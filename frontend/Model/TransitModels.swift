import Foundation

// MARK: - CTA API Response Models

struct TransitTrackResponse: Codable, Hashable {
    let route_id: String
    let trip_id: String?
    let from_stop: String
    let to_stop: String
    let schedule: TransitSchedule
    let duration: String
    let timeline: [TransitTimelineStop]
    let bus_live_location: TransitGPS?
    let polyline: [TransitPolylinePoint]
}

struct TransitSchedule: Codable, Hashable {
    let departure_time: String
    let arrival_time: String
}

struct TransitTimelineStop: Codable, Hashable {
    let stop_id: String
    let stop_name: String
    let eta: String
    let is_current: Bool
}

// CTAGPS moved to SearchTrip.swift


struct TransitPolylinePoint: Codable, Hashable {
    let lat: Double
    let lng: Double
    let typ: String?
}

struct TransitDirection: Codable {
    let dir: String
}

// MARK: - New Unified Trip Models
struct TransitFullTripResponse: Codable, Hashable {
    let ok: Bool
    let vid: String
    let route: String
    let direction: String
    let live_location: TransitGPS?
    let polyline: [TransitPolylinePoint]
    let timeline: [TransitFullTimelineStop]
}

struct TransitFullTimelineStop: Codable, Hashable {
    let stop_id: String
    let stop_name: String
    let lat: String
    let lng: String
    let status: String // Reached, Upcoming, Arriving
    let eta: String
    let is_major: Bool
}
