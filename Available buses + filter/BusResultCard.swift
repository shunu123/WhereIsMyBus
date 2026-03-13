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
            // ── Header: Route breadcrumb + status + time ──
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        // Bus number badge
                        Text(bus.number)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(theme.current.accent)
                            .clipShape(Capsule())

                        if bus.isNightOwl {
                            Label("24/7", systemImage: "moon.stars.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.indigo)
                                .clipShape(Capsule())
                        }

                        if bus.trackingStatus == .scheduled {
                            Label("Offline", systemImage: "wifi.slash")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.12))
                                .clipShape(Capsule())
                        } else {
                            statusBadge
                        }
                    }

                    // Full route A → Z
                    let firstStop = bus.route.stops.first?.name ?? bus.headsign
                    let lastStop  = bus.route.stops.last?.name ?? to
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill").foregroundStyle(.green)
                        Text(firstStop)
                        Image(systemName: "arrow.right").foregroundStyle(theme.current.secondaryText)
                        Image(systemName: "mappin.circle.fill").foregroundStyle(.red)
                        Text(lastStop)
                    }
                    .font(.caption)
                    .foregroundStyle(theme.current.secondaryText)
                    .lineLimit(1)
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

            // ── Current bus position info ──
            currentPositionRow
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            // ── Footer: duration + delay + track button ──
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TRAVEL TIME")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(theme.current.secondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        let duration = bus.etaMinutes ?? bus.durationBetween(from: from, to: to)
                        Text("\(duration)")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(theme.current.accent)
                        Text("min")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.current.accent)
                    }

                    // Delay indicator
                    if let detail = bus.statusDetail, detail.lowercased().contains("delay") {
                        Label(detail, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                Button(action: action) {
                    Label("View Timeline", systemImage: "arrow.right.circle.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(theme.current.accent)
                        .clipShape(Capsule())
                }
            }
            .padding(16)
        }
        .background(theme.current.card)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.current.border.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 2)
    }

    // MARK: - Current Bus Position Row
    @ViewBuilder
    private var currentPositionRow: some View {
        let stops = bus.route.stops
        let nextStopIdx = bus.currentStopIndex
        
        // Priority 1: Direct strings from backend search response
        if let current = bus.currentStopName, let next = bus.nextStopName {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                    Text("Currently at ")
                        .font(.caption)
                        .foregroundStyle(theme.current.secondaryText)
                    + Text(current)
                        .font(.caption.bold())
                        .foregroundStyle(theme.current.text)
                }
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.current.accent)
                    Text("Heading to: ")
                        .font(.caption)
                        .foregroundStyle(theme.current.secondaryText)
                    + Text(next)
                        .font(.caption.bold())
                        .foregroundStyle(theme.current.accent)
                }
            }
        } else if !stops.isEmpty {
            // Priority 2: Derive from stops array if available (legacy logic)
            let hasReachedFrom = nextStopIdx >= (stops.firstIndex(where: { $0.name.lowercased() == from.lowercased() }) ?? 0)
            
            VStack(alignment: .leading, spacing: 4) {
                if !hasReachedFrom {
                    let currentName = stops.indices.contains(nextStopIdx) ? stops[nextStopIdx].name : "En route"
                    HStack(spacing: 6) {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("Bus currently at ")
                            .font(.caption)
                            .foregroundStyle(theme.current.secondaryText)
                        + Text(currentName)
                            .font(.caption.bold())
                            .foregroundStyle(theme.current.text)
                    }

                    if nextStopIdx + 1 < stops.count {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.current.accent)
                            Text("Next stop: \(stops[nextStopIdx + 1].name)")
                                .font(.caption)
                                .foregroundStyle(theme.current.accent)
                        }
                    }
                } else {
                    if nextStopIdx + 1 < stops.count {
                        HStack(spacing: 6) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text("Next stop: ")
                                .font(.caption)
                                .foregroundStyle(theme.current.secondaryText)
                            + Text(stops[nextStopIdx + 1].name)
                                .font(.caption.bold())
                                .foregroundStyle(theme.current.accent)
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7)
                Text("Fetching live position…")
                    .font(.caption)
                    .foregroundStyle(theme.current.secondaryText)
            }
        }
    }

    // MARK: - Status badge
    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            if bus.isDeviated { return ("Deviated", .orange) }
            let detail = bus.statusDetail ?? ""
            if detail.lowercased().contains("delay") { return (detail, .red) }
            return (bus.status.rawValue, statusColor(bus.status))
        }()

        return Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    func statusColor(_ status: BusStatus) -> Color {
        switch status {
        case .onTime: return theme.current.accent
        case .delayed: return .red
        }
    }
}
