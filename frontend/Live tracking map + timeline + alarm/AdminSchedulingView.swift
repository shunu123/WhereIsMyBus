import SwiftUI

struct AdminSchedulingView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var busID = ""
    @State private var busNumber = ""
    @State private var gpsNumber = ""
    @State private var routeFrom = ""
    @State private var routeTo = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Bus Details") {
                    TextField("Bus ID", text: $busID)
                        .keyboardType(.numberPad)
                    TextField("Bus Number (e.g. DL1PC1234)", text: $busNumber)
                    TextField("GPS Hardware ID", text: $gpsNumber)
                }
                
                Section("Route Info") {
                    TextField("Route From", text: $routeFrom)
                    TextField("Route To", text: $routeTo)
                }
                
                Button(action: saveSchedule) {
                    Text("Save Schedule")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.current.accent)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
            }
            .navigationTitle("Add Bus Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func saveSchedule() {
        // Simple validation
        guard !busID.isEmpty, !busNumber.isEmpty, !routeFrom.isEmpty, !routeTo.isEmpty else { return }
        
        Task {
            do {
                // Create a basic trip with 2 stops (From -> To)
                // Realistically, we'd have a stop picker here.
                let stopsList = try? await APIService.shared.fetchStops(routeId: "20", dir: "Eastbound")
                let fromStopStr = stopsList?.first(where: { $0.name.lowercased().contains(routeFrom.lowercased()) })?.id ?? "1"
                let toStopStr = stopsList?.first(where: { $0.name.lowercased().contains(routeTo.lowercased()) })?.id ?? "2"
                let fromStop = Int(fromStopStr) ?? 1
                let toStop = Int(toStopStr) ?? 2

                let newTrip = CreateTripIn(
                    bus_id: Int(busID) ?? 1,
                    route_id: 1, // Default route ID
                    service_date: ISO8601DateFormatter().string(from: Date()).components(separatedBy: "T")[0],
                    start_time: "08:00:00",
                    end_time: "09:00:00",
                    stops: [
                        CreateTripStopIn(stop_id: fromStop, stop_order: 1, arrival: "08:00:00", departure: "08:05:00"),
                        CreateTripStopIn(stop_id: toStop, stop_order: 2, arrival: "09:00:00", departure: "09:00:00")
                    ]
                )
                
                try await APIService.shared.createTrip(newTrip)
                
                // Refresh local buses
                BusRepository.shared.startDailyLoad()
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to save schedule: \(error)")
            }
        }
    }
}
