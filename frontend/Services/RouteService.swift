import Foundation

/// RouteService — static data removed.
/// All routes, stops, and schedules are fetched from the backend via BusRepository.
struct RouteService {
    static let shared = RouteService()
    private init() {}
}
