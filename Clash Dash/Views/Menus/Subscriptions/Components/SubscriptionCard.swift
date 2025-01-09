import SwiftUI

struct SubscriptionCard: View {
    let subscription: ConfigSubscription
    let server: ClashServer
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void
    
    @State private var isEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    init(subscription: ConfigSubscription, server: ClashServer, onEdit: @escaping () -> Void, onToggle: @escaping (Bool) -> Void) {
        self.subscription = subscription
        self.server = server
        self.onEdit = onEdit
        self.onToggle = onToggle
        self._isEnabled = State(initialValue: subscription.enabled)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(subscription.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 编辑和开关按钮
                HStack(spacing: 12) {
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
            }
            
            // 分隔线
            Divider()
            
            // 过滤信息
            VStack(alignment: .leading, spacing: 8) {
                if let keyword = subscription.keyword {
                    FilterBadge(icon: "text.magnifyingglass", text: "包含: \(keyword)", color: .blue)
                }
                
                if let exKeyword = subscription.exKeyword {
                    FilterBadge(icon: "text.magnifyingglass", text: "排除: \(exKeyword)", color: .red)
                }
            }
            
            // 订阅转换状态
            if subscription.subConvert {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.green)
                    Text("已启用订阅转换")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
            
            // 远程优先状态
            if server.luciPackage == .mihomoTProxy,
               let remoteFirst = subscription.remoteFirst {
                HStack {
                    Image(systemName: remoteFirst ? "cloud.fill" : "house.fill")
                        .foregroundColor(.blue)
                    Text(remoteFirst ? "远程优先" : "本地优先")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(
                    color: isEnabled ? 
                        Color.accentColor.opacity(0.3) : 
                        Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                    radius: isEnabled ? 8 : 4,
                    y: 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isEnabled ? 
                        Color.accentColor.opacity(0.5) : 
                        Color(.systemGray4),
                    lineWidth: isEnabled ? 2 : 0.5
                )
        )
    }
}

struct FilterBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .foregroundColor(color)
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
    }
} 