import SwiftUI

struct SettingsRow: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    var subtitle: String? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    List {
        SettingsRow(title: "Notificações", icon: "bell.fill", color: .red)
        SettingsRow(title: "Aparência", icon: "paintbrush.fill", color: .blue, subtitle: "Sistema")
    }
}
