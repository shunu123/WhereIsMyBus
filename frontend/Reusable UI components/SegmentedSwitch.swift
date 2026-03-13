import SwiftUI

struct SegmentedSwitch: View {
    @EnvironmentObject var theme: ThemeManager
    @Binding var isOn: Bool
    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .tint(theme.current.accent)
    }
}
