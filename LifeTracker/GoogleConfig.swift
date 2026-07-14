import Foundation

/// Configuration for connecting to Google Calendar.
///
/// To enable the connection, replace `clientID` below with the OAuth Client ID
/// you create in the Google Cloud Console (an "iOS" type client with bundle ID
/// `com.nicole.LifeTracker`). It looks like:
///   123456789-abcdefg.apps.googleusercontent.com
enum GoogleConfig {
    static let clientID = "6282853880-lnqbbur2ic9eje3ifi03kmdsmd785sp3.apps.googleusercontent.com"

    /// True once a real Client ID has been pasted in above.
    static var isConfigured: Bool {
        clientID.hasSuffix(".apps.googleusercontent.com") && !clientID.hasPrefix("YOUR_CLIENT_ID")
    }

    /// The reversed client ID, used as the app's redirect URL scheme.
    /// e.g. com.googleusercontent.apps.123456789-abcdefg
    static var reversedClientID: String {
        let base = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(base)"
    }

    static var redirectURI: String { "\(reversedClientID):/oauth2redirect" }

    /// Read-only access to the user's calendar.
    static let scope = "https://www.googleapis.com/auth/calendar.readonly"
}
