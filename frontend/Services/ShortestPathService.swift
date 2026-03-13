import Foundation
import CoreLocation

struct GraphNode: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
}

final class ShortestPathService {
    static let shared = ShortestPathService()
    private init() {}

    /// Finds the nearest bus stop using Dijkstra's logic (simplified for Euclidean distance in a sparse graph).
    func findNearestStop(from current: CLLocationCoordinate2D, to stops: [BusStop]) -> BusStop? {
        return findNearestStops(from: current, to: stops, count: 1).first
    }

    /// Finds the top N nearest bus stops.
    func findNearestStops(from current: CLLocationCoordinate2D, to stops: [BusStop], count: Int) -> [BusStop] {
        guard !stops.isEmpty else { return [] }
        
        let currentLoc = CLLocation(latitude: current.latitude, longitude: current.longitude)
        
        // Calculate all distances
        let stopsWithDistance = stops.map { stop -> (BusStop, Double) in
            let stopLoc = CLLocation(latitude: stop.lat, longitude: stop.lng)
            return (stop, currentLoc.distance(from: stopLoc))
        }
        
        // Sort by distance and take the top N
        let sorted = stopsWithDistance.sorted { $0.1 < $1.1 }
        return sorted.prefix(count).map { $0.0 }
    }
}
