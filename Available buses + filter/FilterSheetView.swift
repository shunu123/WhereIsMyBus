import SwiftUI

struct FilterSheetView: View {
    @EnvironmentObject var theme: ThemeManager

    @Binding var showOnTime: Bool
    @Binding var showDelayed: Bool
    @Binding var sortOption: AvailableBusesViewModel.SortOption

    let apply: () -> Void
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
             // Custom Header with "Close" button
            HStack {
                Text("Filter & Sort")
                    .font(.title3.weight(.bold))
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(theme.current.secondaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Status Section
            VStack(alignment: .leading, spacing: 12) {
                Text("STATUS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.current.accent) // Green Header
                
                HStack(spacing: 12) {
                    FilterChip(title: "All", isSelected: !showOnTime && !showDelayed) {
                        showOnTime = false
                        showDelayed = false
                    }
                    
                    FilterChip(title: "On Time", isSelected: showOnTime) {
                        showOnTime.toggle()
                        if showOnTime { showDelayed = false }
                    }
                    
                    FilterChip(title: "Delayed", isSelected: showDelayed) {
                        showDelayed.toggle()
                        if showDelayed { showOnTime = false }
                    }
                }
            }
            .padding(.horizontal, 20)

            // Sort By Section
            VStack(alignment: .leading, spacing: 12) {
                Text("SORT BY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.current.accent)
                
                VStack(spacing: 0) {
                    SortOptionRow(title: "Departure Time", isSelected: sortOption == .departureTime) {
                        sortOption = .departureTime
                    }
                    
                    Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 1)
                    
                    SortOptionRow(title: "Duration", isSelected: sortOption == .duration) {
                        sortOption = .duration
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.current.border, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            PrimaryButton(title: "Apply Filters", action: apply)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
        .background(theme.current.background.ignoresSafeArea())
    }
}

struct FilterChip: View {
    @EnvironmentObject var theme: ThemeManager
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? (theme.current.background == Color.white ? .white : theme.current.text) : theme.current.text)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.current.accent : theme.current.card)
                        .overlay(
                            Capsule().stroke(theme.current.border, lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
    }
}

struct SortOptionRow: View {
    @EnvironmentObject var theme: ThemeManager
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(theme.current.text)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.current.accent)
                }
            }
            .padding(16)
            .background(theme.current.card)
        }
        .buttonStyle(.plain)
    }
}

