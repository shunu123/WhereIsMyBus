import SwiftUI

struct SelectLanguageView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss
    
    // Language data with native names
    private let languages = [
        ("English", "English"),
        ("Hindi", "हिन्दी"),
        ("Tamil", "தமிழ்"),
        ("Telugu", "తెలుగు"),
        ("Kannada", "ಕನ್ನಡ"),
        ("Malayalam", "മലയാളം"),
        ("Marathi", "मराठी"),
        ("Bengali", "বাংলা"),
        ("Gujarati", "ગુજરાતી")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.current.text)
                }
                
                Text("Select Language")
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)
                    .padding(.leading, 8)
                
                Spacer()
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(languages, id: \.0) { lang in
                        Button {
                            languageManager.setLanguage(lang.0)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lang.0)
                                        .font(.headline)
                                        .foregroundStyle(theme.current.text)
                                    
                                    Text(lang.1)
                                        .font(.subheadline)
                                        .foregroundStyle(theme.current.secondaryText)
                                }
                                
                                Spacer()
                                
                                if languageManager.currentLanguage == lang.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(theme.current.accent)
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                            .background(languageManager.currentLanguage == lang.0 ? theme.current.accent.opacity(0.1) : theme.current.card)
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.current.border, lineWidth: 1)
                        .background(theme.current.card)
                )
                .padding(16)
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
