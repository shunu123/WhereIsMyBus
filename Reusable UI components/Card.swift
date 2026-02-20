import SwiftUI

struct Card<Content: View>: View {
    @EnvironmentObject var theme: ThemeManager
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(UIConstants.cardPadding)
            .background(theme.current.card)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                    .stroke(theme.current.border)
            )
    }
}
