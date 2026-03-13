import SwiftUI

struct RouteTimelineView: View {
    @EnvironmentObject var theme: ThemeManager
    @ObservedObject var vm: LiveTrackingViewModel

    var body: some View {
        VStack(spacing: 16) {
            SheetHandle()
            Text("Route Timeline")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(vm.stops.enumerated()), id: \.element.id) { index, s in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(theme.current.accent)
                                .frame(width: s.isMajorStop ? 10 : 6, height: s.isMajorStop ? 10 : 6)
                                .frame(width: 12) // Align centers
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name)
                                    .font(s.isMajorStop ? .body.bold() : .subheadline)
                                    .foregroundStyle(theme.current.text)
                                
                                Text(vm.formattedETATime(at: index))
                                    .font(.caption2)
                                    .foregroundStyle(theme.current.secondaryText)
                            }
                            Spacer()
                        }
                        Divider().opacity(s.isMajorStop ? 0.2 : 0.1)
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .background(theme.current.background.ignoresSafeArea())
    }
}
