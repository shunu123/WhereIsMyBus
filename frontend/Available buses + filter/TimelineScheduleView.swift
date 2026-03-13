import SwiftUI

struct TimelineScheduleView: View {
    @EnvironmentObject var theme: ThemeManager
    let buses: [Bus]
    let from: String // Search points for the card
    let to: String
    let onSelectBus: (Bus) -> Void
    let onLoadMore: () -> Void
    
    @StateObject private var availableBusesVM = AvailableBusesViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                let grouped = Dictionary(grouping: buses, by: { $0.number })
                let sortedKeys = grouped.keys.sorted()

                ForEach(sortedKeys, id: \.self) { routeNo in
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: "ROUTE \(routeNo)", color: theme.current.accent)
                        
                        let sortedBuses = grouped[routeNo]?.sorted { $0.departsAt < $1.departsAt } ?? []
                        
                        ForEach(sortedBuses) { bus in
                            BusResultCard(bus: bus, from: from, to: to) {
                                onSelectBus(bus)
                            }
                            .onAppear {
                                if bus.id == sortedBuses.last?.id && routeNo == sortedKeys.last {
                                    onLoadMore()
                                }
                            }
                        }
                    }
                }

                if buses.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(theme.current.accent.opacity(0.3))
                        Text("No buses found for this route segment.")
                            .font(.headline)
                            .foregroundStyle(theme.current.secondaryText)
                    }
                    .padding(.top, 100)
                }
            }
            .padding(16)
        }
    }

    private func sectionHeader(title: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct TimelineSection: View {
    let title: String
    let buses: [Bus]
    let color: Color
    let onSelect: (Bus) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(color)
                .padding(.leading, 8)
            
            ForEach(buses) { bus in
                TimelineBusRow(bus: bus)
                    .onTapGesture { onSelect(bus) }
            }
        }
    }
}

struct TimelineBusRow: View {
    @EnvironmentObject var theme: ThemeManager
    let bus: Bus
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline Line
            VStack(spacing: 0) {
                Circle()
                    .fill(bus.isDeviated ? Color.orange : markerColor)
                    .frame(width: 12, height: 12)
                
                Rectangle()
                    .fill(theme.current.border)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)
            
            // Card Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(bus.number)
                        .font(.headline.bold())
                        .foregroundStyle(theme.current.text)
                        
                    Spacer()
                    
                    if bus.isNightOwl {
                        Text("24/7")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.indigo)
                            .cornerRadius(4)
                    }

                    if bus.isDeviated {
                        Text("DEVIATED")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                    
                    Text(bus.departsAt)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.current.text)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bus.headsign)
                            .font(.caption)
                            .foregroundStyle(theme.current.secondaryText)
                        
                        if let eta = bus.etaMinutes {
                            Text("ETA: \(eta) mins")
                                .font(.caption.bold())
                                .foregroundStyle(theme.current.accent)
                        }
                    }
                    
                    Spacer()
                    
                    let statusLabel = bus.isDeviated ? "Off Route" : (bus.statusDetail ?? bus.trackingStatus.rawValue)
                    
                    Text(statusLabel)
                        .font(.caption.bold())
                        .foregroundStyle(bus.isDeviated ? .orange : markerColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(bus.isDeviated ? Color.orange.opacity(0.1) : markerColor.opacity(0.1))
                        )
                }
            }
            .padding(12)
            .background(theme.current.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(bus.isDeviated ? Color.orange : theme.current.border, lineWidth: 1)
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private var markerColor: Color {
        switch bus.trackingStatus {
        case .scheduled: return .gray
        case .arriving: return .yellow
        case .arrived: return .green
        case .departed: return .red
        case .halted: return .orange
        case .ended: return .black
        }
    }
}
