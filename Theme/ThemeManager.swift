import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    @Published private(set) var currentTheme: AppTheme = .collegeNormal
    @AppStorage("customFontName") public var customFontName: String = "" {
        didSet { objectWillChange.send() }
    }
    
    // Hex string for custom text color
    @AppStorage("customTextColorHex") public var customTextColorHex: String = "" {
        didSet { objectWillChange.send() }
    }

    var current: AppThemePalette {
        var basePalette: AppThemePalette
        
        switch currentTheme {
        case .collegeNormal:
            basePalette = .init(
                background: Color(red: 0.95, green: 0.96, blue: 1.0),
                card: Color.white.opacity(0.92),
                text: Color(red: 0.05, green: 0.1, blue: 0.3),
                secondaryText: Color(red: 0.05, green: 0.1, blue: 0.3).opacity(0.6),
                border: Color.white.opacity(0.4),
                accent: Color(red: 0.0, green: 0.45, blue: 0.95),
                primaryGradient: [
                    Color(red: 0.0, green: 0.35, blue: 0.75),
                    Color(red: 0.0, green: 0.55, blue: 1.0),
                    Color(red: 0.2, green: 0.7, blue: 1.0)
                ]
            )
        case .midnightLuxury:
            basePalette = .init(
                background: Color(red: 0.05, green: 0.05, blue: 0.08),
                card: Color(red: 0.1, green: 0.12, blue: 0.15).opacity(0.95),
                text: Color(red: 0.9, green: 0.85, blue: 0.8),
                secondaryText: Color(red: 0.7, green: 0.65, blue: 0.6),
                border: Color(red: 0.8, green: 0.75, blue: 0.5).opacity(0.4),
                accent: Color(red: 0.85, green: 0.75, blue: 0.5), // Gold accent
                primaryGradient: [
                    Color(red: 0.6, green: 0.5, blue: 0.2),
                    Color(red: 0.85, green: 0.75, blue: 0.5),
                    Color(red: 0.95, green: 0.9, blue: 0.7)
                ]
            )
        case .frostGlass:
            basePalette = .init(
                background: Color(red: 0.92, green: 0.95, blue: 0.98),
                card: Color.white.opacity(0.7),
                text: Color(red: 0.15, green: 0.25, blue: 0.35),
                secondaryText: Color(red: 0.35, green: 0.45, blue: 0.55),
                border: Color.white.opacity(0.8),
                accent: Color(red: 0.2, green: 0.6, blue: 0.8), // Ice blue accent
                primaryGradient: [
                    Color.white.opacity(0.5),
                    Color(red: 0.2, green: 0.6, blue: 0.8).opacity(0.6),
                    Color(red: 0.1, green: 0.5, blue: 0.9).opacity(0.8)
                ]
            )
        }
        
        // Apply custom text color if set
        if !customTextColorHex.isEmpty, let customColor = Color(hex: customTextColorHex) {
            basePalette.text = customColor
        }
        
        return basePalette
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
    }
    
    init() {
        if let storedThemeStr = UserDefaults.standard.string(forKey: "selectedTheme"),
           let storedTheme = AppTheme(rawValue: storedThemeStr) {
            self.currentTheme = storedTheme
        }
    }
}

// Helper for hex color
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: Double = 0.0
        var g: Double = 0.0
        var b: Double = 0.0
        var a: Double = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
