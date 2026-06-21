//
//  Theme.swift
//  sbog
//
//  Shared color constants for consistent theming
//

import SwiftUI

enum AppTheme {
    // Same palette for Dark/Light: fixed brand colors.
    static let background = Color(hex: "FDECC5")
    static let surface = Color(hex: "FFF5E3")
    static let surfaceElevated = Color(hex: "FFF0D6")
    static let accent = Color(hex: "84332D")
    static let accentSoft = Color(hex: "FFCD4D")
    static let accentSoftSecondary = Color(hex: "FFD983")
    static let textPrimary = Color(hex: "2A1B12")
    static let textSecondary = Color(hex: "6B5B52")
    static let textOnAccent = Color.white
    static let success = Color(hex: "2E7D32")
    static let warning = Color(hex: "F57C00")
    static let error = Color(hex: "C62828")
}

enum PlayerAvatars {
    static let options = ["player1", "player2", "player3", "player4"]
    static let defaultName = "player1"
    
    static func imageName(for storedName: String?) -> String {
        guard let storedName, options.contains(storedName) else {
            return defaultName
        }
        return storedName
    }
}

extension Font {
    static func appTitle(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let appHeadline = Font.system(.headline, design: .rounded)
    static let appBody = Font.system(.body, design: .rounded)
    static let appCaption = Font.system(.caption, design: .rounded)
}

extension Color {
    /// Extension للون hex
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
