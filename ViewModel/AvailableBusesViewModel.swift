import SwiftUI
import Combine
import FirebaseDatabase

class AvailableBusesViewModel: ObservableObject {

    // MARK: - SortOption
    enum SortOption: String, CaseIterable {
        case departureTime = "Departure Time"
        case duration = "Duration"
    }

    @Published var buses: [Bus] = []
    @Published var allRoutes: [RouteModel] = []
    @Published var errorText: String? = nil
    
    @Published var showOnTime = true
    @Published var showDelayed = true
    @Published var sortOption: SortOption = .departureTime

    private let dbRef = Database.database().reference()

    func load(from: String, to: String, via: String?) {
        dbRef.child("routes").observeSingleEvent(of: .value, with: { snapshot in
            var matchedRoutes: [RouteModel] = []

            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot,
                      let dict = childSnapshot.value as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let route = try? JSONDecoder().decode(RouteModel.self, from: data) else { continue }

                let stops = route.stops.map { $0.lowercased() }
                if stops.contains(from.lowercased()) && stops.contains(to.lowercased()) {
                    matchedRoutes.append(route)
                }
            }

            DispatchQueue.main.async {
                self.allRoutes = matchedRoutes
                let repoBuses = BusRepository.shared.allBuses
                self.buses = matchedRoutes.flatMap { route in
                    route.buses.compactMap { busNumber in
                        repoBuses.first(where: { $0.number == busNumber })
                    }
                }
                self.errorText = self.buses.isEmpty ? "No buses found" : nil
            }
        })
    }

    func applyFilterState(from: String, to: String, via: String?) {
        load(from: from, to: to, via: via)
    }
}
