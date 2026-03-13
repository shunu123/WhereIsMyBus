import Foundation

@MainActor
final class StopSuggestionService {
    static let shared = StopSuggestionService()
    private init() {}

    // Debounce task to avoid spamming backend on every keystroke
    private var debounceTask: Task<Void, Never>?

    // MARK: - Public API

    /// Returns live suggestions from the backend for a given query (min 2 chars).
    func suggestions(query: String) async -> [BusStop] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        do {
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            let url = URL(string: "\(APIConfig.baseURL)/api/search/suggestions?q=\(encoded)")!
            var request = URLRequest(url: url)
            request.addValue("true", forHTTPHeaderField: "bypass-tunnel-reminder")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: request)

            struct Response: Decodable {
                let ok: Bool
                let suggestions: [StopSuggestion]
            }
            struct StopSuggestion: Decodable {
                let id: Int
                let name: String
                let lat: Double?
                let lng: Double?
            }

            let decoded = try JSONDecoder().decode(Response.self, from: data)
            return decoded.suggestions.map { BusStop(id: "\($0.id)", name: $0.name, lat: $0.lat ?? 0, lng: $0.lng ?? 0) }
        } catch {
            print("StopSuggestionService error:", error.localizedDescription)
            return []
        }
    }

    /// Pre-warm — no-op with live backend search.
    func prefetch() {}

    /// Force-refresh — no-op with live backend search.
    func invalidateCache() {}
}
