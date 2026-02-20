import Foundation
import Combine
import FirebaseDatabase

@MainActor
final class BusRepository: ObservableObject {
    static let shared = BusRepository()

    @Published private(set) var buses: [Bus] = []
    var allBuses: [Bus] { buses }
    private var timer: Timer?

    private init() {
        startLiveSync()
    }

    func bus(by id: UUID) -> Bus? {
        buses.first { $0.id == id }
    }
    
    func bus(byNumber number: String) -> Bus? {
        buses.first { $0.number == number }
    }

    func allRoutes() -> [Route] {
        Array(Set(buses.map { $0.route }))
            .sorted { $0.from < $1.from }
    }
    
    // MARK: - Live Sync
    
    func startLiveSync() {
        // Use Firebase Realtime Database
        let ref = Database.database().reference().child("live_buses")
        
        // Listen for value changes
        ref.observe(.value, with: { [weak self] snapshot in
            guard let self = self else { return }
            var newVehicles: [VehicleLive] = []
            
            // Each child under "live_buses" is a bus entry (e.g. "Bus_101")
            for case let child as DataSnapshot in snapshot.children {
                guard let dict = child.value as? [String: Any] else { continue }
                
                // Parse the flat dictionary pushed by BusTrackerService
                let lat = dict["latitude"] as? Double
                let lng = dict["longitude"] as? Double
                let speed = dict["speed"] as? Double
                let busKey = child.key // e.g. "Bus_101"
                
                let vehicle = VehicleLive(
                    vehicleNumber: busKey,
                    latitude: lat,
                    longitude: lng,
                    speed: speed
                )
                newVehicles.append(vehicle)
            }
            
            self.updateBuses(with: newVehicles)
        })
    }
    
    func stopLiveSync() {
        let ref = Database.database().reference().child("live_buses")
        ref.removeAllObservers()
    }
    
    private func updateBuses(with availableVehicles: [VehicleLive]) {
        for vehicle in availableVehicles {
            let vNumber = vehicle.vehicleNumber ?? "Unknown"
            
            if let index = buses.firstIndex(where: { $0.number == vNumber }) {
                 updateBus(at: index, with: vehicle)
            } else if buses.first != nil {
                // FALLBACK: If number doesn't match, update the first bus for DEMO
                if let idx = buses.firstIndex(where: { _ in true }) {
                    updateBus(at: idx, with: vehicle)
                }
            }
        }
    }
    
    private func updateBus(at index: Int, with vehicle: VehicleLive) {
        var bus = buses[index]
        let spd = vehicle.velocity
        bus.liveTelemetry.speed = spd
        bus.liveTelemetry.speedKmph = Int(spd)
        bus.liveTelemetry.lastUpdate = Date()
        
        if spd > 0 {
            bus.trackingStatus = .arriving
            bus.liveTelemetry.isHalted = false
        } else {
            bus.trackingStatus = .halted
            bus.liveTelemetry.isHalted = true
        }
        
        let newCoord = Coord(lat: vehicle.lat, lon: vehicle.lng)
        if let last = bus.actualPolyline.last {
            if distance(last, newCoord) > 0.0001 {
                bus.actualPolyline.append(newCoord)
            }
        } else {
            bus.actualPolyline.append(newCoord)
        }
        
        buses[index] = bus
    }
    
    private func distance(_ c1: Coord, _ c2: Coord) -> Double {
        let dLat = c1.lat - c2.lat
        let dLon = c1.lon - c2.lon
        return sqrt(dLat * dLat + dLon * dLon)
    }
}
