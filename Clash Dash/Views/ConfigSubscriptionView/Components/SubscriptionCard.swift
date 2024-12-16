import SwiftUI

struct SubscriptionCard: View {
    let subscription: ConfigSubscription
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void
    let onUpdate: () -> Void
    
    @State private var isEnabled: Bool
    
    init(subscription: ConfigSubscription, onEdit: @escaping () -> Void, onToggle: @escaping (Bool) -> Void, onUpdate: @escaping () -> Void) {
        self.subscription = subscription
        self.onEdit = onEdit
        self.onToggle = onToggle
        self.onUpdate = onUpdate
        self._isEnabled = State(initialValue: subscription.enabled)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Text(subscription.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .onChange(of: isEnabled) { newValue in
                        onToggle(newValue)
                    }
            }
            
            // 订阅地址
            Text(subscription.address)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // 过滤规则
            if let keyword = subscription.keyword {
                FilterRuleView(icon: "text.magnifyingglass", text: "包含: \(keyword)", color: .blue)
            }
            
            if let exKeyword = subscription.exKeyword {
                FilterRuleView(icon: "text.magnifyingglass", text: "排除: \(exKeyword)", color: .red)
            }
            
            // 更新按钮
            Button(action: onUpdate) {
                Label("更新", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// 抽取过滤规则视图为独立组件
struct FilterRuleView: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            Label {
                Text(text)
            } icon: {
                Image(systemName: icon)
            }
            .font(.caption)
            .foregroundColor(color)
        }
    }
} 