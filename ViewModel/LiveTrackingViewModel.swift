import Foundation
import Combine
import SwiftUI

@MainActor
final class LiveTrackingViewModel: ObservableObject {
    @Published var bus: Bus

    @Published var traveledPath: [Coord] = []
    @Published var fullRoutePath: [Coord] = []
    @Published var currentIndex: Double = 0.0
    @Published var autoRecenter: Bool = true
    @Published var isLive: Bool = true
    @Published var isHistorical: Bool = false {
        didSet { loadHistoryData() }
    }
    @Published var selectedDate: Date = Date() {
        didSet { loadHistoryData() }
    }
    @Published var isHistoryEmpty: Bool = false
    @Published var isHistoryScheduled: Bool = false
    @Published var showScheduledStopsOnly: Bool = false {
        didSet { if showScheduledStopsOnly { populateScheduledHistory() } }
    }
    @Published var historyTripStatus: String? = nil
    @Published var historySearchRange: String? = nil
    @Published var currentSpeed: Int = 0
    @Published var speedKmph: Int? = nil // Requirement B: Live speed
    @Published var lastStopTime: String = "--:--"
    
    var plannedPolyline: [Coord] {
        return fullRoutePath
    }

    var actualPolyline: [Coord] {
        let busToTrack = selectedBusForDetail ?? bus
        if busToTrack.id == bus.id {
            return traveledPath
        } else {
            let pointsPerStop = Double(fullRoutePath.count) / Double(max(1, busToTrack.route.stops.count))
            let stopIdx = busToTrack.currentStopIndex
            let count = Int(Double(stopIdx) * pointsPerStop)
            return Array(fullRoutePath.prefix(max(0, count)))
        }
    }

    // Phase 5: Dynamic Pin Detection
    var deviationStartCoord: Coord? {
        // First point of the first off-route segment
        return actualOffRouteSegments.first?.coords.first
    }

    var rejoiningCoord: Coord? {
        // First point of the last on-route segment, IF there was an off-route segment before it
        guard let firstOffEnd = actualOffRouteSegments.last?.coords.last else { return nil }
        // Find the first on-route point AFTER the last off-route point
        let onSegments = actualOnRouteSegments
        for seg in onSegments {
            if let first = seg.coords.first, actualPolyline.firstIndex(where: { $0.id == first.id }) ?? 0 > actualPolyline.firstIndex(where: { $0.id == firstOffEnd.id }) ?? 0 {
                return first
            }
        }
        return nil
    }
    
    var deviationStartStopIndex: Int? {
        guard let start = deviationStartCoord else { return nil }
        return bus.route.stops.enumerated().min(by: { 
            distance($0.element.coordinate, start) < distance($1.element.coordinate, start)
        })?.offset
    }
    
    @Published var displayedStops: [Stop] = [] // Source-relative stops

    @Published var otherBuses: [Bus] = []
    private var otherBusIndices: [Double] = []

    @Published var showUpcoming: Bool = true
    @Published var showDeparted: Bool = true
    @Published var showScheduled: Bool = false
    
    // alarm
    @Published var alarmStopName: String = ""
    @Published var alarmStopsBefore: Int = 2
    @Published var alarmEnabled: Bool = false
    
    @Published var selectedBusForDetail: Bus?
    
    
    
    var isIsolatedMode: Bool {
        selectedBusForDetail?.isDeviated ?? false
    }

    var reachedStops: [Stop] {
        let busToTrack = selectedBusForDetail ?? bus
        let idx = (busToTrack.id == bus.id) ? Int(currentIndex) : (busToTrack.currentStopIndex * Int(Double(fullRoutePath.count) / Double(max(1, bus.route.stops.count))))
        let pointsPerStop = Double(fullRoutePath.count) / Double(max(1, bus.route.stops.count))
        let currentStopIdxInt = Int(Double(idx) / pointsPerStop)
        return Array(bus.route.stops.prefix(currentStopIdxInt + 1))
    }

    var actualOnRouteSegments: [PathSegment] {
        return deriveActualSegments(fullRoute: fullRoutePath, actualPath: actualPolyline, findDiverted: false)
    }

    var actualOffRouteSegments: [PathSegment] {
        return deriveActualSegments(fullRoute: fullRoutePath, actualPath: actualPolyline, findDiverted: true)
    }

