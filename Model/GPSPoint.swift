import Foundation
import CoreLocation
import MapKit

/// Latest GPS position returned by `/gps/latest`.
/// Field names match the SQL column names in the FastAPI backend.
struct GPSPoint: Codable, Identifiable, Equatable {
    var id: String { 
        if let vid = ext_vehicle_id { return vid }
        return "\(trip_id ?? 0)-\(ext_trip_id ?? "?")" 
    }

    // MARK: - Static factory for non-JSON construction (e.g. from WebSocket)
    static func make(
        busId: Int? = nil,
        tripId: Int? = nil,
        lat: Double,
        lng: Double,
        speed: Double? = nil,
        heading: Double? = nil,
        routeName: String? = nil,
        routeId: Int? = nil,
        ts: String? = nil,
        extVehicleId: String? = nil,
        extTripId: String? = nil,
        status: String? = nil,
        direction: String? = nil,
        fromStopName: String? = nil,
        toStopName: String? = nil,
        delayMin: Double? = nil,
        source: String? = nil
    ) -> GPSPoint {
        // Build a minimal JSON dict and decode — keeps one init path
        var dict: [String: Any] = ["lat": lat, "lon": lng]
        if let v = busId        { dict["bus_id"] = v }
        if let v = tripId       { dict["trip_id"] = v }
        if let v = speed        { dict["speed"] = v }
        if let v = heading      { dict["heading"] = v }
        if let v = routeName    { dict["route_name"] = v }
        if let v = routeId      { dict["route_id"] = v }
        if let v = ts           { dict["ts"] = v }
        if let v = extVehicleId { dict["ext_vehicle_id"] = v }
        if let v = extTripId    { dict["ext_trip_id"] = v }
        if let v = status       { dict["status"] = v }
        if let v = direction    { dict["dir"] = v }
        if let v = fromStopName { dict["from_stop_name"] = v }
        if let v = toStopName   { dict["to_stop_name"] = v }
        if let v = delayMin     { dict["delay_min"] = v }
        if let v = source       { dict["source"] = v }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(GPSPoint.self, from: data)
    }
    let bus_id: Int?
    let trip_id: Int?
    let lat: Double
    let lng: Double
    let speed: Double?
    let heading: Double?
    let route_name: String?
    let route_id: Int?
    let ts: String?
    let ext_vehicle_id: String?
    let ext_trip_id: String?
    let status: String?
    let direction: String?
    let from_stop_name: String?
    let to_stop_name: String?
    let delay_min: Double?   // Minutes behind schedule (from GTFS-RT)
    let source: String?      // "realtime" or "schedule"
    
    enum CodingKeys: String, CodingKey {
        case bus_id, trip_id, lat, status, ts
        case from_stop_name, to_stop_name
        case route_id, route_name
        case ext_vehicle_id, ext_trip_id
        case delay_min, source
        // Longitude: /gps/live uses 'lon', DB uses 'lng'
        case lon
        case lng
        // Speed: /gps/live uses 'spd' (String), DB uses 'speed' (Double)
        case spd
        case speed
        // Heading: /gps/live uses 'hdg', DB uses 'heading'
        case hdg
        case heading
        // Direction: /gps/live uses 'dir', DB uses 'direction'
        case dir
        case direction
        // Route: /gps/live uses 'rt', DB uses 'route_name'
        case rt
    }
    
    // Custom init to handle dual key names between /gps/live and /api/gps/latest
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bus_id         = try c.decodeIfPresent(Int.self,    forKey: .bus_id)
        trip_id        = try c.decodeIfPresent(Int.self,    forKey: .trip_id)
        lat            = (try? c.decode(Double.self, forKey: .lat)) ?? 0
        // Longitude: try 'lon' first (/gps/live), then 'lng' (DB)
        lng            = (try? c.decode(Double.self, forKey: .lon))
                      ?? (try? c.decode(Double.self, forKey: .lng))
                      ?? 0
        // Speed: try 'spd' as String (/gps/live), then 'speed' as Double (DB)
        if let s = try? c.decodeIfPresent(String.self, forKey: .spd) {
            speed = Double(s)
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .speed) {
            speed = Double(s)
        } else {
            speed = try? c.decodeIfPresent(Double.self, forKey: .speed)
        }
        // Heading: try 'hdg' (/gps/live) then 'heading' (DB)
        heading        = (try? c.decodeIfPresent(Double.self, forKey: .hdg))
                      ?? (try? c.decodeIfPresent(Double.self, forKey: .heading))
        // Route name: try 'rt' (/gps/live) then 'route_name' (DB)
        route_name     = (try? c.decodeIfPresent(String.self, forKey: .rt))
                      ?? (try? c.decodeIfPresent(String.self, forKey: .route_name))
        route_id       = try c.decodeIfPresent(Int.self,    forKey: .route_id)
        ts             = try c.decodeIfPresent(String.self, forKey: .ts)
        ext_vehicle_id = try c.decodeIfPresent(String.self, forKey: .ext_vehicle_id)
        ext_trip_id    = try c.decodeIfPresent(String.self, forKey: .ext_trip_id)
        status         = try c.decodeIfPresent(String.self, forKey: .status)
        // Direction: try 'dir' (/gps/live) then 'direction' (DB)
        direction      = (try? c.decodeIfPresent(String.self, forKey: .dir))
                      ?? (try? c.decodeIfPresent(String.self, forKey: .direction))
        from_stop_name = try c.decodeIfPresent(String.self, forKey: .from_stop_name)
        to_stop_name   = try c.decodeIfPresent(String.self, forKey: .to_stop_name)
        delay_min      = try c.decodeIfPresent(Double.self, forKey: .delay_min)
        source         = try c.decodeIfPresent(String.self, forKey: .source)
    }

    // Encode using canonical DB field names
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(bus_id,          forKey: .bus_id)
        try c.encodeIfPresent(trip_id,         forKey: .trip_id)
        try c.encode(lat,                      forKey: .lat)
        try c.encode(lng,                      forKey: .lng)   // write as 'lng'
        try c.encodeIfPresent(speed,           forKey: .speed)
        try c.encodeIfPresent(heading,         forKey: .heading)
        try c.encodeIfPresent(route_name,      forKey: .route_name)
        try c.encodeIfPresent(route_id,        forKey: .route_id)
        try c.encodeIfPresent(ts,              forKey: .ts)
        try c.encodeIfPresent(ext_vehicle_id,  forKey: .ext_vehicle_id)
        try c.encodeIfPresent(ext_trip_id,     forKey: .ext_trip_id)
        try c.encodeIfPresent(status,          forKey: .status)
        try c.encodeIfPresent(direction,       forKey: .direction)
        try c.encodeIfPresent(from_stop_name,  forKey: .from_stop_name)
        try c.encodeIfPresent(to_stop_name,    forKey: .to_stop_name)
        try c.encodeIfPresent(delay_min,       forKey: .delay_min)
        try c.encodeIfPresent(source,          forKey: .source)
    }

    func isWithinRegion(_ region: MKCoordinateRegion, buffer: Double = 1.2) -> Bool {
        let latDelta = region.span.latitudeDelta * buffer
        let lonDelta = region.span.longitudeDelta * buffer
        
        let minLat = region.center.latitude - latDelta / 2
        let maxLat = region.center.latitude + latDelta / 2
        let minLon = region.center.longitude - lonDelta / 2
        let maxLon = region.center.longitude + lonDelta / 2
        
        return lat >= minLat && lat <= maxLat && lng >= minLon && lng <= maxLon
    }
}
