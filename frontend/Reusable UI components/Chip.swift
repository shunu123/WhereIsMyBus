import SwiftUI

struct Chip: View {
    @EnvironmentObject var theme: ThemeManager
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.current.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.current.border))
    }
}
