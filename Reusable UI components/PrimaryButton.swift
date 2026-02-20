import SwiftUI

struct PrimaryButton: View {
    @EnvironmentObject var theme: ThemeManager
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.current.accent)
                .foregroundStyle(theme.current.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
