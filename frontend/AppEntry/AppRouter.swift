import SwiftUI
import Combine
import Foundation
import CoreLocation

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [AppPage] = []
    @Published var showRateUs: Bool = false

    enum AppPage: Hashable {
        case home
        case availableBuses(from: String, to: String, fromID: String? = nil, toID: String? = nil, fromLat: Double? = nil, fromLon: Double? = nil, toLat: Double? = nil, toLon: Double? = nil, via: String? = nil)


        case liveTracking(busID: UUID, isHistorical: Bool = false, date: Date? = nil, sourceStop: String? = nil, destinationStop: String? = nil, sourceLat: Double? = nil, sourceLon: Double? = nil, destLat: Double? = nil, destLon: Double? = nil)
        case trackByNumber(autoStartVoice: Bool = false)
        case savedRoutes
        case recentSearches
        case settings 
        case help
        case report
        case about
        case busSchedule(busID: String, searchPoint: String? = nil, destinationStop: String? = nil, sourceLat: Double? = nil, sourceLon: Double? = nil, destLat: Double? = nil, destLon: Double? = nil)
        case busesAtStop(stopName: String)
        case logout
        case fleetHistory
        case activeFleet // NEW: Live Eye view map
        case allRoutes
        case routeDetail(routeID: String)
        case registration
        case routeMap(busNumbers: [String], from: String, to: String)
        case tripDetailTimeline(
            tripId: UUID,
            busNumber: String,
            startTime: String,
            endTime: String,
            trackPoints: [Coord],
            timelineEvents: [TripTimelineEvent]
        )

        case editProfile
        case studentData
        case adminScheduling
        case adminHistory
        case studentDashboard
    }

    // MARK: - Navigation Methods

    func go(_ route: AppPage) {
        print("🧭 Navigation: AppRouter.go(\(route))")
        path.append(route)
    }

    func popToRoot() {
        print("🧭 Navigation: AppRouter.popToRoot()")
        path.removeAll()
    }

    func back() {
        print("🧭 Navigation: AppRouter.back()")
        if !path.isEmpty {
            path.removeLast()
        }
    }
}
