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
    /// In a real road network, this would use an adjacency list of road intersections.
    /// Here, we find the stop with the minimum distance from the current location.
    func findNearestStop(from current: CLLocationCoordinate2D, to stops: [BusStop]) -> BusStop? {
        guard !stops.isEmpty else { return nil }
        
        let currentLoc = CLLocation(latitude: current.latitude, longitude: current.longitude)
        
        // Dijkstra initialization
        var minDistance: Double = Double.infinity
        var nearest: BusStop? = nil
        
        // In a true graph implementation, we'd iterate through edges.
        // For bus stops as nodes directly reachable from 'current', we calculate weights.
        for stop in stops {
            let stopLoc = CLLocation(latitude: stop.lat, longitude: stop.lng)
            let distance = currentLoc.distance(from: stopLoc)
            
            if distance < minDistance {
                minDistance = distance
                nearest = stop
            }
        }
        
        return nearest
    }
}
