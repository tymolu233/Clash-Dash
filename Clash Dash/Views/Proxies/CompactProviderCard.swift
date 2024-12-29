import SwiftUI

struct CompactProviderCard: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    @State private var isExpanded = false
    @State private var testingNodes = Set<String>()
    @State private var isUpdating = false
    @State private var showingUpdateSuccess = false
    @State private var toastMessage = ""
    
    // 添加计算属性来获取最新的节点数据
    private var currentNodes: [ProxyNode] {
        viewModel.providerNodes[provider.name] ?? nodes
    }
    
    private var usageInfo: String? {
        let currentProvider = viewModel.providers.first { $0.name == provider.name } ?? provider
        guard let info = currentProvider.subscriptionInfo else { return nil }
        let used = Double(info.upload + info.download)
        return "\(formatBytes(Int64(used))) / \(formatBytes(info.total))"
    }
    
    private var timeInfo: (update: String, expire: String)? {
        let currentProvider = viewModel.providers.first { $0.name == provider.name } ?? provider
        
        guard let updatedAt = currentProvider.updatedAt,
              let info = currentProvider.subscriptionInfo,
              info.expire > 0 else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let updateDate = formatter.date(from: updatedAt) ?? Date()
        
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .short
        
        return (
            update: relativeFormatter.localizedString(for: updateDate, relativeTo: Date()),
            expire: formatExpireDate(info.expire)
        )
    }
    
    // 添加辅助函数来处理名称
    private var displayInfo: (icon: String, name: String) {
        let name = provider.name
        guard let firstScalar = name.unicodeScalars.first,
              firstScalar.properties.isEmoji else {
            return (String(name.prefix(1)).uppercased(), name)
        }
        
        // 如果第一个字符是 emoji，将其作为图标，并从名称中移除
        let emoji = String(name.unicodeScalars.prefix(1))
        let remainingName = name.dropFirst()
        return (emoji, String(remainingName).trimmingCharacters(in: .whitespaces))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 15) {
                    // 左侧图标和名称
                    HStack(spacing: 10) {
                        // 提供者图标
                        Text(displayInfo.icon)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 36, height: 36)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayInfo.name)
                                .font(.system(.body, design: .default))
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            if let usage = usageInfo {
                                Text(usage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
//                                    .fontWeight()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
//                    Spacer()
                    
                    // 右侧状态
                    HStack(alignment: .center, spacing: 0) {
                        // 时间信息
                        if let times = timeInfo {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("更新：\(times.update)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("到期：\(times.expire)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 110)
                        }
                        
                        // 竖条分隔符
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 3, height: 30)
                            .opacity(0.3)
                            .padding(.horizontal, 5)
                        
                        // 节点数量和箭头
                        HStack(spacing: 10) {
                            if isExpanded {
                                SpeedTestButton(
                                    isTesting: viewModel.testingProviders.contains(provider.name)
                                ) {
                                    Task {
                                        await viewModel.healthCheckProvider(providerName: provider.name)
                                    }
                                }
                            } else {
                                Text("\(currentNodes.count)")
                                    .fontWeight(.medium)
                                    .font(.system(size: 16, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(.tertiaryLabel))
                                .fontWeight(.bold)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                        .frame(width: 55, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(height: 64)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            // 添加长按菜单
            .contextMenu {
                Button {
                    Task {
                        await MainActor.run {
                            isUpdating = true
                            // 显示更新中的 toast
                            withAnimation {
                                showingUpdateSuccess = false  // 确保先隐藏成功提示
                            }
                        }
                        
                        do {
                            try await withTaskCancellationHandler {
                                await viewModel.updateProxyProvider(providerName: provider.name)
                                
                                // 等待一小段时间确保数据已更新
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                                
                                // 手动获取最新数据
                                await viewModel.fetchProxies()
                                
                                await MainActor.run {
                                    let successFeedback = UINotificationFeedbackGenerator()
                                    successFeedback.notificationOccurred(.success)
                                    isUpdating = false
                                    
                                    // 显示成功提示
                                    withAnimation {
                                        showingUpdateSuccess = true
                                    }
                                    // 2 秒后隐藏提示
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            showingUpdateSuccess = false
                                        }
                                    }
                                }
                            } onCancel: {
                                Task { @MainActor in
                                    isUpdating = false
                                    let errorFeedback = UINotificationFeedbackGenerator()
                                    errorFeedback.notificationOccurred(.error)
                                }
                            }
                        } catch {
                            await MainActor.run {
                                isUpdating = false
                                let errorFeedback = UINotificationFeedbackGenerator()
                                errorFeedback.notificationOccurred(.error)
                                print("更新提供者失败: \(error)")
                            }
                        }
                    }
                } label: {
                    if isUpdating {
                        Label("更新中...", systemImage: "arrow.clockwise")
                    } else {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isUpdating)
            }
            
            // 展开的节点列表
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        // 使用 currentNodes 替代 nodes
                        ForEach(currentNodes) { node in
                            ProxyNodeRow(
                                nodeName: node.name,
                                isSelected: false,
                                delay: node.delay,
                                isTesting: testingNodes.contains(node.name)
                            )
                            .onTapGesture {
                                Task {
                                    print("📡 开始测试节点: \(node.name) (Provider: \(provider.name))")
                                    testingNodes.insert(node.name)
                                    
                                    do {
                                        try await withTaskCancellationHandler {
                                            await viewModel.healthCheckProviderProxy(
                                                providerName: provider.name,
                                                proxyName: node.name
                                            )
                                            // 不需要再调用 fetchProxies，因为 healthCheckProviderProxy 已经包含了这个操作
                                            print("✅ 节点测试完成: \(node.name), 延迟: \(node.delay)ms")
                                            
                                            let successFeedback = UINotificationFeedbackGenerator()
                                            successFeedback.notificationOccurred(.success)
                                        } onCancel: {
                                            print("❌ 节点测试取消: \(node.name)")
                                            testingNodes.remove(node.name)
                                            
                                            let errorFeedback = UINotificationFeedbackGenerator()
                                            errorFeedback.notificationOccurred(.error)
                                        }
                                    } catch {
                                        print("❌ 节点测试错误: \(node.name), 错误: \(error)")
                                        let errorFeedback = UINotificationFeedbackGenerator()
                                        errorFeedback.notificationOccurred(.error)
                                    }
                                    
                                    testingNodes.remove(node.name)
                                    print("🏁 节点测试流程结束: \(node.name)")
                                }
                            }
                            
                            if node.id != currentNodes.last?.id {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if showingUpdateSuccess || isUpdating {
                HStack {
                    if isUpdating {
                        ProgressView()
                            .tint(.blue)
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                    
                    Text(isUpdating ? "正在更新..." : "更新成功")
                        .foregroundColor(.primary)
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(25)
                .shadow(radius: 10, x: 0, y: 5)
                .padding(.bottom, 50)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // 格式化字节数
    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.0fGB", gb)
        } else if mb >= 1 {
            return String(format: "%.0fMB", mb)
        } else if kb >= 1 {
            return String(format: "%.0fKB", kb)
        } else {
            return "\(bytes)B"
        }
    }
    
    // 格式化过期时间
    private func formatExpireDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

#Preview {
    CompactProviderCard(
        provider: Provider(
            name: "测试提供者",
            type: "http",
            vehicleType: "http",
            updatedAt: "2023-01-01T12:00:00.000Z",
            subscriptionInfo: SubscriptionInfo(
                upload: 1024 * 1024 * 100,    // 100MB
                download: 1024 * 1024 * 500,  // 500MB
                total: 1024 * 1024 * 1024,    // 1GB
                expire: 1735689600            // 2025-01-01
            )
        ),
        nodes: [],
        viewModel: ProxyViewModel(
            server: ClashServer(
                name: "测试服务器",
                url: "localhost",
                port: "9090",
                secret: "123456"
            )
        )
    )
    .padding()
} 
