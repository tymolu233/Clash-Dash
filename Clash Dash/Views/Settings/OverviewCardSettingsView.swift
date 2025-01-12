import SwiftUI

struct OverviewCardSettingsView: View {
    @StateObject private var settings = OverviewCardSettings()
    @AppStorage("subscriptionCardStyle") private var subscriptionCardStyle = SubscriptionCardStyle.classic
    
    var body: some View {
        List {
            Section {
                ForEach(settings.cardOrder) { card in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                        
                        Image(systemName: card.icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        Text(card.description)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settings.cardVisibility[card] ?? true },
                            set: { _ in settings.toggleVisibility(for: card) }
                        ))
                    }
                }
                .onMove { source, destination in
                    settings.moveCard(from: source, to: destination)
                }
            } header: {
                SectionHeader(title: "卡片设置", systemImage: "rectangle.on.rectangle")
            } footer: {
                Text("拖动 ≡ 图标可以调整顺序，使用开关可以控制卡片的显示或隐藏")
            }
            
            Section {
                Picker("订阅卡片样式", selection: $subscriptionCardStyle) {
                    ForEach(SubscriptionCardStyle.allCases, id: \.self) { style in
                        Text(style.description).tag(style)
                    }
                }
            } header: {
                SectionHeader(title: "订阅卡片", systemImage: "creditcard.fill")
            }
        }
        .navigationTitle("概览页面设置")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
    }
} 