    private func deriveActualSegments(fullRoute: [Coord], actualPath: [Coord], findDiverted: Bool) -> [PathSegment] {
        guard !actualPath.isEmpty else { return [] }
        var segments: [PathSegment] = []
        var currentCoords: [Coord] = []
        
        let tolerance = 0.0005 // Approx 50 meters
        
        for coord in actualPath {
            let isOffRoute = !fullRoute.contains(where: { distance($0, coord) < tolerance })
            let matchesTarget = (isOffRoute == findDiverted)
            
            if matchesTarget {
                currentCoords.append(coord)
            } else if !currentCoords.isEmpty {
                segments.append(PathSegment(coords: currentCoords, isDiverted: findDiverted))
                currentCoords = []
            }
        }
        if !currentCoords.isEmpty {
            segments.append(PathSegment(coords: currentCoords, isDiverted: findDiverted))
        }
        return segments
    }

    private var timer: Timer?
    private var haltTicks: Int = 0

    var isFuture: Bool {
        Calendar.current.startOfDay(for: selectedDate) > Calendar.current.startOfDay(for: Date())
    }

    init(bus: Bus, isHistorical: Bool = false, date: Date? = nil, sourceStop: String? = nil) {
        self.bus = bus
        self.selectedDate = date ?? Date()
        
        // 1. Filter stops relative to sourceStop if provided
        var displayStops = bus.route.stops
        if let source = sourceStop {
            let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let sourceIndex = displayStops.firstIndex(where: { 
                let name = $0.name.lowercased()
                return name.contains(normalizedSource) || normalizedSource.contains(name)
            }) {
                displayStops = Array(displayStops[sourceIndex...])
            }
        }
        self.displayedStops = displayStops
        
        // 2. Build path from relevant stops only
        let plannedPath = TrackingSimulationService.shared.buildPath(stops: displayStops)
        self.bus.route.plannedPolyline = plannedPath
        
        var path = plannedPath
        // Simulate diversion in the ACTUAL path only
        if bus.isDeviated {
            let startDivert = Int(Double(path.count) * 0.4)
            let endDivert = Int(Double(path.count) * 0.6)
            // Offset the coordinates to show actual deviation from the planned path
            for i in startDivert..<endDivert {
                path[i] = Coord(lat: path[i].lat + 0.005, lon: path[i].lon + 0.005, isDiverted: true)
            }
        }
        
        self.fullRoutePath = path
        self.isHistorical = isHistorical
        
        if isHistorical || isFuture {
            self.traveledPath = isFuture ? [] : path
            self.currentIndex = isFuture ? 0.0 : Double(max(0, path.count - 1))
        } else {
            self.traveledPath = []
            self.currentIndex = 0.0
            
            // Load other buses on the same route
            let all = BusRepository.shared.allBuses
            self.otherBuses = all.filter { b in
                b.id != bus.id && 
                b.route.from == bus.route.from && 
                b.route.to == bus.route.to &&
                b.trackingStatus != .scheduled && b.trackingStatus != .ended
            }
            // Initialize their indices randomly? No, rely on their actual positions.
            // We just clear indices logic for now or derive it from their telemetry.
            self.otherBusIndices = Array(repeating: 0.0, count: self.otherBuses.count)
        }
        
        loadHistoryData()
    }

    private func populateScheduledHistory() {
        let stopsToTrack = self.displayedStops.isEmpty ? self.bus.route.stops : self.displayedStops
        self.bus.historyStops = stopsToTrack.map { HistoryStop(stopName: $0.name, reachedTime: nil) }
        self.fullRoutePath = TrackingSimulationService.shared.buildPath(stops: stopsToTrack)
        self.traveledPath = []
        self.currentIndex = 0
    }

