import SwiftUI

struct SheetHandle: View {
    @EnvironmentObject var theme: ThemeManager
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(theme.current.border)
            .frame(width: 44, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }
}
