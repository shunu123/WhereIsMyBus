//
//  BusResultCard.swift
//  WhereIsMyBus
//

import SwiftUI
import MapKit

struct BusResultCard: View {
    let bus: Bus
    let from: String
    let to: String
    let action: () -> Void
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            // Header: Bus No + Status + Time
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(bus.number)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(theme.current.text)
                        
                        // Status Chip
                        statusBadge
                    }
                    
                    Text(bus.headsign) 
                        .font(.subheadline)
                        .foregroundStyle(theme.current.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(bus.timeAtStop(name: from) ?? bus.departsAt) 
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.current.accent) 
                    
                    Text("At \(from)")
                        .font(.caption)
                        .foregroundStyle(theme.current.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Info Section (Duration & Context) - Requirement 2
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bus.headsign)
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.current.text)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(contextMessage)
                            .font(.caption)
                    }
                    .foregroundStyle(theme.current.secondaryText)
                }
                
                Spacer()
                
                // Prominent Duration - Relative to search
                VStack(alignment: .trailing, spacing: 0) {
                    Text("DURATION")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(theme.current.secondaryText)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(bus.durationBetween(from: from, to: to))")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(theme.current.accent)
                        Text("min")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.current.accent)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Footer
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 10))
                    Text("Daily Service • College Bus")
                        .font(.system(size: 11))
                }
                .foregroundStyle(theme.current.secondaryText)
                
                Spacer()
                
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text("View Track")
                        Image(systemName: "arrow.right")
                    }
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(theme.current.accent)
                }
            }
            .padding(14)
            .background(theme.current.accent.opacity(0.03))
        }
        .background(theme.current.card)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.current.border.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 2) // Prevent shadow clipping
    }

    private var statusBadge: some View {
        let text: String
        let color: Color
        
        if bus.isDeviated {
            text = "Deviated"
            color = .orange
        } else {
            text = bus.status.rawValue
            color = statusColor(bus.status)
        }
        
        return Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var contextMessage: String {
        if bus.isDeviated {
            return "Deviated from route"
        }
        let time = bus.timeAtStop(name: from) ?? bus.departsAt
        return "Reaches \(from) at \(time)"
    }
    
    func statusColor(_ status: BusStatus) -> Color {
        switch status {
        case .onTime: return theme.current.accent
        case .delayed: return .red
        }
    }
}
