import SwiftUI

struct BusTimelineView: View {
    @EnvironmentObject var router: AppRouter
    let route: RouteModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(route.stops, id: \.self) { stop in
                    HStack(spacing: 20) {
                        VStack {
                            Circle().fill(.blue).frame(width: 10, height: 10)
                            Rectangle().fill(.gray).frame(width: 2, height: 40)
                        }
                        Text(stop).font(.body)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle(route.route_id)
        .navigationBarTitleDisplayMode(.inline)
    }
}
