import SwiftUI
import FirebaseDatabase

struct RouteSelectionView: View {
    @State private var routes: [RouteModel] = []
    private let ref = Database.database().reference().child("routes")

    var body: some View {
        NavigationView {
            List(routes) { route in
                NavigationLink(destination: BusTimelineView(route: route)) {
                    VStack(alignment: .leading) {
                        Text(route.route_id).font(.headline)
                        Text("\(route.from_location) ➔ \(route.to_location)").font(.subheadline).foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Select Route")
            .onAppear(perform: fetchRoutes)
        }
    }

    func fetchRoutes() {
        ref.observe(.value) { snapshot in
            var newRoutes: [RouteModel] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: dict),
                   let route = try? JSONDecoder().decode(RouteModel.self, from: data) {
                    newRoutes.append(route)
                }
            }
            self.routes = newRoutes
        }
    }
}

