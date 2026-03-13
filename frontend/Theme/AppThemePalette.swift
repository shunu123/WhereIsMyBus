import SwiftUI

struct AppThemePalette {
    var background: Color
    var card: Color
    var text: Color
    var secondaryText: Color
    var border: Color
    var accent: Color
    var primaryGradient: [Color]

    // Neon colors for premium UI
    var routePurple: Color { Color(red: 0.6, green: 0.2, blue: 1.0) }
    var routeTeal: Color { Color(red: 0.0, green: 0.8, blue: 1.0) }
    var routeIndigo: Color { Color(red: 0.3, green: 0.3, blue: 0.9) }
    var glassCard: Color { Color.white.opacity(0.15) }

    // Some screens might refer to "primary"
    var primary: Color { accent }
}
