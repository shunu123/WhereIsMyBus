import Foundation

final class TrackingSimulationService {
    static let shared = TrackingSimulationService()
    private init() {}

    func buildPath(stops: [Stop]) -> [Coord] {
        // Simple winding road: interpolate with offsets to simulate natural curves
        guard stops.count >= 2 else { return stops.map { $0.coordinate } }

        var out: [Coord] = []
        for i in 0..<(stops.count - 1) {
            let a = stops[i].coordinate
            let b = stops[i + 1].coordinate
            
            // Calculate distance approx to determine number of segments
            let latDiff = b.lat - a.lat
            let lonDiff = b.lon - a.lon
            let dist = sqrt(latDiff * latDiff + lonDiff * lonDiff)
            
            // Higher density for smoother curves and more granular movement
            let segments = Int(max(20, dist * 2000)) 
            let step = 1.0 / Double(segments)
            
            // Perpendicular vector for curves
            let perpLat = -lonDiff
            let perpLon = latDiff
            
            out.append(a)
            for j in 1..<segments {
                let t = Double(j) * step
                
                // Base linear point
                var lat = a.lat + latDiff * t
                var lon = a.lon + lonDiff * t
                
                // Add "winding" effect using sine waves
                // We use multiple frequencies to make it look organic
                let curveAmount = dist * 0.05 // 5% of distance max offset
                let winding = sin(t * .pi) * sin(t * 5) * curveAmount
                
                lat += perpLat * winding
                lon += perpLon * winding
                
                out.append(Coord(lat: lat, lon: lon))
            }
        }
        out.append(stops.last!.coordinate)
        return out
    }

    func generateHistory(path: [Coord], date: Date) -> [LocationPing] {
        let base = Calendar.current.startOfDay(for: date)
        return path.enumerated().map { idx, c in
            LocationPing(timestamp: base.addingTimeInterval(Double(idx) * 60), coordinate: c)
        }
    }
}
