import Foundation

final class BusSearchService {
    static let shared = BusSearchService()
    private init() {}

    func searchBuses(from: String, to: String, via: String? = nil) -> [Bus] {
        let fromTrim = from.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let toTrim = to.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let viaTrim = via?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !fromTrim.isEmpty, !toTrim.isEmpty else { return [] }

        return BusRepository.shared.buses.filter { bus in
            let route = bus.route
            
            // Find indices of from and to stops in the route
            let fromIndex = route.stops.firstIndex { 
                let name = $0.name.lowercased()
                return name.contains(fromTrim) || fromTrim.contains(name)
            }
            let toIndex = route.stops.firstIndex { 
                let name = $0.name.lowercased()
                return name.contains(toTrim) || toTrim.contains(name)
            }
            
            // Direction Validation: 'from' must exist and come before 'to'
            guard let fIdx = fromIndex, let tIdx = toIndex, fIdx < tIdx else { return false }
            
            if let viaQuery = viaTrim, !viaQuery.isEmpty {
                let stopNames = route.stops.map { $0.name.lowercased() }
                return stopNames.contains { $0.contains(viaQuery) }
            }
            
            return true
        }
    }

    func findByNumber(_ number: String) -> Bus? {
        let key = number.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !key.isEmpty else { return nil }
        return BusRepository.shared.buses.first { $0.number.uppercased() == key }
    }

    func findByStop(_ stopName: String) -> [Bus] {
        let key = stopName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return [] }
        return BusRepository.shared.buses.filter { bus in
            bus.route.stops.contains { $0.name.lowercased().contains(key) }
        }
    }
}