    private func loadHistoryData() {
        self.selectedBusForDetail = nil // Requirement: History mode tracks primary bus only
        self.showScheduledStopsOnly = false
        
        // Force live mode if today is selected
        if Calendar.current.isDateInToday(self.selectedDate) && isHistorical {
            self.isHistorical = false
            return
        }
        
        if isHistorical {
            // 1. Calculate IST Range (Requirement: 00:00:00 to 23:59:59 IST)
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: self.selectedDate)
            components.hour = 0
            components.minute = 0
            components.second = 0
            let start = calendar.date(from: components) ?? self.selectedDate
            components.hour = 23
            components.minute = 59
            components.second = 59
            let end = calendar.date(from: components) ?? self.selectedDate
            
            let df = DateFormatter()
            df.dateFormat = "MMM dd, HH:mm"
            self.historySearchRange = "\(df.string(from: start)) — \(df.string(from: end))"
            
            // 2. Check Schedule (Simulated: Scheduled for weekdays)
            let weekday = calendar.component(.weekday, from: self.selectedDate)
            self.isHistoryScheduled = (weekday >= 2 && weekday <= 6) // Mon-Fri
            
            // 3. Fetch History Record (Simulated Range Query)
            let dateKey = DateFormatter(); dateKey.dateFormat = "yyyy-MM-dd"
            let key = dateKey.string(from: self.selectedDate)
            
            // In a real API, we'd fetch all records in (start...end)
            // Here we check if any trip exists
            if let record = bus.tripHistory[key] {
                // If multiple trips existed, we'd pick the one closest to bus.departsAt
                // For simulation, we just take the one found.
                self.isHistoryEmpty = false
                self.isHistoryScheduled = true // If a record exists, it was scheduled!
                self.bus.isDeviated = record.isDeviated
                self.bus.historyStops = record.historyStops
                self.bus.actualPolyline = record.actualPolyline
                self.bus.route.plannedPolyline = record.plannedPolyline
                self.fullRoutePath = record.isDeviated ? record.actualPolyline : record.plannedPolyline
                
                // Requirement 3: Strictly use history record status
                self.historyTripStatus = record.status
                self.bus.hasReachedDestination = true 
            } else {
                self.isHistoryEmpty = true
                self.historyTripStatus = nil
                self.bus.historyStops = []
                self.bus.actualPolyline = []
                
                // Provide theoretical path for "View Scheduled Stops" feature
                let stopsToTrack = self.displayedStops.isEmpty ? self.bus.route.stops : self.displayedStops
                self.fullRoutePath = TrackingSimulationService.shared.buildPath(stops: stopsToTrack)
            }
        } else {
            self.isHistoryEmpty = false
            self.isHistoryScheduled = true
            self.historySearchRange = nil
            // Live mode starts with empty history, populated as it moves
            let stopsToTrack = self.displayedStops.isEmpty ? self.bus.route.stops : self.displayedStops
            self.bus.historyStops = stopsToTrack.map { HistoryStop(stopName: $0.name, reachedTime: nil) }
        }
        
