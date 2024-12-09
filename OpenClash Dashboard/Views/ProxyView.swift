import SwiftUI

struct ProxyView: View {
    let server: ClashServer
    @StateObject private var viewModel: ProxyViewModel
    
    init(server: ClashServer) {
        self.server = server
        self._viewModel = StateObject(wrappedValue: ProxyViewModel(server: server))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.groups.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else {
                    // 代理组列表
                    proxyGroupsSection
                    
                    // 代理提供者列表
                    proxyProvidersSection
                }
            }
            .padding()
        }
        .navigationTitle(server.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchProxies()
        }
    }
    
    // MARK: - 代理组部分
    private var proxyGroupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("代理组")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(viewModel.getSortedGroups()) { group in
                GroupCard(group: group, viewModel: viewModel)
            }
        }
    }
    
    // MARK: - 代理提供者部分
    private var proxyProvidersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("代理提供者")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(viewModel.providers) { provider in
                ProviderCard(provider: provider, viewModel: viewModel)
            }
        }
    }
}

// MARK: - 代理组卡片
struct GroupCard: View {
    let group: ProxyGroup
    @ObservedObject var viewModel: ProxyViewModel
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 头部信息（点击展开/收起）
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(group.name)
                        .font(.system(.body, design: .rounded))
                        .bold()
                    
                    Spacer()
                    
                    // 显示当前选中的节点
                    VStack(alignment: .trailing) {
                        Text(group.now)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // 展开的代理列表
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(group.all, id: \.self) { proxyName in
                        ProxyItemRow(
                            proxyName: proxyName,
                            isSelected: group.now == proxyName,
                            node: viewModel.nodes.first(where: { $0.name == proxyName }),
                            isTesting: viewModel.testingNodes.contains(proxyName)
                        ) {
                            Task {
                                await viewModel.selectProxy(groupName: group.name, proxyName: proxyName)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 代理节点行
struct ProxyItemRow: View {
    let proxyName: String
    let isSelected: Bool
    let node: ProxyNode?
    let isTesting: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // 代理名称
                Text(proxyName)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                
                Spacer()
                
                // 代理类型和延迟信息
                if let node = node {
                    HStack(spacing: 12) {
                        // 代理类型标签
                        Text(node.type)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        
                        // 延迟信息
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Text(formatDelay(node.delay))
                                .font(.caption)
                                .foregroundColor(delayColor(node.delay))
                        }
                    }
                }
                
                // 选中指示器
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
    
    // 格式化延迟显示
    private func formatDelay(_ delay: Int) -> String {
        if delay == 0 {
            return "超时"
        }
        return "\(delay) ms"
    }
    
    // 根据延迟值返回对应的颜色
    private func delayColor(_ delay: Int) -> Color {
        switch delay {
        case 0:
            return .red
        case 1...100:
            return .green
        case 101...200:
            return .yellow
        case 201...500:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - 代理提供者卡片
struct ProviderCard: View {
    let provider: Provider
    @ObservedObject var viewModel: ProxyViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(provider.name)
                    .font(.system(.body, design: .rounded))
                    .bold()
                
                Spacer()
                
                // 显示节点数量
                Text("\(provider.nodeCount) 个节点")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 订阅信息（如果有）
            if let info = provider.subscriptionInfo {
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("已用流量")
                        Text(formatTraffic(info.download + info.upload))
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("总流量")
                        Text(formatTraffic(info.total))
                            .foregroundColor(.secondary)
                    }
                }
                .font(.footnote)
            }
            
            HStack {
                Button {
                    Task {
                        await viewModel.updateProxyProvider(providerName: provider.name)
                    }
                } label: {
                    Label("更新", systemImage: "arrow.triangle.2.circlepath")
                }
                
                Button {
                    Task {
                        await viewModel.healthCheckProvider(providerName: provider.name)
                    }
                } label: {
                    Label("测速", systemImage: "speedometer")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // 格式化流量显示
    private func formatTraffic(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1024 / 1024 / 1024
        return String(format: "%.2f GB", gb)
    }
}

#Preview {
    NavigationStack {
        ProxyView(server: ClashServer(name: "测试服务器", url: "10.1.1.2", port: "9090", secret: "123456"))
    }
} 