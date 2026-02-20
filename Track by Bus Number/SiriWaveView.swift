import SwiftUI
import Combine

struct SiriWaveView: View {
    // Apple-like colors for voice UI
    let colors: [Color] = [
        Color(red: 0.2, green: 0.8, blue: 0.9), // Cyan
        Color(red: 0.9, green: 0.3, blue: 0.4), // Pink/Red
        Color(red: 0.3, green: 0.3, blue: 0.9), // Blue
        Color(red: 0.2, green: 0.8, blue: 0.5), // Green
        Color(red: 0.6, green: 0.2, blue: 0.8)  // Purple
    ]
    
    @State private var heights: [CGFloat] = Array(repeating: 10, count: 5)
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 10)
                    .fill(colors[index])
                    .frame(width: 8, height: heights[index])
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: heights[index])
            }
        }
        .frame(height: 60)
        .onReceive(timer) { _ in
            for i in 0..<5 {
                // Random height between 10 and 50 to simulate voice activity
                heights[i] = CGFloat.random(in: 10...50)
            }
        }
        // Stop timer when view disappears
        .onDisappear {
            timer.upstream.connect().cancel()
        }
    }
}
