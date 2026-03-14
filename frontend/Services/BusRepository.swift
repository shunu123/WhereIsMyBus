import Foundation
import Combine

@MainActor
final class BusRepository: ObservableObject {
    static let shared = BusRepository()

    @Published private(set) var buses: [Bus] = []
    var allBuses: [Bus] { buses }
    private var timer: Timer?

    private var lastUpdateTime: Date = Date()
    private let updateInterval: TimeInterval = 1.0 // Minimum 1s between full UI refreshes
    
    func notifyUpdate() {
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) >= updateInterval {
            lastUpdateTime = now
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    private init() {
        startDailyLoad()
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
    
    /// Register (or update) a bus in the repository. Used when search results
    /// hydrate a bus with full stop data.
    func register(bus: Bus) {
        if let idx = buses.firstIndex(where: { $0.id == bus.id }) {
            buses[idx] = bus
        } else {
            buses.append(bus)
        }
    }
    
    func ensureStops(for busID: UUID) async {
        guard let idx = buses.firstIndex(where: { $0.id == busID }) else { return }
        let bus = buses[idx]
        if !bus.route.stops.isEmpty { return }
        
        do {
            let stops = try await APIService.shared.fetchTimeline(tripId: bus.vehicleId, extTripId: bus.extTripId)
            await MainActor.run {
                if let currentIdx = self.buses.firstIndex(where: { $0.id == busID }) {
                    let parsedStops = stops.map { $0.toStop() }
                    self.buses[currentIdx].route.stops = parsedStops
                    self.buses[currentIdx].route.plannedPolyline = TrackingSimulationService.shared.buildPath(stops: parsedStops)
                }
            }
        } catch {
            print("Failed to ensure stops for \(bus.number): \(error)")
        }
    }
    
    // MARK: - Live Sync
    
    func startDailyLoad() {
        Task {
            do {
                let dailyTrips = try await APIService.shared.fetchBuses()
                var newBuses: [Bus] = []
                
                for trip in dailyTrips {
                    var departsAtStr = "--"
                    if let depTime = trip.firstDeparture {
                        let ds = depTime.replacingOccurrences(of: "Z", with: "")
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        var date = formatter.date(from: depTime)
                        if date == nil {
                            formatter.formatOptions = [.withInternetDateTime]
                            date = formatter.date(from: depTime)
                        }
                        if date == nil {
                            // Try parsing "2026-02-28T12:00:00" or similar
                            let f = DateFormatter()
                            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                            f.locale = Locale(identifier: "en_US_POSIX")
                            date = f.date(from: ds)
                        }
                        
                        if let d = date {
                            let tf = DateFormatter()
                            tf.timeZone = TimeZone(identifier: "Asia/Kolkata")
                            tf.dateFormat = "hh:mm a"
                            departsAtStr = tf.string(from: d)
                        } else {
                            let parts = depTime.components(separatedBy: "T")
                            if parts.count > 1 {
                                let timeParts = parts[1].components(separatedBy: ":")
                                if timeParts.count >= 2, let hr = Int(timeParts[0]) {
                                    let ampm = hr >= 12 ? "PM" : "AM"
                                    let hr12 = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr)
                                    departsAtStr = String(format: "%02d:%@ %@", hr12, timeParts[1], ampm)
                                }
                            }
                        }
                    }
                    
                    var fromName = "System Route"
                    var toName = "Destination"
                    
                    if let routeName = trip.routeName {
                        if routeName.contains(" - ") {
                            let parts = routeName.components(separatedBy: " - ")
                            fromName = parts.first ?? fromName
                            toName = parts.last ?? toName
                        } else if routeName.contains(" to ") {
                            let parts = routeName.components(separatedBy: " to ")
                            fromName = parts.first ?? fromName
                            toName = parts.last ?? toName
                        } else if routeName.contains(" via ") {
                            let parts = routeName.components(separatedBy: " via ")
                            fromName = parts.first ?? fromName
                        } else {
                            fromName = routeName
                        }
                    }
                    
                    let route = Route(from: fromName, to: toName, stops: [])
                    
                    var bus = Bus(
                        id: UUID(),
                        number: trip.busNo ?? "N/A",
                        headsign: trip.label ?? trip.routeName ?? "College Bus",
                        departsAt: departsAtStr,
                        durationText: "--",
                        status: .onTime,
                        statusDetail: "Scheduled",
                        trackingStatus: .scheduled,
                        etaMinutes: nil,
                        route: route,
                        vehicleId: trip.tripId,
                        busId: trip.busId,
                        extTripId: trip.extTripId
                    )
                    newBuses.append(bus)
                }
                
                await MainActor.run {
                    for newBus in newBuses {
                        if let existingIdx = self.buses.firstIndex(where: { $0.vehicleId == newBus.vehicleId }) {
                            // Merge: Preserve original ID, detailed route stops, and telemetry
                            var merged = newBus
                            merged.id = self.buses[existingIdx].id
                            
                            // IF the existing bus has a richer route (stops), keep it
                            if self.buses[existingIdx].route.stops.count > merged.route.stops.count {
                                merged.route = self.buses[existingIdx].route
                            }
                            
                            // Preserve telemetry
                            merged.actualPolyline = self.buses[existingIdx].actualPolyline
                            merged.liveTelemetry = self.buses[existingIdx].liveTelemetry
                            merged.trackingStatus = self.buses[existingIdx].trackingStatus
                            merged.statusDetail = self.buses[existingIdx].statusDetail
                            
                            self.buses[existingIdx] = merged
                        } else {
                            self.buses.append(newBus)
                        }
                    }
                }
            } catch {
                print("Failed to load daily buses:", error)
            }
        }
    }
    
    func startLiveSync() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.syncCoords()
            }
        }
    }
    
    func updateBusTelemetry(id: UUID, point: Coord, speed: Double, timestampRaw: String?) {
        if let idx = buses.firstIndex(where: { $0.id == id }) {
            buses[idx].liveTelemetry.speed = speed
            buses[idx].liveTelemetry.speedKmph = Int(speed)
            
            // Parse GPS timestamp
            if let tsString = timestampRaw {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: tsString) {
                    buses[idx].liveTelemetry.lastUpdate = date
                } else {
                    formatter.formatOptions = [.withInternetDateTime]
                    if let date = formatter.date(from: tsString) {
                        buses[idx].liveTelemetry.lastUpdate = date
                    } else {
                        buses[idx].liveTelemetry.lastUpdate = Date()
                    }
                }
            } else {
                buses[idx].liveTelemetry.lastUpdate = Date()
            }
            
            // Status and Tracking Updates
            // Status and Tracking Updates - Throttled/Debounced
            let speedThreshold = 2.0 // KM/H
            if speed > speedThreshold {
                if buses[idx].trackingStatus != .arriving {
                    buses[idx].trackingStatus = .arriving
                    buses[idx].statusDetail = "Running"
                    buses[idx].liveTelemetry.isHalted = false
                }
            } else if speed <= 1.0 { // Must be significantly slow to halt
                if buses[idx].trackingStatus != .halted {
                    buses[idx].trackingStatus = .halted
                    buses[idx].statusDetail = "Stopped"
                    buses[idx].liveTelemetry.isHalted = true
                }
            }
            
            // Update actual polyline if point is new/significant
            if let last = buses[idx].actualPolyline.last {
                if distance(last, point) > 0.00005 { // Approx 5 meters
                    buses[idx].actualPolyline.append(point)
                }
            } else {
                buses[idx].actualPolyline.append(point)
                notifyUpdate()
            }
        }
    }
    
    private func syncCoords() async {
        do {
            let liveData = try await APIService.shared.fetchLiveFleetGPS()
            print("Syncing Fleet: Received \(liveData.count) GPS points from backend")
            
            var liveMapById: [Int: GPSPoint] = [:]
            var liveMapByExt: [String: GPSPoint] = [:]
            
            for pt in liveData {
                if let tid = pt.trip_id {
                    liveMapById[tid] = pt
                }
                if let etid = pt.ext_trip_id {
                    liveMapByExt[etid] = pt
                }
            }
            
            await MainActor.run {
                for i in 0..<self.buses.count {
                    let bus = self.buses[i]
                    var match: GPSPoint? = nil
                    
                    if let extId = bus.extTripId, let gps = liveMapByExt[extId] {
                        match = gps
                    } else if let tid = bus.vehicleId, let gps = liveMapById[tid] {
                        match = gps
                    }
                    
                    if let gps = match {
                        let point = Coord(lat: gps.lat, lon: gps.lng)
                        let spd = gps.speed ?? 0.0
                        
                        self.buses[i].liveTelemetry.speed = spd
                        self.buses[i].liveTelemetry.speedKmph = Int(spd)
                        
                        if let tsString = gps.ts {
                            let formatter = ISO8601DateFormatter()
                            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            if let date = formatter.date(from: tsString) {
                                self.buses[i].liveTelemetry.lastUpdate = date
                            } else {
                                formatter.formatOptions = [.withInternetDateTime]
                                if let date = formatter.date(from: tsString) {
                                    self.buses[i].liveTelemetry.lastUpdate = date
                                } else {
                                    self.buses[i].liveTelemetry.lastUpdate = Date()
                                }
                            }
                        } else {
                            self.buses[i].liveTelemetry.lastUpdate = Date()
                        }
                        
                        let speedThreshold = 2.0 // KM/H
                        if spd > speedThreshold {
                            self.buses[i].trackingStatus = .arriving
                            self.buses[i].statusDetail = "Running"
                            self.buses[i].liveTelemetry.isHalted = false
                        } else if spd <= 1.0 {
                            self.buses[i].trackingStatus = .halted
                            self.buses[i].statusDetail = "Stopped"
                            self.buses[i].liveTelemetry.isHalted = true
                        }
                        
                        if let last = self.buses[i].actualPolyline.last {
                            if self.distance(last, point) > 0.0001 {
                                self.buses[i].actualPolyline.append(point)
                            }
                        } else {
                            self.buses[i].actualPolyline.append(point)
                        }
                    }
                }
            }
            self.notifyUpdate()
        } catch {
            print("SyncCoords failed:", error)
        }
    }
    
    func stopLiveSync() {
        timer?.invalidate()
        timer = nil
    }
    
    private func distance(_ c1: Coord, _ c2: Coord) -> Double {
        let dLat = c1.lat - c2.lat
        let dLon = c1.lon - c2.lon
        return sqrt(dLat * dLat + dLon * dLon)
    }
}

extension TimelineStop {
    func toStop() -> Stop {
        var timeText: String? = nil
        var date: Date? = nil
        let displayTimeStr = realtimeEta ?? schedArrival
        
        if let timeStr = displayTimeStr {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = formatter.date(from: timeStr)
            if date == nil {
                let basicFormatter = ISO8601DateFormatter()
                date = basicFormatter.date(from: timeStr)
            }
            
            if date == nil {
                let timeOnly = timeStr.count > 8 ? String(timeStr.prefix(8)) : timeStr
                let f = DateFormatter()
                f.dateFormat = "HH:mm:ss"
                // Crucial for pure time strings without dates attached
                f.defaultDate = Date() 
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone(identifier: "America/Chicago")
                date = f.date(from: timeOnly)
            }
            
            if let d = date {
                let tf = DateFormatter()
                tf.timeZone = TimeZone(identifier: "America/Chicago")
                tf.dateFormat = "hh:mm a"
                timeText = tf.string(from: d)
            }
        }
        
        return Stop(
            id: "\(stopId)",
            name: stopName,
            coordinate: Coord(lat: lat, lon: lng),
            timeText: timeText,
            isMajorStop: true,
            stopOrder: stopOrder,
            realtimeArrival: date
        )
    }
}
