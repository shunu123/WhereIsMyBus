import Foundation

struct VehicleLive: Codable, Identifiable, Sendable {
    var id: String { vehicleNumber ?? UUID().uuidString }
    let vehicleNumber: String?
    let latitude: Double?
    let longitude: Double?
    let speed: Double?
    
    // Helpers to prevent crashes if Firebase data is missing
    var lat: Double { latitude ?? 0.0 }
    var lng: Double { longitude ?? 0.0 }
    var velocity: Double { speed ?? 0.0 }
}
