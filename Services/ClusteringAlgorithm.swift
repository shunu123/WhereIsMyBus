import Foundation
import CoreLocation
import MapKit

/// Repesents a cluster of markers.
struct BusCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let points: [GPSPoint]
    
    var count: Int { points.count }
    var routeNames: Set<String> {
        Set(points.compactMap { $0.route_name })
    }
}

/// A service to group nearby markers based on map distance.
class ClusteringAlgorithm {
    static let shared = ClusteringAlgorithm()
    
    /// Groups points into clusters based on a distance threshold.
    /// - Parameters:
    ///   - points: The list of points to cluster.
    ///   - distanceThreshold: The maximum distance (in map units) to group points.
    ///   - region: The current visible region to help calculate scale.
    func cluster(points: [GPSPoint], distanceThreshold: Double, region: MKCoordinateRegion) -> [BusCluster] {
        guard !points.isEmpty else { return [] }
        
        var clusters: [BusCluster] = []
        var visited = Set<String>()
        
        // Convert threshold to lat/lng degrees roughly based on region
        let latFactor = region.span.latitudeDelta * distanceThreshold
        let lngFactor = region.span.longitudeDelta * distanceThreshold
        
        for point in points {
            if visited.contains(point.id) { continue }
            
            // Start a new cluster
            var clusterPoints: [GPSPoint] = [point]
            visited.insert(point.id)
            
            // Find neighbors
            for other in points {
                if visited.contains(other.id) { continue }
                
                let latDist = abs(point.lat - other.lat)
                let lngDist = abs(point.lng - other.lng)
                
                if latDist < latFactor && lngDist < lngFactor {
                    clusterPoints.append(other)
                    visited.insert(other.id)
                }
            }
            
            // Calculate centroid
            let avgLat = clusterPoints.map { $0.lat }.reduce(0, +) / Double(clusterPoints.count)
            let avgLng = clusterPoints.map { $0.lng }.reduce(0, +) / Double(clusterPoints.count)
            
            clusters.append(BusCluster(
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLng),
                points: clusterPoints
            ))
        }
        
        return clusters
    }
}
