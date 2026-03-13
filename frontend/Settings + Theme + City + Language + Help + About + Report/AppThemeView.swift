import SwiftUI

struct AppThemeView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    // Theme data with colors
    let themes: [(AppTheme, [Color])] = [
        (.collegeNormal, [Color(red: 0.0, green: 0.35, blue: 0.75), Color(red: 0.0, green: 0.55, blue: 1.0), Color(red: 0.2, green: 0.7, blue: 1.0)]),
        (.midnightLuxury, [Color(red: 0.6, green: 0.5, blue: 0.2), Color(red: 0.85, green: 0.75, blue: 0.5), Color(red: 0.95, green: 0.9, blue: 0.7)]),
        (.frostGlass, [Color.white.opacity(0.5), Color(red: 0.2, green: 0.6, blue: 0.8).opacity(0.6), Color(red: 0.1, green: 0.5, blue: 0.9).opacity(0.8)])
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
                    
                    // Customization
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Customizations")
                            .font(.headline)
                            .foregroundStyle(theme.current.text)
                            .padding(.horizontal, 16)
                            
                        VStack(spacing: 0) {
                            // Text Color
                            HStack {
                                Text("Text Color (Theme-wide)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(theme.current.text)
                                Spacer()
                                ColorPicker("", selection: Binding(
                                    get: {
                                        if !theme.customTextColorHex.isEmpty, let c = Color(hex: theme.customTextColorHex) { return c }
                                        return theme.current.text
                                    },
                                    set: { newColor in
                                        theme.customTextColorHex = newColor.toHex() ?? ""
                                    }
                                ))
                                .labelsHidden()
                            }
                            .padding(16)
                            
                            Divider().padding(.leading, 16)
                            
                            // Font Selection
                            HStack {
                                Text("App Font")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(theme.current.text)
                                Spacer()
                                Picker("Font", selection: $theme.customFontName) {
                                    Text("System (Default)").tag("")
                                    Text("Avenir").tag("Avenir")
                                    Text("Helvetica Neue").tag("HelveticaNeue")
                                    Text("Courier New").tag("CourierNewPSMT")
                                }
                                .tint(theme.current.secondaryText)
                            }
                            .padding(16)
                        }
                        .background(theme.current.background)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.current.border, lineWidth: 1)
                        )
                    }
                    
                    // Reset
                    if !theme.customTextColorHex.isEmpty || !theme.customFontName.isEmpty {
                        Button("Reset Customizations") {
                            theme.customTextColorHex = ""
                            theme.customFontName = ""
                        }
                        .foregroundStyle(theme.current.accent)
                        .padding(.top, 8)
                    }
                }
                .padding(16)
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
