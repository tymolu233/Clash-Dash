import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("加载中")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProxyView: View {
    let server: ClashServer
    @StateObject private var viewModel: ProxyViewModel
    @State private var selectedGroupId: String?
    @State private var isRefreshing = false
    @State private var showProviderSheet = false
    @Namespace private var animation
    
    init(server: ClashServer) {
        self.server = server
        self._viewModel = StateObject(wrappedValue: ProxyViewModel(server: server))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.groups.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView {
                            Label("加载中", systemImage: "network")
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        LoadingView()
                    }
                } else {
                    // 代理组概览卡片
                    ProxyGroupsOverview(
                        groups: viewModel.getSortedGroups(),
                        viewModel: viewModel
                    )
                    
                    // 代理提供者部分
                    if !viewModel.providers.isEmpty {
                        ProxyProvidersSection(
                            providers: viewModel.providers,
                            nodes: viewModel.providerNodes,
                            viewModel: viewModel
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await refreshData()
        }
        .navigationTitle(server.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showProviderSheet = true
                    } label: {
                        Label("��加", systemImage: "square.stack.3d.up")
                    }
                    
                    Button {
                        Task { await refreshData() }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, 
                                     value: isRefreshing)
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .sheet(isPresented: $showProviderSheet) {
            ProvidersSheetView(
                providers: viewModel.providers,
                nodes: viewModel.providerNodes,
                viewModel: viewModel
            )
            .presentationDetents([.medium, .large])
        }
        .task {
            await viewModel.fetchProxies()
        }
    }
    
    private func refreshData() async {
        withAnimation { isRefreshing = true }
        await viewModel.fetchProxies()
        withAnimation { isRefreshing = false }
    }
    
    private func sortNodes(_ nodeNames: [String], _ allNodes: [ProxyNode], groupName: String) -> [ProxyNode] {
        let specialNodes = ["DIRECT", "REJECT"]
        var matchedNodes = nodeNames.compactMap { name in
            if specialNodes.contains(name) {
                if let existingNode = allNodes.first(where: { $0.name == name }) {
                    return existingNode
                }
                return ProxyNode(
                    id: UUID().uuidString,
                    name: name,
                    type: "Special",
                    alive: true,
                    delay: 0,
                    history: []
                )
            }
            return allNodes.first { $0.name == name }
        }
        
        // 检查是否需要隐藏不可用代理
        let hideUnavailable = UserDefaults.standard.bool(forKey: "hideUnavailableProxies")
        if hideUnavailable {
            matchedNodes = matchedNodes.filter { node in
                specialNodes.contains(node.name) || node.delay > 0
            }
        }
        
        return matchedNodes.sorted { node1, node2 in
            if node1.name == "DIRECT" { return true }
            if node2.name == "DIRECT" { return false }
            if node1.name == "REJECT" { return true }
            if node2.name == "REJECT" { return false }
            if node1.name == groupName { return true }
            if node2.name == groupName { return false }
            
            if node1.delay == 0 { return false }
            if node2.delay == 0 { return true }
            return node1.delay < node2.delay
        }
    }
}

// 代理组概览卡片
struct ProxyGroupsOverview: View {
    let groups: [ProxyGroup]
    @ObservedObject var viewModel: ProxyViewModel
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(groups, id: \.name) { group in
                GroupCard(
                    group: group,
                    viewModel: viewModel
                )
            }
        }
    }
}

// 单个代理组卡片
struct GroupCard: View {
    let group: ProxyGroup
    @ObservedObject var viewModel: ProxyViewModel
    @State private var showingProxySelector = false
    
    private var delayStats: (green: Int, yellow: Int, red: Int, timeout: Int) {
        var green = 0   // 低延迟 (0-150ms)
        var yellow = 0  // 中等延迟 (151-300ms)
        var red = 0     // 高延迟 (>300ms)
        var timeout = 0 // 未连接 (0ms)
        
        for nodeName in group.all {
            if let node = viewModel.nodes.first(where: { $0.name == nodeName }) {
                switch node.delay {
                case 0:
                    timeout += 1
                case DelayColor.lowRange:
                    green += 1
                case DelayColor.mediumRange:
                    yellow += 1
                default:
                    red += 1
                }
            } else {
                timeout += 1
            }
        }
        
        return (green, yellow, red, timeout)
    }
    
