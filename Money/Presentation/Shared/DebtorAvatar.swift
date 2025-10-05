import SwiftUI

struct DebtorAvatar: View {
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(initials)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 48, height: 48)
        .shadow(color: Color.accentColor.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}

extension Debtor {
    var initials: String {
        name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
            .joined()
    }
}

#Preview {
    VStack(spacing: 20) {
        DebtorAvatar(initials: "GP")
        DebtorAvatar(initials: "MA")
        DebtorAvatar(initials: "JS")
    }
    .padding()
}
