import SwiftUI

struct SplashView: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0.0
    @State private var textOffset: CGFloat = 20
    @State private var isLogoPulsing = false

    var body: some View {
        ZStack {
            // Background with theme gradient
            LinearGradient(
                colors: theme.current.primaryGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Bus Logo
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .scaleEffect(isLogoPulsing ? 1.2 : 1.0)
                        .opacity(isLogoPulsing ? 0.0 : 0.5)
                    
                    Image(systemName: "bus.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
                }
                .scaleEffect(scale)
                .opacity(opacity)
                
                VStack(spacing: 12) {
                    // App Title
                    Text("Where Is My Bus")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(y: textOffset)
                    
                    Text("Your Daily College Transit Companion")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .offset(y: textOffset)
                }
                .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
                textOffset = 0
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isLogoPulsing = true
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(ThemeManager())
}
