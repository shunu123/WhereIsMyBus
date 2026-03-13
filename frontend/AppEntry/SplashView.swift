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
                // Lottie Animation
                LottieView(url: URL(string: "https://lottie.host/16b69e12-0efb-4061-b33d-12dc2b93fd84/Ax2k12jKRd.lottie")!)
                    .frame(width: 300, height: 300)
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
