import Foundation

final class HistoryService {
    static let shared = HistoryService()
    private init() {}

    func historyPings(for route: Route, on date: Date) -> [LocationPing] {
        let path = TrackingSimulationService.shared.buildPath(stops: route.stops)
        return TrackingSimulationService.shared.generateHistory(path: path, date: date)
    }
}
