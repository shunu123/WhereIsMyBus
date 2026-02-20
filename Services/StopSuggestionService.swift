import Foundation

final class StopSuggestionService {
    static let shared = StopSuggestionService()
    private init() {}

    /// Fetches stop suggestions from the backend only.
    /// Returns empty when the query is blank or the backend is unreachable.
    func suggest(query: String, city: String = "") async -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        do {
            let stops = try await BackendAPI.shared.fetchStops(query: q)
            return stops.map { $0.name }
        } catch {
            print("StopSuggestionService: backend unavailable — \(error)")
            return []
        }
    }
}
