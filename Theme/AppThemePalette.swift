import SwiftUI

struct AppThemePalette {
    var background: Color
    var card: Color
    var text: Color
    var secondaryText: Color
    var border: Color
    var accent: Color
    var primaryGradient: [Color]

    // Some screens might refer to "primary"
    var primary: Color { accent }
}
