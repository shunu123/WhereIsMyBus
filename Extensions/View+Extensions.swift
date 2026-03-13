import SwiftUI
import UIKit

// MARK: - Selective Corner Radius

extension View {
    /// Applies a corner radius to specific corners only.
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Custom Font Applier

extension View {
    @ViewBuilder
    func applyCustomAppTheme(_ theme: ThemeManager) -> some View {
        if !theme.customFontName.isEmpty {
            self.environment(\.font, Font.custom(theme.customFontName, size: 16, relativeTo: .body))
        } else {
            self
        }
    }
}
