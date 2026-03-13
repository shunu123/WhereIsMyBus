import SwiftUI

struct AboutView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // Premium background
            LinearGradient(colors: theme.current.primaryGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .opacity(0.1)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        router.back()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(theme.current.text)
                    }
                    
                    Text("About")
                        .font(.title2.bold())
                        .foregroundStyle(theme.current.text)
                        .padding(.leading, 8)
                    
                    Spacer()
                }
                .padding(16)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // App Logo & High-end Branding
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: theme.current.primaryGradient, startPoint: .top, endPoint: .bottom))
                                    .frame(width: 120, height: 120)
                                    .shadow(color: theme.current.accent.opacity(0.3), radius: 20, y: 10)
                                
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.white)
                            }
                            
                            VStack(spacing: 4) {
                                Text("Where is My Bus")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(theme.current.text)
                                
                                Text("v2.1.0 (Stable)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(theme.current.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(theme.current.accent.opacity(0.1))
                                    .cornerRadius(20)
                            }
                        }
                        .padding(.top, 20)
                        
                        // App Story / Mission
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Our Mission")
                                .font(.headline)
                                .foregroundStyle(theme.current.text)
                            
                            Text("We believe that public transport should be predictable and stress-free. Where Is My Bus is designed to empower millions of commuters across India with real-time tracking, accurate ETAs, and smart arrival alerts.")
                                .font(.subheadline)
                                .foregroundStyle(theme.current.secondaryText)
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(theme.current.card)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(theme.current.border, lineWidth: 1)
                        )
                        
                        // Links Section
                        VStack(spacing: 12) {
                            linkButton(title: "Terms of Service", icon: "doc.text")
                            linkButton(title: "Privacy Policy", icon: "shield.lefthalf.filled")
                            linkButton(title: "Open Source Licenses", icon: "chevron.left.forwardslash.chevron.right")
                        }
                        
                        // Footer
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                Text("Proudly made for India 🇮🇳")
                                    .font(.subheadline.bold())
                            }
                            .foregroundStyle(theme.current.text)
                            
                            Text("© 2024 BusTrack Inc. All rights reserved.")
                                .font(.caption2)
                                .foregroundStyle(theme.current.secondaryText)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .padding(16)
                }
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
    
    private func linkButton(title: String, icon: String) -> some View {
        Button {
            // Link action
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(theme.current.accent)
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(theme.current.secondaryText)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(theme.current.text)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(theme.current.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.current.border, lineWidth: 1)
            )
        }
    }
}
