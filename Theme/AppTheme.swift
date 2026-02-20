import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case collegeNormal
    case sunset
    case ocean
    case fadedGradient
    case goldenHour
    case lavender
    case forest
    case aurora

    var id: String { rawValue }

    var title: String {
        switch self {
        case .collegeNormal: return "College (Default)"
        case .sunset: return "Sunset"
        case .ocean: return "Ocean Breeze"
        case .fadedGradient: return "Faded Gradient"
        case .goldenHour: return "Golden Hour"
        case .lavender: return "Lavender Mist"
        case .forest: return "Forest Path"
        case .aurora: return "Aurora Neon"
        }
    }
}
