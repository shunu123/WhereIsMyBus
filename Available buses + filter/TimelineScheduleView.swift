import SwiftUI

struct TimelineScheduleView: View {
    @EnvironmentObject var theme: ThemeManager
    let buses: [Bus]
    let from: String // Search points for the card
    let to: String
    let onSelectBus: (Bus) -> Void
    
    @StateObject private var dummyVM = AvailableBusesViewModel() // We might want to pass the VM or use sections from parent

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // We use the buses array from parent, but logically we should separate them
                // For now, let's categorize them here or expect parent to pass categorizeable data
                
                let upcoming = buses.filter { $0.statusRelativeTo(stopName: from) == .arriving || $0.statusRelativeTo(stopName: from) == .arrived }
                let scheduled = buses.filter { $0.trackingStatus == .scheduled }
                let departed = buses.filter { $0.statusRelativeTo(stopName: from) == .departed }

                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: "UPCOMING BUSES", color: .blue)
                        ForEach(upcoming) { bus in
                            BusResultCard(bus: bus, from: from, to: to) {
                                onSelectBus(bus)
                            }
                        }
                    }
                }

                if !scheduled.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: "SCHEDULED", color: .gray)
                        ForEach(scheduled) { bus in
                            BusResultCard(bus: bus, from: from, to: to) {
                                onSelectBus(bus)
                            }
                        }
                    }
                }

                if !departed.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: "DEPARTED (MISSED)", color: .red)
                        ForEach(departed) { bus in
                            BusResultCard(bus: bus, from: from, to: to) {
                                onSelectBus(bus)
                            }
                        }
                        .opacity(0.7)
                    }
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
