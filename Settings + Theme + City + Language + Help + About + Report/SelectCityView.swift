import SwiftUI

struct SelectCityView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) var dismiss
    @State private var query = ""

    private let cities = ["Chennai"]

    var body: some View {
        VStack(spacing: 12) {
            Text("Select City").font(.title2.bold())
                .foregroundStyle(theme.current.text)

            TextField("Search city…", text: $query)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(theme.current.text)
                .padding(.horizontal, 16)

            List(filtered, id: \.self) { c in
                Button {
                    locationManager.setCity(c)
                    dismiss()
                } label: {
                    HStack {
                        Text(c)
                            .foregroundStyle(theme.current.text)
                        Spacer()
                        if locationManager.currentCity == c { 
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.current.accent)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }

        .padding(.top, 16)
        .background(theme.current.background.ignoresSafeArea())
    }

    private var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return cities }
        return cities.filter { $0.lowercased().contains(q) }
    }
}
