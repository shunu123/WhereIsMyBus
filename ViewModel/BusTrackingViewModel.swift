import Foundation
import SwiftUI
import Combine
import CoreLocation

// 1. HELPER MAP: This tells Swift how to read your JSON structure
struct ScheduleRoot: Codable {
    let route_name: String
    let stops: [BusStop]
}

// BusStop is now defined in Model/BusStop.swift

// 2. VIEWMODEL: This is your main class that matches the file name
class BusTrackingViewModel: ObservableObject {
    @Published var schedule: [BusStop] = []
    @Published var currentBus: VehicleLive?
    @Published var etaMinutes: Int = 0
    
    let busId: String
    private let baseURL = "https://where-is-my-bus-6ae1a-default-rtdb.asia-southeast1.firebasedatabase.app"
    
    init(busId: String) {
        self.busId = busId
        fetchSchedule()
        observeLiveLocation()
    }
    
    func fetchSchedule() {
        // Path: /bus_metadata/101.json
        guard let url = URL(string: "\(baseURL)/bus_metadata/\(busId).json") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data {
                do {
                    // We use the 'ScheduleRoot' map here to find the 'stops' list
                    let decodedData = try JSONDecoder().decode(ScheduleRoot.self, from: data)
                    DispatchQueue.main.async {
                        self.schedule = decodedData.stops
                    }
                } catch {
                    print("Decoding Error: \(error)")
                }
            }
        }.resume()
    }
    
    func observeLiveLocation() {
        // Path: /live_buses/Bus_101.json
        guard let url = URL(string: "\(baseURL)/live_buses/Bus_\(busId).json") else { return }
        
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    do {
                        let location = try JSONDecoder().decode(VehicleLive.self, from: data)
                        DispatchQueue.main.async {
                            self.currentBus = location
                        }
                    } catch {
                        print("Location Error: \(error)")
                    }
                }
            }.resume()
        }
    }
}
