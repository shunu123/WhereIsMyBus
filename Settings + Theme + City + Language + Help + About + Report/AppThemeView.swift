import SwiftUI

struct AppThemeView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    // Theme data with colors
    let themes: [(AppTheme, [Color])] = [
        (.sunset, [Color(red: 1.0, green: 0.3, blue: 0.0), Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.8, blue: 0.0)]),
        (.ocean, [Color(red: 0.0, green: 0.75, blue: 1.0), Color(red: 0.53, green: 0.81, blue: 0.98), Color(red: 1.0, green: 0.84, blue: 0.0)]),
        (.fadedGradient, [Color(red: 0.9, green: 0.85, blue: 1.0), Color(red: 0.8, green: 0.9, blue: 1.0), Color(red: 0.75, green: 0.95, blue: 0.9)]),
        (.goldenHour, [Color(red: 1.0, green: 0.8, blue: 0.4), Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.9, blue: 0.6)]),
        (.lavender, [Color(red: 0.7, green: 0.5, blue: 0.9), Color(red: 0.9, green: 0.6, blue: 0.8), Color(red: 1.0, green: 0.8, blue: 0.8)]),
        (.forest, [Color(red: 0.0, green: 0.4, blue: 0.3), Color(red: 0.1, green: 0.6, blue: 0.4), Color(red: 0.4, green: 0.8, blue: 0.5)]),
        (.aurora, [Color(red: 0.4, green: 0.0, blue: 0.8), Color(red: 0.0, green: 0.8, blue: 1.0), Color(red: 0.0, green: 1.0, blue: 0.5)])
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.current.text)
                }
                
                Text("App Theme")
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)
                    .padding(.leading, 8)
                
                Spacer()
            }
            .padding(16)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Theme Options
                    VStack(spacing: 0) {
                        ForEach(themes, id: \.0) { themeOption in
                            Button {
                                theme.setTheme(themeOption.0)
                            } label: {
                                HStack(spacing: 16) {
                                    // Color Circle
                                    Circle()
                                        .fill(LinearGradient(colors: themeOption.1, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 40, height: 40)
                                    
                                    Text(themeOption.0.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(theme.current.text)
                                    
                                    Spacer()
                                    
                                    if theme.currentTheme == themeOption.0 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(Color.green)
                                    }
                                }
                                .padding(16)
                            .background(theme.current.background)
                            }
                            .buttonStyle(.plain)
                            
                            if themeOption.0 != themes.last?.0 {
                                Divider()
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .background(theme.current.background)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.current.border, lineWidth: 1)
                    )
                    
                    // Preview Card
                    VStack(spacing: 16) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 40))
                            .foregroundStyle(theme.current.accent)
                        
                        Text("Preview")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(theme.current.text)
                        
                        Text("This is how your app looks with the \(theme.currentTheme.title).")
                            .font(.subheadline)
                            .foregroundStyle(theme.current.secondaryText)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            // Preview action
                        } label: {
                            Text("Primary Button")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 200)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearGradient(colors: theme.current.primaryGradient, startPoint: .leading, endPoint: .trailing))
                                )
                        }
                    }
                    .padding(24)
                    .background(theme.current.background)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.current.border, lineWidth: 1)
                    )
                }
                .padding(16)
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
