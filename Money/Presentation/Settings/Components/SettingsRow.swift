import SwiftUI

struct SettingsRow<Accessory: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    var subtitle: String? = nil
    @ViewBuilder var accessory: () -> Accessory

    init(
        title: LocalizedStringKey,
        icon: String,
        color: Color,
        subtitle: String? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
        self.accessory = accessory
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color.gradient)
                .clipShape(.rect(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer(minLength: 0)
            accessory()
        }
    }
}

#Preview {
    List {
        SettingsRow(title: "Notificações", icon: "bell.fill", color: .red)
        SettingsRow(title: "Aparência", icon: "paintbrush.fill", color: .blue, subtitle: "Sistema")
        SettingsRow(title: "Tema", icon: "paintbrush.fill", color: .blue) {
            Text("Claro")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
