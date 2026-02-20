import SwiftUI

struct SetAlarmSheetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var theme: ThemeManager
    @ObservedObject var vm: LiveTrackingViewModel

    @State private var stopsBefore: Int = 2
    @State private var selectedStop: String = ""
    @State private var isSuccess = false

    var body: some View {
        VStack(spacing: 16) {
            SheetHandle()

            if isSuccess {
                VStack(spacing: 20) {
                    Spacer().frame(height: 40)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(theme.current.accent)
                        .scaleEffect(isSuccess ? 1.0 : 0.5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isSuccess)
                    
                    Text("Alarm Successfully Set!")
                        .font(.title3.bold())
                        .foregroundStyle(theme.current.text)
                    
                    Text("We'll alert you \(stopsBefore) stops before \(selectedStop).")
                        .font(.subheadline)
                        .foregroundStyle(theme.current.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .transition(.opacity)
            } else {
                Text("Set Arrival Alarm")
                    .font(.headline)

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Wake me up at")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.current.secondaryText)

                        Picker("Stop", selection: $selectedStop) {
                            ForEach(vm.stops.map(\.name), id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .pickerStyle(.menu)

                        Text("When to alert?")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.current.secondaryText)

                        Picker("Stops before", selection: $stopsBefore) {
                            Text("1 stop before").tag(1)
                            Text("2 stops before").tag(2)
                            Text("3 stops before").tag(3)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.current.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button("Set Alarm") {
                        vm.alarmStopName = selectedStop
                        vm.alarmStopsBefore = stopsBefore
                        vm.alarmEnabled = true
                        
                        withAnimation {
                            isSuccess = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.current.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .onAppear {
            selectedStop = vm.stops.last?.name ?? ""
        }
        .background(theme.current.background.ignoresSafeArea())
    }
}