    private var totalNodes: Int {
        group.all.count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 标题行
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(group.name)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if group.type == "URLTest" {
                            Image(systemName: "bolt.horizontal.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.caption)
                        }
                    }
                    
                    Text(group.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 添加节点数量显示
                Text("\(totalNodes) 个节点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }
            
            Divider()
                .padding(.horizontal, -16)
            
            // 当前节点信息 - 使用更小巧的设计
            HStack(spacing: 8) {
                Image(systemName: getNodeIcon(for: group.now))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                if viewModel.testingGroups.contains(group.name) {
                    // 显示测速动画
                    DelayTestingView()
                        .foregroundStyle(.blue)
                        .transition(.opacity)
                } else if let currentNode = viewModel.nodes.first(where: { $0.name == group.now }) {
                    Text(currentNode.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    if currentNode.delay > 0 {
                        Text("\(currentNode.delay) ms")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DelayColor.color(for: currentNode.delay).opacity(0.1))
                            .foregroundStyle(DelayColor.color(for: currentNode.delay))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.testingGroups.contains(group.name))
            
            // 延迟统计条
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    if delayStats.green > 0 {
                        Rectangle()
                            .fill(DelayColor.low.opacity(0.85))
                            .frame(width: CGFloat(delayStats.green) / CGFloat(totalNodes) * geometry.size.width)
                    }
                    if delayStats.yellow > 0 {
                        Rectangle()
                            .fill(DelayColor.medium.opacity(0.85))
                            .frame(width: CGFloat(delayStats.yellow) / CGFloat(totalNodes) * geometry.size.width)
                    }
                    if delayStats.red > 0 {
                        Rectangle()
                            .fill(DelayColor.high.opacity(0.85))
                            .frame(width: CGFloat(delayStats.red) / CGFloat(totalNodes) * geometry.size.width)
                    }
                    if delayStats.timeout > 0 {
                        Rectangle()
                            .fill(DelayColor.disconnected.opacity(0.3))
                            .frame(width: CGFloat(delayStats.timeout) / CGFloat(totalNodes) * geometry.size.width)
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
            }
            .frame(height: 8)
            
            // 延迟统计数据
            HStack {
                // 左侧延迟统计
                HStack(spacing: 12) {
                    ForEach([
                        (count: delayStats.green, color: DelayColor.low, label: "低延迟"),
                        (count: delayStats.yellow, color: DelayColor.medium, label: "中等"),
                        (count: delayStats.red, color: DelayColor.high, label: "高延迟"),
                        (count: delayStats.timeout, color: DelayColor.disconnected, label: "超时")
                    ], id: \.label) { stat in
                        if stat.count > 0 {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(stat.color.opacity(0.85))
                                    .frame(width: 6, height: 6)
                                Text("\(stat.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 右侧总点数
                // Text("\(totalNodes) 个节点")
                //     .font(.caption2)
                //     .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .onTapGesture {
            // 添加触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // 总是显示选择器
            showingProxySelector = true
        }
        .sheet(isPresented: $showingProxySelector) {
            ProxySelectorSheet(
                group: group,
                viewModel: viewModel
            )
        }
    }
    
    private func getStatusColor(for nodeName: String) -> Color {
        switch nodeName {
        case "DIRECT":
            return .green
        case "REJECT":
            return .red
        default:
            return .blue
        }
    }
    
    private func getNodeIcon(for nodeName: String) -> String {
        switch nodeName {
        case "DIRECT":
            return "arrow.up.forward"
        case "REJECT":
            return "xmark.circle"
        default:
            if let node = viewModel.nodes.first(where: { $0.name == nodeName }) {
                switch node.type.lowercased() {
                case "ss", "shadowsocks":
                    return "bolt.shield"
                case "vmess":
                    return "v.circle"
                case "trojan":
                    return "shield.lefthalf.filled"
                case "http", "https":
                    return "globe"
                case "socks", "socks5":
                    return "network"
                default:
                    return "antenna.radiowaves.left.and.right"
                }
            }
            return "antenna.radiowaves.left.and.right"
        }
    }
}

// 代理提供者部分
struct ProxyProvidersSection: View {
    let providers: [Provider]
    let nodes: [String: [ProxyNode]]
    @ObservedObject var viewModel: ProxyViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("代理提供者")
                .font(.title2.bold())
            
            ForEach(providers.sorted(by: { $0.name < $1.name })) { provider in
                ProviderCard(provider: provider, 
                            nodes: nodes[provider.name] ?? [], 
                            viewModel: viewModel)
            }
        }
    }
}

struct ProviderCard: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 移除原有的展开按钮，整个卡片可点击
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.headline)
                    
                    if let info = provider.subscriptionInfo {
                        Text("已用流量: \(formatBytes(info.upload + info.download)) / \(formatBytes(info.total))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.updateProxyProvider(providerName: provider.name)
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            
            if isExpanded {
                Divider()
                
                // 节点列表
                LazyVStack(spacing: 8) {
                    ForEach(nodes) { node in
                        HStack {
                            Text(node.name)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            if viewModel.testingNodes.contains(node.id) {
                                DelayTestingView()
                                    .foregroundStyle(.blue)
                                    .transition(.opacity)
                            } else if node.delay > 0 {
                                Text("\(node.delay) ms")
                                    .font(.caption)
                                    .foregroundStyle(getDelayColor(node.delay))
                                    .transition(.opacity)
                            } else {
                                Text("超时")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle()) // 确保整行可点击
                        .onTapGesture {
                            Task {
                                await viewModel.testNodeDelay(nodeName: node.name)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: viewModel.testingNodes.contains(node.id))
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .onTapGesture {
            withAnimation {
                isExpanded.toggle()
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func getDelayColor(_ delay: Int) -> Color {
        DelayColor.color(for: delay)
    }
}

// 其他辅助视图和法保持不变...

struct ProvidersSheetView: View {
    let providers: [Provider]
    let nodes: [String: [ProxyNode]]
    @ObservedObject var viewModel: ProxyViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(providers.sorted(by: { $0.name < $1.name })) { provider in
                    Section(provider.name) {
                        if let nodes = nodes[provider.name] {
                            ForEach(nodes) { node in
                                HStack {
                                    Text(node.name)
                                    Spacer()
                                    if node.delay > 0 {
                                        Text("\(node.delay) ms")
                                            .foregroundStyle(getDelayColor(node.delay))
                                    } else {
                                        Text("超时")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("代理提供者")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getDelayColor(_ delay: Int) -> Color {
        DelayColor.color(for: delay)
    }
}

struct ScrollClipModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollClipDisabled()
        } else {
            content
        }
    }
}

// 修改 ProxySelectorSheet 使用网格布局
struct ProxySelectorSheet: View {
    let group: ProxyGroup
    @ObservedObject var viewModel: ProxyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showURLTestAlert = false
    @AppStorage("proxyGroupSortOrder") private var proxyGroupSortOrder = ProxyGroupSortOrder.default
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    // 节点统计
                    HStack {
                        Text("节点列表")
                            .font(.headline)
                        Spacer()
                        Text("\(group.all.count) 个节点")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 节点网格 - 使用排序后的节点列表
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.getSortedNodes(group.all, in: group), id: \.self) { nodeName in
                            let node = viewModel.nodes.first { $0.name == nodeName }
                            ProxyNodeCard(
                                nodeName: nodeName,
                                node: node,
                                isSelected: group.now == nodeName,
                                isTesting: node.map { viewModel.testingNodes.contains($0.id) } ?? false
                            )
                            .onTapGesture {
                                // 添加触觉反馈
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                if group.type == "URLTest" {
                                    showURLTestAlert = true
                                } else {
                                    Task {
                                        // 先切换节点
                                        await viewModel.selectProxy(groupName: group.name, proxyName: nodeName)
                                        // 如果不是 REJECT，则测试延迟
                                        if nodeName != "REJECT" {
                                            await viewModel.testNodeDelay(nodeName: nodeName)
                                        }
                                        // 移除自动关闭
                                        // dismiss()
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text(group.name)
                            .font(.headline)
                        
                        if viewModel.testingGroups.contains(group.name) {
                            DelayTestingView()
                                .foregroundStyle(.blue)
                                .scaleEffect(0.8)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // 添加触觉反馈
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        Task {
                            await viewModel.testGroupSpeed(groupName: group.name)
                        }
                    } label: {
                        Label("测速", systemImage: "bolt.horizontal")
                    }
                    .disabled(viewModel.testingGroups.contains(group.name))
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.testingGroups.contains(group.name))
            .alert("自动测速选择分组", isPresented: $showURLTestAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("该分组不支持手动切换节点")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// 添加节点卡片视图
struct ProxyNodeCard: View {
    let nodeName: String
    let node: ProxyNode?
    let isSelected: Bool
    let isTesting: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 节点名称和选中状态
            HStack {
                Circle()
                    .fill(getStatusColor(for: nodeName))
                    .frame(width: 8, height: 8)
                
                Text(nodeName)
                    .font(.system(.subheadline, design: .rounded))
                    .bold()
                    .lineLimit(1)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
            }
            
            // 节点类型延迟
            HStack {
                Text(node?.type ?? "Special")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                
                Spacer()
                
                if nodeName == "REJECT" {
                    Text("阻断")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                } else if isTesting {
                    DelayTestingView()
                        .foregroundStyle(.blue)
                        .scaleEffect(0.8)
                        .transition(.opacity)
                } else if let node = node, node.delay > 0 {
                    Text("\(node.delay) ms")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(getDelayColor(node.delay).opacity(0.1))
                        .foregroundStyle(getDelayColor(node.delay))
                        .clipShape(Capsule())
                        .transition(.opacity)
                } else {
                    Text("超时")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.1))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                        .transition(.opacity)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? .blue : .clear, lineWidth: 2)
        }
    }
    
    private func getStatusColor(for nodeName: String) -> Color {
        switch nodeName {
        case "DIRECT":
            return .green
        case "REJECT":
            return .red
        default:
            return .blue
        }
    }
    
    private func getDelayColor(_ delay: Int) -> Color {
        DelayColor.color(for: delay)
    }
}

// 更新 DelayColor 结构体，统一延迟颜色配置
struct DelayColor {
    // 延迟范围常量
    static let lowRange = 0...150
    static let mediumRange = 151...300
    static let highThreshold = 300
    
    static func color(for delay: Int) -> Color {
        switch delay {
        case 0:
            return Color(.systemGray2) // 未连接
        case lowRange:
            return Color(red: 0.2, green: 0.85, blue: 0.2) // 低延迟
        case mediumRange:
            return Color(red: 1.0, green: 0.6, blue: 0.0) // 中等延迟
        default:
            return Color(red: 1.0, green: 0.2, blue: 0.2) // 高延迟
        }
    }
    
    static let disconnected = Color(.systemGray2)
    static let low = Color(red: 0.2, green: 0.85, blue: 0.2)
    static let medium = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let high = Color(red: 1.0, green: 0.2, blue: 0.2)
}

// 修改延迟测试动画组件
struct DelayTestingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .foregroundStyle(.blue)
            .onAppear {
                withAnimation(
                    .linear(duration: 1)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
            .onDisappear {
                isAnimating = false
            }
    }
}

#Preview {
    NavigationStack {
        ProxyView(server: ClashServer(name: "测试服务器", url: "10.1.1.2", port: "9090", secret: "123456"))
    }
} 
