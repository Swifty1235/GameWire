import SwiftUI

/// Central place for GameWire's colors. Clean system colors that follow light/dark mode,
/// plus one orange accent for the logo and highlights.
enum Theme {
    /// GameWire orange (#FF7A00). Defined in Assets → AccentColor.
    static let accent = Color.accentColor
    static let background = Color(.systemBackground)
}

extension Color {
    /// Color from a hex value, e.g. `Color(hex: 0x39FF61)`.
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Date {
    /// Compact "time ago" label used on posts: "now", "12m", "3h", "2d".
    var shortAgo: String {
        let seconds = Int(Date().timeIntervalSince(self))
        switch seconds {
        case ..<60: return "now"
        case ..<3600: return "\(seconds / 60)m"
        case ..<86_400: return "\(seconds / 3600)h"
        default: return "\(seconds / 86_400)d"
        }
    }
}
