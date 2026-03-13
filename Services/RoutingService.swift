import Foundation
import MapKit

/// Service for calculating routes between coordinates using MKDirections.
final class RoutingService {
    static let shared = RoutingService()
    private init() {}
    
    struct RouteResult {
        let polyline: [CLLocationCoordinate2D]
        let distanceMeters: Double
        let travelTimeSeconds: Double
    }
    
    func calculateRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> RouteResult {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw NSError(domain: "RoutingService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No route found"])
        }
        
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: route.polyline.pointCount))
        
        return RouteResult(
            polyline: coords,
            distanceMeters: route.distance,
            travelTimeSeconds: route.expectedTravelTime
        )
    }
}
