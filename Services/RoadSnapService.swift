import Foundation
import MapKit

/// Shared service that converts a list of Coord waypoints into road-snapped polylines
/// using Apple's MKDirections. Results are cached by a key so re-clicks don't cost extra.
actor RoadSnapService {
    static let shared = RoadSnapService()
    private init() {}

    // Cache: sorted stop IDs string -> road-snapped coords
    private var cache: [String: [Coord]] = [:]

    /// Returns road-snapped path for the given stops.
    /// - Re-uses cache if available.
    /// - Falls back to smooth interpolation if routing fails.
    func snap(stops: [Stop]) async -> [Coord] {
        guard stops.count >= 2 else { return stops.map { $0.coordinate } }

        let key = stops.map { $0.id }.joined(separator: "-")
        if let cached = cache[key] { return cached }

        var allPoints: [Coord] = []

        for i in 0..<stops.count - 1 {
            let start = stops[i].coordinate
            let end   = stops[i + 1].coordinate

            let request = MKDirections.Request()
            let startLocation = CLLocationCoordinate2D(latitude: start.lat, longitude: start.lon)
            let endLocation   = CLLocationCoordinate2D(latitude: end.lat,   longitude: end.lon)
            request.source      = MKMapItem(placemark: MKPlacemark(coordinate: startLocation))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: endLocation))
            request.transportType = .automobile

            do {
                let response = try await MKDirections(request: request).calculate()
                if let route = response.routes.first {
                    let pts   = route.polyline.points()
                    let count = route.polyline.pointCount
                    let skip  = max(1, count / 80)
                    for j in stride(from: 0, to: count, by: skip) {
                        let coord = pts[j].coordinate
                        allPoints.append(Coord(lat: coord.latitude, lon: coord.longitude))
                    }
                    // Always include the last point
                    let lastCoord = pts[count - 1].coordinate
                    allPoints.append(Coord(lat: lastCoord.latitude, lon: lastCoord.longitude))
                } else {
                    interpolate(from: start, to: end, into: &allPoints)
                }
            } catch {
                print("RoadSnapService: MKDirections failed [\(stops[i].name)→\(stops[i+1].name)]: \(error.localizedDescription)")
                interpolate(from: start, to: end, into: &allPoints)
            }
        }

        cache[key] = allPoints
        return allPoints
    }

    /// Evicts the cached result for a given set of stops (call when stops change).
    func invalidate(stops: [Stop]) {
        let key = stops.map { $0.id }.joined(separator: "-")
        cache.removeValue(forKey: key)
    }

    // MARK: – Private Helpers

    private func interpolate(from: Coord, to: Coord, into list: inout [Coord]) {
        list.append(from)
        let n = 30
        for j in 1..<n {
            let t = Double(j) / Double(n)
            list.append(Coord(lat: from.lat + (to.lat - from.lat) * t,
                              lon: from.lon + (to.lon - from.lon) * t))
        }
        list.append(to)
    }
}
