import SwiftUI

struct RateUsView: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var rating: Int = 0
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header Image/Icon
            ZStack {
                Circle()
                    .fill(theme.current.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "star.bubble.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.current.accent)
            }
            .padding(.top, 10)

            VStack(spacing: 12) {
                Text("How are we doing?")
                    .font(.title2.bold())
                    .foregroundStyle(.black)

                Text("Your feedback helps us make Where Is My Bus better for everyone.")
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Star Rating
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(index <= rating ? .orange : Color.black.opacity(0.2))
                        .onTapGesture {
                            withAnimation(.spring()) {
                                rating = index
                            }
                        }
                }
            }
            .padding(.vertical, 10)

            // Actions
            VStack(spacing: 12) {
                Button {
                    if rating > 0 {
                        // In a real app, send to App Store or backend
                        onDismiss()
                    }
                } label: {
                    Text("Submit Rating")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(rating > 0 ? theme.current.accent : Color.gray.opacity(0.3))
                        .cornerRadius(16)
                        .shadow(color: theme.current.accent.opacity(rating > 0 ? 0.3 : 0), radius: 10, y: 5)
                }
                .disabled(rating == 0)

                Button {
                    onDismiss()
                } label: {
                    Text("Maybe Later")
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
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        RateUsView(onDismiss: {})
            .environmentObject(ThemeManager())
    }
}
