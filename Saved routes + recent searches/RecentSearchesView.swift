import SwiftUI

struct RecentSearchesView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter

    @State private var searches: [(from: String, to: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button { router.back() } label: {
                    Image(systemName: "arrow.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.current.text)
                }

                Text("Recent Searches")
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)

                Spacer()

                if !searches.isEmpty {
                    Button("Clear All") {
                        SearchHistoryService.shared.clearAll()
                        searches = []
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.current.accent)
                }
            }

            if searches.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(theme.current.secondaryText.opacity(0.4))
                    Text("No recent searches")
                        .font(.headline)
                        .foregroundStyle(theme.current.secondaryText)
                    Text("Your bus searches will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(theme.current.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(searches.indices, id: \.self) { idx in
                            let item = searches[idx]
                            recentRow(
                                title: "\(item.from) → \(item.to)",
                                subtitle: ""
                            ) {
                                router.go(.availableBuses(from: item.from, to: item.to, via: nil))
                            } onRemove: {
                                SearchHistoryService.shared.remove(at: idx)
                                searches = SearchHistoryService.shared.all()
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            searches = SearchHistoryService.shared.all()
        }
    }

    func recentRow(title: String, subtitle: String, onTap: @escaping () -> Void, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.current.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "clock")
                    .font(.system(size: 20))
                    .foregroundStyle(theme.current.accent)
            }
            .onTapGesture { onTap() }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.current.text)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.current.secondaryText)
                }
            }
            .onTapGesture { onTap() }

            Spacer()

            Button { onRemove() } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(theme.current.secondaryText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.current.border, lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.current.card)
                )
        )
    }
}
