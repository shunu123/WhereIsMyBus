import SwiftUI

struct PremiumMarker: View {
    let busNumber: String
    let theme: ThemeManager
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        ZStack {
            // Neon Glow
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 44, height: 44)
                .blur(radius: 8)
                .scaleEffect(isSelected ? 1.2 : 1.0)
            
            VStack(spacing: 0) {
                Text(busNumber)
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color)
                    .foregroundStyle(.white)
                    .cornerRadius(4)
                    .offset(y: -4)
                
                ZStack {
                    Circle()
                        .fill(isSelected ? color : Color.white)
                        .frame(width: 32, height: 32)
                        .shadow(color: color.opacity(0.5), radius: 6)
                    
                    Image(systemName: "bus.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? .white : color)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
    }
}

struct PremiumRouteCard: View {
    let routeName: String
    let isActive: Bool
    let color: Color
    let theme: ThemeManager

    // Deprecated params kept for compatibility — now unused
    var source: String = ""
    var destination: String = ""

    var body: some View {
        HStack(spacing: 6) {
            if isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
            }
            Text(routeName)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? .white : theme.current.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Group {
                if isActive {
                    color
                } else {
                    theme.current.card
                }
            }
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ? color : theme.current.text.opacity(0.12), lineWidth: 1.5)
        )
        .shadow(color: isActive ? color.opacity(0.4) : .clear, radius: 8, y: 3)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}


struct PremiumSearchBar: View {
    @Binding var text: String
    let theme: ThemeManager
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.current.accent)
            
            TextField("", text: $text, prompt: Text("SEARCH SELECTED ROUTE").foregroundColor(.white.opacity(0.6)))
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
        .background(
            VisualEffectBlur(blurStyle: .systemMaterialDark)
                .opacity(0.8)
        )
        .cornerRadius(27)
        .overlay(
            RoundedRectangle(cornerRadius: 27)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }
}
