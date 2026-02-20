import SwiftUI

struct SplashView: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            // Background with theme gradient
            LinearGradient(
                colors: theme.current.primaryGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Bus Logo
                Image(systemName: "bus.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                
                // App Title
                Text("Where Is My Bus")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(ThemeManager())
}
