import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    @Published private(set) var currentTheme: AppTheme = .collegeNormal

    var current: AppThemePalette {
        switch currentTheme {
        case .collegeNormal:
            return .init(
                background: Color(red: 0.98, green: 0.98, blue: 1.0),
                card: Color.white,
                text: Color(red: 0.05, green: 0.1, blue: 0.3),
                secondaryText: Color(red: 0.05, green: 0.1, blue: 0.3).opacity(0.6),
                border: Color(red: 0.0, green: 0.1, blue: 0.3).opacity(0.1),
                accent: Color(red: 0.0, green: 0.4, blue: 0.8),
                primaryGradient: [
                    Color(red: 0.0, green: 0.3, blue: 0.7),
                    Color(red: 0.0, green: 0.5, blue: 0.9),
                    Color(red: 0.3, green: 0.7, blue: 1.0)
                ]
            )
        case .sunset:
            return .init(
                background: Color.white,
                card: Color.black.opacity(0.03),
                text: Color.black,
                secondaryText: Color.black.opacity(0.65),
                border: Color.black.opacity(0.08),
                accent: Color(red: 1.0, green: 0.3, blue: 0.0),
                primaryGradient: [
                    Color(red: 1.0, green: 0.3, blue: 0.0),
                    Color(red: 1.0, green: 0.58, blue: 0.0),
                    Color(red: 1.0, green: 0.8, blue: 0.0)
                ]
            )
        case .ocean:
            return .init(
                background: Color(red: 0.96, green: 0.98, blue: 1.0),
                card: Color.white.opacity(0.85),
                text: Color(red: 0.05, green: 0.1, blue: 0.2),
                secondaryText: Color(red: 0.05, green: 0.1, blue: 0.2).opacity(0.6),
                border: Color.blue.opacity(0.12),
                accent: Color(red: 0.0, green: 0.75, blue: 1.0),
                primaryGradient: [
                    Color(red: 0.0, green: 0.75, blue: 1.0),
                    Color(red: 0.53, green: 0.81, blue: 0.98),
                    Color(red: 1.0, green: 0.84, blue: 0.0)
                ]
            )
        case .fadedGradient:
            return .init(
                background: Color(red: 0.97, green: 0.97, blue: 1.0),
                card: Color.white.opacity(0.95),
                text: Color(red: 0.1, green: 0.1, blue: 0.15),
                secondaryText: Color(red: 0.45, green: 0.45, blue: 0.5),
                border: Color(red: 0.93, green: 0.93, blue: 0.96),
                accent: Color(red: 0.6, green: 0.75, blue: 1.0),
                primaryGradient: [
                    Color(red: 0.9, green: 0.85, blue: 1.0),
                    Color(red: 0.8, green: 0.9, blue: 1.0),
                    Color(red: 0.75, green: 0.95, blue: 0.9)
                ]
            )
        case .goldenHour:
            return .init(
                background: Color(red: 1.0, green: 0.98, blue: 0.95),
                card: Color.white.opacity(0.9),
                text: Color(red: 0.4, green: 0.25, blue: 0.1),
                secondaryText: Color(red: 0.4, green: 0.25, blue: 0.1).opacity(0.6),
                border: Color(red: 0.95, green: 0.9, blue: 0.8),
                accent: Color(red: 1.0, green: 0.7, blue: 0.0),
                primaryGradient: [
                    Color(red: 1.0, green: 0.8, blue: 0.4),
                    Color(red: 1.0, green: 0.6, blue: 0.2),
                    Color(red: 1.0, green: 0.9, blue: 0.6)
                ]
            )
        case .lavender:
            return .init(
                background: Color(red: 0.98, green: 0.96, blue: 1.0),
                card: Color.white.opacity(0.9),
                text: Color(red: 0.3, green: 0.2, blue: 0.4),
                secondaryText: Color(red: 0.3, green: 0.2, blue: 0.4).opacity(0.6),
                border: Color(red: 0.9, green: 0.85, blue: 0.95),
                accent: Color(red: 0.7, green: 0.5, blue: 0.9),
                primaryGradient: [
                    Color(red: 0.7, green: 0.5, blue: 0.9),
                    Color(red: 0.9, green: 0.6, blue: 0.8),
                    Color(red: 1.0, green: 0.8, blue: 0.8)
                ]
            )
        case .forest:
            return .init(
                background: Color(red: 0.96, green: 0.98, blue: 0.96),
                card: Color.white.opacity(0.9),
                text: Color(red: 0.05, green: 0.2, blue: 0.1),
                secondaryText: Color(red: 0.05, green: 0.2, blue: 0.1).opacity(0.6),
                border: Color(red: 0.85, green: 0.95, blue: 0.85),
                accent: Color(red: 0.1, green: 0.6, blue: 0.4),
                primaryGradient: [
                    Color(red: 0.0, green: 0.4, blue: 0.3),
                    Color(red: 0.1, green: 0.6, blue: 0.4),
                    Color(red: 0.4, green: 0.8, blue: 0.5)
                ]
            )
        case .aurora:
            return .init(
                background: Color(red: 0.0, green: 0.02, blue: 0.05),
                card: Color.white.opacity(0.12),
                text: Color.white,
                secondaryText: Color.white.opacity(0.7),
                border: Color.white.opacity(0.2),
                accent: Color(red: 0.0, green: 1.0, blue: 0.5),
                primaryGradient: [
                    Color(red: 0.4, green: 0.0, blue: 0.8),
                    Color(red: 0.0, green: 0.8, blue: 1.0),
                    Color(red: 0.0, green: 1.0, blue: 0.5)
                ]
            )
        }
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
}
