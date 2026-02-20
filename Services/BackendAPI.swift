import Foundation

// Custom error handling for clearer debugging
enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noData
}

// Model for Search Suggestions (Stops)
struct StopResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let lat: Double
    let lng: Double
}

// Model for Historical Movement (30-day storage)
struct VehicleHistoryPoint: Codable {
    let lat: Double
    let lng: Double
    let timestamp: String // ISO8601 string: "2026-02-19T10:00:00Z"
    let speed: Double?
    let heading: Double?
}

final class BackendAPI {
    static let shared = BackendAPI()
    private let baseURL = "https://where-is-my-bus-6ae1a-default-rtdb.asia-southeast1.firebasedatabase.app"
    
    private init() {}
    
    // MARK: - Live Tracking (Map & ETA)
    /// Fetches the live location for one specific bus (e.g., "Bus_101")
    // Change your existing methods to look like this:
    // MARK: - Scalable Fetching
    // MARK: - Scalable Fetching
    func fetchBusLive(id: String) async throws -> VehicleLive {
        guard let url = URL(string: "\(baseURL)/live_sync/\(id).json") else { throw APIError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(VehicleLive.self, from: data)
    }

    func fetchBusSchedule(id: String) async throws -> [BusStop] {
        // Fetches the specific stops for the specific bus ID
        guard let url = URL(string: "\(baseURL)/bus_metadata/\(id)/stops.json") else { throw APIError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([BusStop].self, from: data)
    }
    // MARK: - Search & Suggestions
    /// Fetches all stops to filter for suggestions (e.g., "Saveetha Engineering College")
    func fetchStops(query: String) async throws -> [StopResponse] {
        guard let url = URL(string: "\(baseURL)/stops.json") else { throw APIError.invalidURL }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let allStops = try JSONDecoder().decode([StopResponse].self, from: data)
        
        return allStops.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    // MARK: - 30-Day History (Timeline)
    /// Fetches history for a specific bus ID on a specific date (YYYY-MM-DD)
    /// This prevents downloading too much data at once.
    func fetchVehicleHistory(busId: String, date: String) async throws -> [VehicleHistoryPoint] {
        guard let url = URL(string: "\(baseURL)/vehicle_history/\(busId)/\(date).json") else {
            throw APIError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Firebase 'POST' data returns a dictionary [UniqueKey: Data]
        let dict = try JSONDecoder().decode([String: VehicleHistoryPoint].self, from: data)
        
        // Sort points by time so the timeline is chronological
        return dict.values.sorted { $0.timestamp < $1.timestamp }
    }
}
