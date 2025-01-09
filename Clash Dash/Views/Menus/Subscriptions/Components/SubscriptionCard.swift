import SwiftUI

struct SubscriptionCard: View {
    let subscription: ConfigSubscription
    let server: ClashServer
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void
    let viewModel: ConfigSubscriptionViewModel
    
    @State private var isEnabled: Bool
    @State private var isRefreshing = false
    @State private var currentSubscription: ConfigSubscription
    @Environment(\.colorScheme) private var colorScheme
    
    init(subscription: ConfigSubscription, 
         server: ClashServer, 
         viewModel: ConfigSubscriptionViewModel,
         onEdit: @escaping () -> Void, 
         onToggle: @escaping (Bool) -> Void) {
        self.subscription = subscription
        self.server = server
        self.viewModel = viewModel
        self.onEdit = onEdit
        self.onToggle = onToggle
        self._isEnabled = State(initialValue: subscription.enabled)
        self._currentSubscription = State(initialValue: subscription)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(currentSubscription.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        if server.luciPackage == .mihomoTProxy,
                           let remoteFirst = currentSubscription.remoteFirst {
                            HStack(spacing: 4) {
                                Image(systemName: remoteFirst ? "cloud.fill" : "house.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(remoteFirst ? "远程优先" : "本地优先")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                        
                    Text(currentSubscription.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
 
                }
                
                Spacer()
                
                // 编辑和开关按钮
                HStack(spacing: 12) {
                    if server.luciPackage == .mihomoTProxy,
                       let subscriptionId = currentSubscription.subscriptionId {
                        Button {
                            Task {
                                isRefreshing = true
                                do {
                                    if let updatedSubscription = try await viewModel.updateMihomoTProxySubscription(subscriptionId) {
                                        currentSubscription = updatedSubscription
                                    }
                                } catch {
                                    print("更新失败: \(error)")
                                }
                                isRefreshing = false
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                                .font(.title3)
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        }
                        .disabled(isRefreshing)
                    }
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                    
                    if server.luciPackage == .openClash {
                        Toggle("", isOn: $isEnabled)
                            .labelsHidden()
                            .onChange(of: isEnabled) { newValue in
                                onToggle(newValue)
                            }
                    }
                }
            }
            
            // 分隔线
            Divider()
            
            if server.luciPackage == .mihomoTProxy {
                // 订阅详细信息
                VStack(alignment: .leading, spacing: 8) {
                    // 流量信息
                    HStack(spacing: 16) {
                        if let used = currentSubscription.used {
                            SubscripationDataLabel(title: "已用", value: used)
                        }
                        if let available = currentSubscription.available {
                            SubscripationDataLabel(title: "剩余", value: available)
                        }
                        if let total = currentSubscription.total {
                            SubscripationDataLabel(title: "总量", value: total)
                        }
                    }
                    
                    // 到期和更新信息
                    HStack(spacing: 16) {
                        if let expire = currentSubscription.expire {
                            SubscripationDataLabel(title: "到期", value: expire)
                        }
                        if let lastUpdate = currentSubscription.lastUpdate {
                            SubscripationDataLabel(title: "更新", value: lastUpdate)
                        }
                    }
                    
                    // 上传下载信息
                    HStack(spacing: 16) {
                        if let upload = currentSubscription.upload {
                            SubscripationDataLabel(title: "上传", value: upload)
                        }
                        if let download = currentSubscription.download {
                            SubscripationDataLabel(title: "下载", value: download)
                        }
                    }
                }
                .padding(.top, 4)
            } else {
                // 过滤信息
                VStack(alignment: .leading, spacing: 8) {
                    if let keyword = currentSubscription.keyword {
                        FilterBadge(icon: "text.magnifyingglass", text: "包含: \(keyword)", color: .blue)
                    }
                    
                    if let exKeyword = currentSubscription.exKeyword {
                        FilterBadge(icon: "text.magnifyingglass", text: "排除: \(exKeyword)", color: .red)
                    }
                }
                
                // 订阅转换状态
                if currentSubscription.subConvert {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.green)
                        Text("已启用订阅转换")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                }
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

struct SubscripationDataLabel: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
} 