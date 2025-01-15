import SwiftUI

struct OverviewCardSettingsView: View {
    @StateObject private var settings = OverviewCardSettings()
    @AppStorage("subscriptionCardStyle") private var subscriptionCardStyle = SubscriptionCardStyle.classic
    @AppStorage("modeSwitchCardStyle") private var modeSwitchCardStyle = ModeSwitchCardStyle.classic
    @AppStorage("showWaveEffect") private var showWaveEffect = false
    @AppStorage("showWaterDropEffect") private var showWaterDropEffect = true
    
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
                Picker("订阅信息卡片样式", selection: $subscriptionCardStyle) {
                    ForEach(SubscriptionCardStyle.allCases, id: \.self) { style in
                        Text(style.description).tag(style)
                    }
                }
                
                Picker("代理切换卡片样式", selection: $modeSwitchCardStyle) {
                    ForEach(ModeSwitchCardStyle.allCases, id: \.self) { style in
                        Text(style.description).tag(style)
                    }
                }
                
                Toggle("速度卡片波浪效果", isOn: $showWaveEffect)
                
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("总流量卡片水滴效果", isOn: $showWaterDropEffect)
                    Text("一滴水滴约为 10MB 的流量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                SectionHeader(title: "卡片样式", systemImage: "greetingcard")
            }
        }
        .navigationTitle("概览页面设置")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
    }
} 