import Foundation
import AuthenticationServices
import CryptoKit
import AppKit

/// A calendar event pulled from Google Calendar.
struct GoogleEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date?
    let isAllDay: Bool
}

/// Manages the Google Calendar connection: OAuth sign-in, token refresh, and
/// fetching events. Read-only.
@MainActor
final class GoogleCalendarService: ObservableObject {
    static let shared = GoogleCalendarService()

    @Published var isConnected = false
    @Published var isBusy = false
    @Published var status = ""
    @Published var events: [GoogleEvent] = []

    private var accessToken: String?
    private var expiry: Date?
    private var refreshToken: String? {
        didSet { UserDefaults.standard.set(refreshToken, forKey: "googleRefreshToken") }
    }

    private var pendingVerifier: String?
    private var authSession: ASWebAuthenticationSession?
    private let presenter = AuthPresenter()

    private init() {
        refreshToken = UserDefaults.standard.string(forKey: "googleRefreshToken")
        isConnected = refreshToken != nil
        if isConnected {
            Task { await fetchEvents() }
        }
    }

    // MARK: Sign in

    func connect() {
        guard GoogleConfig.isConfigured else {
            status = "Add your Client ID in GoogleConfig.swift first."
            return
        }
        let verifier = Self.randomURLSafeString(bytes: 32)
        pendingVerifier = verifier
        let challenge = Self.codeChallenge(for: verifier)

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: GoogleConfig.clientID),
            .init(name: "redirect_uri", value: GoogleConfig.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: GoogleConfig.scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
        ]

