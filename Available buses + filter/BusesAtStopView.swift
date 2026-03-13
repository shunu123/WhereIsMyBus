import SwiftUI

struct BusesAtStopView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @StateObject var vm: BusesAtStopViewModel

    init(stopName: String) {
        _vm = StateObject(wrappedValue: BusesAtStopViewModel(stopName: stopName))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            
            if let err = vm.errorText {
                VStack(spacing: 12) {
                    Spacer().frame(height: 100)
                    Text(err)
                        .font(.title3.bold())
                        .foregroundStyle(theme.current.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(32)
            }

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(vm.buses) { bus in
                        BusResultCard(
                            bus: bus,
                            from: vm.stopName,
                            to: bus.route.to
                        ) {
                            router.go(.busSchedule(busID: bus.id.uuidString, searchPoint: vm.stopName))
                        }
                    }
                }
                .padding(16)
            }
            .background(theme.current.background)
        }
        .navigationBarHidden(true)
    }

    var header: some View {
        HStack {
            Button {
                router.back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }

            Text("Buses at \(vm.stopName)")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
        .background(LinearGradient(colors: theme.current.primaryGradient, startPoint: .top, endPoint: .bottom))
    }
}
