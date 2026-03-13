import Foundation
import CoreLocation

struct RouteMatch: Identifiable {
    let id = UUID()
    let bus: DailyBusTrip
    let fromStop: BusStop
    let toStop: BusStop
}

final class RouteDiscoveryService {
    static let shared = RouteDiscoveryService()
    private init() {}

    /// Finds bus trips that pass near the source and destination coordinates.
    func findRoutes(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> [RouteMatch] {
        // 1. Fetch all stops to find candidates
        let allStops = try await APIService.shared.fetchAllStops()
        
        // 2. Find stops near source and destination (within 2km)
        let sourceCandidates = allStops.filter {
            distance($0.coordinate, from) < 2000
        }.sorted(by: { distance($0.coordinate, from) < distance($1.coordinate, from) })
        
        let destCandidates = allStops.filter {
            distance($0.coordinate, to) < 2000
        }.sorted(by: { distance($0.coordinate, to) < distance($1.coordinate, to) })
        
        guard !sourceCandidates.isEmpty, !destCandidates.isEmpty else {
            return []
        }
        
        // 3. Fetch current live buses
        let allBuses = try await APIService.shared.fetchBuses()
        
        var matches: [RouteMatch] = []
        
        // 4. For each bus, che#imageLiteral(resourceName: "Screenshot 2026-03-12 at 22.54.59.png")ck if it contains a source stop and then a destination stop
        for bus in allBuses {
            // This requires full stop list for the route, which we might need to fetch per route
            // For efficiency, we'll just check if the bus's route name matches our candidate stop names in a real app, 
            // but here we should ideally check the actual stop sequence.
            
            // Simplified for this requirement: 
            // If we find a bus that mentions candidate stop names or if we have route/stop mapping.
            // Since we have `fetchRouteStops`, we can check the sequence.
            
            if let routeId = bus.routeId {
                let routeStops = try? await APIService.shared.fetchRouteStops(routeId: routeId)
                if let stops = routeStops {
                    let srcMatch = stops.first { s in sourceCandidates.contains { $0.id == s.id } }
                    let dstMatch = stops.first { s in destCandidates.contains { $0.id == s.id } }
                    
                    if let src = srcMatch, let dst = dstMatch, src.stopOrder < dst.stopOrder {
                        // Found a valid route!
                        // Convert Model.Stop back to BusStop for the Match
                        let fromBusStop = BusStop(id: src.id, name: src.name, lat: src.coordinate.lat, lng: src.coordinate.lon)
                        let toBusStop = BusStop(id: dst.id, name: dst.name, lat: dst.coordinate.lat, lng: dst.coordinate.lon)
                        
                        matches.append(RouteMatch(bus: bus, fromStop: fromBusStop, toStop: toBusStop))
                    }
                }
            }
        }
        
        return matches
    }
    
    private func distance(_ c1: CLLocationCoordinate2D, _ c2: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: c1.latitude, longitude: c1.longitude)
        let loc2 = CLLocation(latitude: c2.latitude, longitude: c2.longitude)
        return loc1.distance(from: loc2)
    }
}
