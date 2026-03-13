import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case collegeNormal
    case midnightLuxury
    case frostGlass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .collegeNormal: return "College (Default)"
        case .midnightLuxury: return "Midnight Luxury (Premium)"
        case .frostGlass: return "Frost Glass (Premium)"
        }
    }
}
