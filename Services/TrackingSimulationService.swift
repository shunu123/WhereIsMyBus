import Foundation

final class TrackingSimulationService {
    static let shared = TrackingSimulationService()
    private init() {}

    func buildPath(stops: [Stop]) -> [Coord] {
        return stops.map { $0.coordinate }
    }

    func generateHistory(path: [Coord], date: Date) -> [LocationPing] {
        let base = Calendar.current.startOfDay(for: date)
        return path.enumerated().map { idx, c in
            LocationPing(timestamp: base.addingTimeInterval(Double(idx) * 60), coordinate: c)
        }
    }
}
