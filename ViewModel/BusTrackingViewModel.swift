import Foundation
import SwiftUI
import Combine
import CoreLocation

// VIEWMODEL: Fetches bus schedule and live location from FastAPI
@MainActor
class BusTrackingViewModel: ObservableObject {
    @Published var schedule: [TimelineStop] = []
    @Published var currentBus: GPSPoint?
    @Published var etaMinutes: Int = 0
    @Published var isLoading: Bool = false
    
    let tripId: String
    
    init(tripId: String) {
        self.tripId = tripId
        Task { await fetchSchedule() }
        Task { await observeLiveLocation() }
    }
    
    func fetchSchedule() async {
        isLoading = true
        do {
            // Support both internal (INT) and external (STRING) IDs
            if let intId = Int(tripId) {
                self.schedule = try await APIService.shared.fetchTimeline(tripId: intId)
            } else {
                self.schedule = try await APIService.shared.fetchTimeline(extTripId: tripId)
            }
        } catch {
            print("Schedule Fetch Error: \(error)")
        }
        isLoading = false
    }
    
    func observeLiveLocation() async {
        // Poll every 5-10 seconds for live GPS from our backend
        while !Task.isCancelled {
            do {
                let tid = Int(tripId)
                let etid = tid == nil ? tripId : nil
                
                if let location = try await APIService.shared.fetchLatestGPS(tripId: tid, extTripId: etid) {
                    self.currentBus = location

                    // Real ETA: use delay_min from GTFS-RT if available
                    if let delayMin = location.delay_min, delayMin > 0 {
                        self.etaMinutes = Int(delayMin.rounded())
                    } else if let lastStop = schedule.last, let delay = lastStop.delaySec {
                        // Fallback: scheduled time remaining to last stop
                        self.etaMinutes = delay / 60
                    }
                }
            } catch {
                print("Live Location Error: \(error)")
            }
            try? await Task.sleep(nanoseconds: 7_000_000_000) // 7 seconds
        }
    }
}
