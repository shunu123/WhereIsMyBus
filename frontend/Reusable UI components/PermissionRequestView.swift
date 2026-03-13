import SwiftUI
import CoreLocation
import Speech
import AVFoundation

struct PermissionRequestView: View {
    @EnvironmentObject var theme: ThemeManager
    var onAllow: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon Header
            permissionIcon(icon: "mic.fill", color: .red)
                .padding(.top, 10)

            VStack(spacing: 12) {
                Text("Enable Voice Search")
                    .font(.title2.bold())
                    .foregroundStyle(.black)

                Text("Allow microphone access to use fast hands-free voice search for buses and routes.")
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Benefits List
            VStack(alignment: .leading, spacing: 16) {
                benefitRow(icon: "waveform", text: "Fast hands-free voice search", color: .red)
                benefitRow(icon: "magnifyingglass", text: "Quick bus and route lookup", color: .blue)
                benefitRow(icon: "sparkles", text: "Smart voice commands", color: .orange)
            }
            .padding(.horizontal, 10)

            // Actions
            VStack(spacing: 12) {
                Button {
                    onAllow()
                } label: {
                    Text("Allow Access")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(theme.current.accent)
                        .cornerRadius(16)
                        .shadow(color: theme.current.accent.opacity(0.3), radius: 10, y: 5)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Not Now")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.black.opacity(0.6))
                }
                .padding(.bottom, 10)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(theme.current.border, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.12), radius: 25, y: 12)
    }

    private func permissionIcon(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 60, height: 60)
            
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
        }
        .background(Circle().fill(Color.white).padding(2))
    }

    private func benefitRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.85))
            
            Spacer()
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        PermissionRequestView(onAllow: {}, onDismiss: {})
            .environmentObject(ThemeManager())
    }
}