        let session = ASWebAuthenticationSession(
            url: comps.url!,
            callbackURLScheme: GoogleConfig.reversedClientID
        ) { [weak self] callback, _ in
            guard let self else { return }
            guard let callback,
                  let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value else {
                Task { @MainActor in self.status = "Sign-in was cancelled." }
                return
            }
            Task { await self.exchange(code: code) }
        }
        session.presentationContextProvider = presenter
        session.start()
        authSession = session
    }

    func disconnect() {
        accessToken = nil
        expiry = nil
        refreshToken = nil
        events = []
        isConnected = false
        status = "Disconnected."
    }

    // MARK: Token exchange / refresh

    private func exchange(code: String) async {
        guard let verifier = pendingVerifier else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let token = try await postToken(params: [
                "client_id": GoogleConfig.clientID,
                "code": code,
                "code_verifier": verifier,
                "grant_type": "authorization_code",
                "redirect_uri": GoogleConfig.redirectURI,
            ])
            apply(token)
            isConnected = true
            await fetchEvents()
        } catch {
            status = "Sign-in failed: \(error.localizedDescription.prefix(160))"
        }
    }

    /// Returns a valid access token, refreshing it if needed.
    private func validAccessToken() async -> String? {
        if let token = accessToken, let exp = expiry, exp > Date().addingTimeInterval(60) {
            return token
        }
        guard let refresh = refreshToken else { return nil }
        do {
            let token = try await postToken(params: [
                "client_id": GoogleConfig.clientID,
                "refresh_token": refresh,
                "grant_type": "refresh_token",
            ])
            apply(token)
            return accessToken
        } catch {
            return nil
        }
    }

    private func apply(_ token: TokenResponse) {
        accessToken = token.access_token
        expiry = Date().addingTimeInterval(TimeInterval(token.expires_in ?? 3600))
        if let refresh = token.refresh_token {
            refreshToken = refresh
        }
    }

    private func postToken(params: [String: String]) async throws -> TokenResponse {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params
            .map { "\($0.key)=\(Self.formEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            throw NSError(domain: "GoogleToken", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    // MARK: Fetch events

    func fetchEvents() async {
        guard let token = await validAccessToken() else {
            isConnected = false
            status = "Please connect again."
            return
        }
        isBusy = true
        defer { isBusy = false }

        let now = Date()
        let cal = Calendar.current
        let timeMin = cal.date(byAdding: .day, value: -365, to: now) ?? now
        let timeMax = cal.date(byAdding: .day, value: 365, to: now) ?? now

        let calendarIDs = await fetchCalendarIDs(token: token)
        var collected: [GoogleEvent] = []
        var lastError: String?

        for id in calendarIDs {
            let (evs, err) = await loadEvents(calendarID: id, token: token, from: timeMin, to: timeMax)
            collected += evs
            if let err { lastError = err }
        }

        events = collected.sorted { $0.start < $1.start }
        if events.isEmpty, let lastError {
            status = lastError
        } else {
            status = "Synced \(events.count) events from \(calendarIDs.count) calendar(s)."
        }
    }

    /// Fetches the list of the user's calendar IDs (falls back to "primary").
    private func fetchCalendarIDs(token: String) async -> [String] {
        var req = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                return ["primary"]
            }
            let list = try JSONDecoder().decode(CalendarListResponse.self, from: data)
            let ids = list.items?.map { $0.id } ?? []
            return ids.isEmpty ? ["primary"] : ids
        } catch {
            return ["primary"]
        }
    }

    /// Fetches events for one calendar within the time window.
    /// Returns the events and, if the request failed, an error message.
    private func loadEvents(calendarID: String, token: String,
                            from: Date, to: Date) async -> ([GoogleEvent], String?) {
        let iso = ISO8601DateFormatter()
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encodedID = calendarID.addingPercentEncoding(withAllowedCharacters: allowed) ?? calendarID

        var comps = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedID)/events")!
        comps.queryItems = [
            .init(name: "timeMin", value: iso.string(from: from)),
            .init(name: "timeMax", value: iso.string(from: to)),
            .init(name: "singleEvents", value: "true"),
            .init(name: "orderBy", value: "startTime"),
            .init(name: "maxResults", value: "250"),
        ]
        guard let url = comps.url else { return ([], "Bad URL") }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let body = String(data: data, encoding: .utf8)?.prefix(160) ?? ""
                return ([], "Fetch error \(http.statusCode): \(body)")
            }
            let resp = try JSONDecoder().decode(EventsResponse.self, from: data)
            return (resp.items?.compactMap { GoogleEvent(apiEvent: $0) } ?? [], nil)
        } catch {
            return ([], "Fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: PKCE helpers

    private static func randomURLSafeString(bytes count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncoded()
    }

    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

/// Provides the window to anchor the Google sign-in sheet to.
final class AuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}

// MARK: - JSON models

private struct TokenResponse: Decodable {
    let access_token: String
    let expires_in: Int?
    let refresh_token: String?
}

private struct CalendarListResponse: Decodable {
    let items: [CalListItem]?
}

private struct CalListItem: Decodable {
    let id: String
    let summary: String?
}

private struct EventsResponse: Decodable {
    let items: [APIEvent]?
}

private struct APIEvent: Decodable {
    let id: String
    let summary: String?
    let start: APITime?
    let end: APITime?
}

private struct APITime: Decodable {
    let date: String?       // all-day: "2026-07-14"
    let dateTime: String?   // timed: "2026-07-14T09:00:00-07:00"
}

private extension GoogleEvent {
    init?(apiEvent e: APIEvent) {
        guard let startRaw = e.start else { return nil }
        let isoFmt = ISO8601DateFormatter()
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "yyyy-MM-dd"
        dayFmt.timeZone = .current

        func parse(_ t: APITime?) -> (date: Date, allDay: Bool)? {
            guard let t else { return nil }
            if let dt = t.dateTime, let d = isoFmt.date(from: dt) { return (d, false) }
            if let day = t.date, let d = dayFmt.date(from: day) { return (d, true) }
            return nil
        }

        guard let s = parse(startRaw) else { return nil }
        self.id = e.id
        self.title = e.summary ?? "(No title)"
        self.start = s.date
        self.end = parse(e.end)?.date
        self.isAllDay = s.allDay
    }
}

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
