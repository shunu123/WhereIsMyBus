import SwiftUI

struct SavedRoutesView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                Button { router.back() } label: {
                    Image(systemName: "arrow.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.current.text)
                }

                Text("Saved Routes")
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)

                Spacer()
            }

            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "bookmark.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(theme.current.secondaryText.opacity(0.4))
                Text("No saved routes yet")
                    .font(.headline)
                    .foregroundStyle(theme.current.secondaryText)
                Text("Routes you bookmark will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(theme.current.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            Spacer()
        }
        .padding(16)
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
