import Foundation

/// Persists and retrieves search history (from/to pairs) using UserDefaults.
final class SearchHistoryService {
    static let shared = SearchHistoryService()
    private let key = "search_history"
    private let maxItems = 20

    private init() {}

    /// All saved searches, newest first.
    func all() -> [(from: String, to: String)] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([[String]].self, from: data)
        else { return [] }
        return decoded.compactMap {
            guard $0.count == 2 else { return nil }
            return (from: $0[0], to: $0[1])
        }
    }

    /// Save a new search. Deduplicates and limits to maxItems.
    func save(from: String, to: String) {
        var current = all()
        // Remove duplicate
        current.removeAll { $0.from == from && $0.to == to }
        // Prepend newest
        current.insert((from: from, to: to), at: 0)
        // Trim
        if current.count > maxItems { current = Array(current.prefix(maxItems)) }
        encode(current)
    }

    /// Remove a specific item by index.
    func remove(at index: Int) {
        var current = all()
        guard current.indices.contains(index) else { return }
        current.remove(at: index)
        encode(current)
    }

    /// Clear all history.
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func encode(_ items: [(from: String, to: String)]) {
        let raw = items.map { [$0.from, $0.to] }
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
