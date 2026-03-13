import SwiftUI

struct BusStopTimelineView: View {
    let stops: [String]
    let currentStopIndex: Int

    var body: some View {
        VStack(alignment: .leading) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 6)
                .padding(.top, 10)
                .frame(maxWidth: .infinity)

            Text("Route Progress")
                .font(.headline)
                .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<stops.count, id: \.self) { index in
                        HStack(alignment: .top, spacing: 15) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(index <= currentStopIndex ? .accentColor : Color.gray)
                                    .frame(width: 10, height: 10)
                                if index != stops.count - 1 {
                                    Rectangle()
                                        .fill(index < currentStopIndex ? .accentColor : Color.gray)
                                        .frame(width: 2, height: 30)
                                }
                            }
                            
                            Text(stops[index])
                                .font(.system(size: 14))
                                .foregroundStyle(index <= currentStopIndex ? .primary : .secondary)
                            
                            Spacer()
                            
                            if index > currentStopIndex {
                                Text("Upcoming")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}
