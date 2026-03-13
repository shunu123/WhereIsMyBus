import SwiftUI

struct TrackByBusNumberView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @StateObject private var voice = VoiceAssistant()
    
    var autoStartVoice: Bool = false

    @State private var busNo: String = ""
    @State private var errorText: String?

    // Recent buses data
    var recentBuses: [String] {
        BusRepository.shared.allBuses.prefix(5).map { $0.number }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Header
            HStack {
                Button {
                    router.back()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.current.text)
                }
                
                Text("Track by Bus Number")
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)
                
                Spacer()
            }
            .padding(.horizontal, 16)

            // Input Card
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "bus.fill")
                        .foregroundStyle(theme.current.accent)
                    
                    TextField("Enter Bus No (e.g. 21G, 335-E)", text: $busNo)
                        .font(.subheadline)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.current.border, lineWidth: 1)
                )

                if let err = errorText {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // Track Button
                Button {
                    Task {
                        errorText = nil
                        if let bus = BusSearchService.shared.findByNumber(busNo) {
                            router.go(.busSchedule(busID: bus.id.uuidString))
                        } else {
                            errorText = "Bus not found."
                        }
                    }
                } label: {
                    Text("Track Bus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: theme.current.primaryGradient, startPoint: .leading, endPoint: .trailing))
                        )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(theme.current.border, lineWidth: 1)
                    .background(theme.current.card)
            )
            .padding(.horizontal, 16)

            // Voice Wave (if active)
            if voice.isListening {
                SiriWaveView()
                    .padding(.horizontal, 16)
            }

            // Recent Buses Section
            VStack(alignment: .leading, spacing: 12) {
                Text("RECENT BUSES")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.current.accent)
                    .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recentBuses, id: \.self) { bus in
                            Text(bus)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.current.text)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(theme.current.border, lineWidth: 1)
                                        .background(theme.current.card)
                                )
                                .onTapGesture {
                                    busNo = bus
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            Spacer()
        }
        .padding(.top, 16)
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onChange(of: voice.transcript) { oldValue, newValue in
            if !newValue.isEmpty {
                busNo = newValue.uppercased()
            }
        }
        .onAppear {
            if autoStartVoice {
                Task { await voice.start() }
            }
        }
        .onDisappear { voice.stop() }
    }
}