        // Refresh position/path if already started
        if isHistorical && !isHistoryEmpty {
            self.traveledPath = fullRoutePath
            self.currentIndex = Double(max(0, fullRoutePath.count - 1))
        } else if isHistorical && showScheduledStopsOnly {
            self.traveledPath = []
            self.currentIndex = 0
        }
    }

    var stops: [Stop] { displayedStops }

    var currentCoordinate: Coord {
        if fullRoutePath.isEmpty { return bus.route.stops.first?.coordinate ?? Coord(lat: 12.9716, lon: 77.5946) }
        let idx = Int(min(currentIndex, Double(fullRoutePath.count - 1)))
        return fullRoutePath[idx]
    }

    // Backend Integration
    // We rely on BusRepository which syncs with BackendAPI
    private func fetchBackendData() {
        // Sync self.bus with Repository
        if let updated = BusRepository.shared.bus(by: bus.id) {
            self.bus = updated
        }
        
        // Update other buses
        let all = BusRepository.shared.allBuses
        self.otherBuses = all.filter { b in
             b.id != bus.id && 
             b.route.from == bus.route.from && 
             b.route.to == bus.route.to &&
             (b.trackingStatus == .arriving || b.trackingStatus == .departed || b.trackingStatus == .halted)
        }
    }

    func start() {
        print("LiveTrackingViewModel: Starting... isHistorical=\(isHistorical)")
        stop()
        
        fetchBackendData()
        
        if isHistorical || isFuture {
            self.traveledPath = isFuture ? [] : fullRoutePath
            self.currentIndex = isFuture ? 0.0 : Double(max(0, fullRoutePath.count - 1))
            return
        }
        
        isLive = true
        // Every 0.5s we move bit by bit
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                withAnimation(.linear(duration: 0.5)) {
                    self.tick()
                }
            }
        }
    }
    
    func refresh() {
        Task { @MainActor in
            self.tick()
        }
        fetchBackendData()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !fullRoutePath.isEmpty else { return }
        
        // Pull latest state from Repository
        fetchBackendData()

        if isHistorical { return }

        // Live Mode Logic:
        // Update traveled path from bus data
        if !bus.actualPolyline.isEmpty {
            self.traveledPath = bus.actualPolyline
            
            // Update currentIndex based on last position
            if let lastPos = bus.actualPolyline.last {
                if let closestIdx = findClosestIndex(on: fullRoutePath, to: lastPos) {
                     self.currentIndex = Double(closestIdx)
                     let totalPoints = Double(fullRoutePath.count)
                     let stopsCount = Double(max(1, bus.route.stops.count))
                     self.bus.currentStopIndex = Int(Double(closestIdx) / (totalPoints / stopsCount))
                }
            }
        }
        
        // Update telemetry
        self.currentSpeed = Int(bus.liveTelemetry.speed)
        self.speedKmph = self.currentSpeed
        
        // 6. Calculate last major stop time and update historyStops
        let pointsPerStop = Double(fullRoutePath.count) / Double(max(1, bus.route.stops.count))
        let currentStopIndexInt = Int(currentIndex / pointsPerStop) // Approximate from index
        let passedStops = bus.route.stops.prefix(currentStopIndexInt + 1)
        
        // Update historyStops for live bus
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let nowStr = formatter.string(from: Date())
        
        for i in 0...currentStopIndexInt {
            if i < bus.historyStops.count && bus.historyStops[i].reachedTime == nil {
                bus.historyStops[i] = HistoryStop(stopName: bus.route.stops[i].name, reachedTime: nowStr)
            }
        }

        if let lastMajorStop = passedStops.last(where: { $0.isMajorStop }) {
            lastStopTime = lastMajorStop.timeText ?? "--:--"
        } else {
            lastStopTime = bus.route.stops.first?.timeText ?? "--:--"
        }
        
        // 7. Reached Destination Logic
        if currentIndex >= Double(fullRoutePath.count - 1) && !bus.hasReachedDestination {
            bus.hasReachedDestination = true
            bus.trackingStatus = .ended
            bus.totalTripDuration = Int(currentIndex / 0.02) * 5 / 60 // Simulated duration estimate
        }

        // 7. Alarm trigger logic
        if alarmEnabled, !alarmStopName.isEmpty {
            if let targetIdx = bus.route.stops.firstIndex(where: { $0.name == alarmStopName }) {
                if currentStopIndexInt >= max(0, targetIdx - alarmStopsBefore) {
                    alarmEnabled = false
                }
            }
        }
    }
    
    private func findClosestIndex(on path: [Coord], to target: Coord) -> Int? {
        var minDst = Double.greatestFiniteMagnitude
        var minIdx: Int? = nil
        let strideVal = 5
        for i in stride(from: 0, to: path.count, by: strideVal) {
            let dst = distance(path[i], target)
            if dst < minDst {
                minDst = dst
                minIdx = i
            }
        }
        return minIdx
    }
    
    // updateOtherBuses removed as we rely on backend data
    private func updateOtherBuses() {
        // No-op or removed. Keeping empty method if called elsewhere, 
        // but I removed the call in tick, so safe to remove.
        // Actually, ensuring filteredOtherBuses logic works without indices updates.
        // Since we update otherBuses in fetchBackendData, we don't need to simulate movement.
    }
    
    // Requirement B: Helper properties
    var nextStop: Stop? {
        let busToTrack = selectedBusForDetail ?? bus
        let liveIndexValue = (busToTrack.id == bus.id) ? Int(currentIndex / (Double(fullRoutePath.count) / Double(max(1, bus.route.stops.count)))) : busToTrack.currentStopIndex
        if liveIndexValue + 1 < bus.route.stops.count {
            return bus.route.stops[liveIndexValue + 1]
        }
        return nil
    }
    
    var durationToDestination: Int {
        let busToTrack = selectedBusForDetail ?? bus
        let liveIndexValue = (busToTrack.id == bus.id) ? Int(currentIndex / (Double(fullRoutePath.count) / Double(max(1, bus.route.stops.count)))) : busToTrack.currentStopIndex
        let remainingStops = max(0, bus.route.stops.count - 1 - liveIndexValue)
        return remainingStops * 10 
    }
    
    // Phase 2: Nearest Stop Logic
    var nearestStopName: String {
        let busToTrack = selectedBusForDetail ?? bus
        let currentCoord = (busToTrack.id == bus.id) ? currentCoordinate : (busToTrack.route.stops[busToTrack.currentStopIndex].coordinate)
        
        let sortedStops = busToTrack.route.stops.sorted { s1, s2 in
            let d1 = distance(currentCoord, s1.coordinate)
            let d2 = distance(currentCoord, s2.coordinate)
            return d1 < d2
        }
        
        if let nearest = sortedStops.first, distance(currentCoord, nearest.coordinate) < 0.005 {
            return nearest.name
        }
        return ""
    }
    
    private func distance(_ c1: Coord, _ c2: Coord) -> Double {
        let dLat = c1.lat - c2.lat
        let dLon = c1.lon - c2.lon
        return sqrt(dLat * dLat + dLon * dLon)
    }
}
