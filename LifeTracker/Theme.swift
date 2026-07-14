import SwiftUI

extension Color {
    /// Create a Color from a hex string like "F8C8DC" or "#F8C8DC".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// The app's brand palette — warm creams with a peach accent.
    static let brandPink = Color(hex: "E9B8A6")    // accent: selection, checkmarks, buttons (deeper peach)
    static let pagePink = Color(hex: "FFEFEF")     // main page — soft blush
    static let sidebarPink = Color(hex: "F0EBE3")  // sidebar — greige
    static let barPink = Color(hex: "F3D0D7")      // top bar — soft pink
    static let hoverPink = Color(hex: "F5EEE6")    // subtle hover / cream
    static let inkOnPink = Color(hex: "6E5647")    // readable warm taupe-brown text
    static let incomeGreen = Color(hex: "5E9E7E")  // income amounts
    static let expenseRose = Color(hex: "C8697A")  // expense amounts
    static let googleBlue = Color(hex: "CFE0F0")   // Google Calendar event chips
}
