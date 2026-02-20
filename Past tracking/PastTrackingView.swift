import SwiftUI

struct PastTrackingView: View {
    @EnvironmentObject var theme: ThemeManager
    @StateObject private var vm = PastTrackingViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Past Tracking")
                .font(.title2.bold())
                .foregroundStyle(theme.current.text)

            DatePicker("Select Date", selection: $vm.selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .foregroundStyle(theme.current.text)
                .padding(.horizontal, 16)

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Route")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.current.secondaryText)

                    Picker("Route", selection: Binding(
                        get: { vm.selectedRoute ?? vm.routes.first },
                        set: { vm.selectedRoute = $0 }
                    )) {
                        ForEach(vm.routes) { r in
                            Text("\(r.from) > \(r.to)").tag(Optional(r))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.horizontal, 16)

            PrimaryButton(title: "Load Past Path") {
                vm.loadHistory()
            }
            .padding(.horizontal, 16)

            HStack {
                Text("Points: \(vm.pings.count)")
                    .foregroundStyle(theme.current.secondaryText)
                Spacer()
                Button("Replay") {
                    vm.startReplay()
                }
                .foregroundStyle(theme.current.accent)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 16)
        .background(theme.current.background.ignoresSafeArea())
        .onAppear {
            vm.loadRoutes()
        }
    }
}
