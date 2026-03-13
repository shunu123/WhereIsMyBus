import Foundation

/// Persists recently searched bus numbers.
final class BusSearchHistoryService {
    static let shared = BusSearchHistoryService()
    private let key = "bus_number_history"
    private let maxItems = 10

    private init() {}

    func all() -> [String] {
        return UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func save(_ number: String) {
        let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        
        var current = all()
        current.removeAll { $0 == trimmed }
        current.insert(trimmed, at: 0)
        
        if current.count > maxItems {
            current = Array(current.prefix(maxItems))
        }
        UserDefaults.standard.set(current, forKey: key)
    }

    func remove(_ number: String) {
        var current = all()
        current.removeAll { $0 == number }
        UserDefaults.standard.set(current, forKey: key)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
