import SwiftUI
import Combine

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [Route] = []
    @Published var showRateUs: Bool = false

    enum Route: Hashable {
        case home
        case availableBuses(from: String, to: String, via: String?)
        case liveTracking(busID: UUID, isHistorical: Bool = false, date: Date? = nil, sourceStop: String? = nil)
        case trackByNumber(autoStartVoice: Bool = false)
        case savedRoutes
        case recentSearches
        case settings
        case help
        case report
        case about
        case busSchedule(busID: UUID, searchPoint: String? = nil)
        case busesAtStop(stopName: String)
        case logout
        case fleetHistory
        case routeMap(buses: [Bus], from: String, to: String)
        case tripDetailTimeline(
            tripId: UUID,
            busNumber: String,
            startTime: String,
            endTime: String,
            trackPoints: [Coord],
            timelineEvents: [TripTimelineEvent]
        )
    }

    // MARK: - Navigation Methods

    func go(_ route: Route) {
        path.append(route)
    }

    func popToRoot() {
        path.removeAll()
    }

    func back() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
}
