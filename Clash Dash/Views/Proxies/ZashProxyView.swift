import SwiftUI

struct ZashProxyView: View {
    let server: ClashServer
    @StateObject private var viewModel: ProxyViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedGroup: ProxyGroup?
    @AppStorage("allowManualURLTestGroupSwitch") private var allowManualURLTestGroupSwitch = false
    @State private var showURLTestAlert = false
    
    // 计算每行显示的列数
    private var columnsCount: Int {
        // 根据设备尺寸和方向动态调整列数
        switch horizontalSizeClass {
        case .compact:
            return 2 // iPhone 竖屏
        case .regular:
            return 4 // iPad 或 iPhone 横屏
        default:
            return 2
        }
    }
    
    init(server: ClashServer) {
        self.server = server
        self._viewModel = StateObject(wrappedValue: ProxyViewModel(server: server))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.groups.isEmpty {
                        LoadingView()
                    } else {
                        // 代理组网格
                        let columns = makeColumns(availableWidth: geometry.size.width)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(viewModel.getSortedGroups(), id: \.name) { group in
                                ZashGroupCard(group: group, viewModel: viewModel, containerWidth: geometry.size.width)
                                    .onTapGesture {
                                        HapticManager.shared.impact(.light)
                                        selectedGroup = group
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                        
                        // 代理提供者部分
                        if !UserDefaults.standard.bool(forKey: "hideProxyProviders") {
                            let httpProviders = viewModel.providers
                                .filter { ["HTTP", "FILE"].contains($0.vehicleType.uppercased()) }
                                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                            
                            if !httpProviders.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("代理提供者")
                                        .font(.system(.title3, design: .rounded))
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 12)
                                    
                                    LazyVGrid(columns: columns, spacing: 8) {
                                        ForEach(httpProviders, id: \.name) { provider in
                                            ZashProviderCard(
                                                provider: provider,
                                                nodes: viewModel.providerNodes[provider.name] ?? [],
                                                viewModel: viewModel,
                                                containerWidth: geometry.size.width
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await viewModel.fetchProxies()
        }
        .task {
            await viewModel.fetchProxies()
        }
        .sheet(item: $selectedGroup) { group in
            NavigationStack {
                ZashGroupDetailView(
                    group: group,
                    viewModel: viewModel
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("自动测速选择分组", isPresented: $showURLTestAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("该分组不支持手动切换节点，可在全局设置中启用手动切换")
        }
    }
    
    // 修改辅助方法
    private func makeColumns(availableWidth: CGFloat) -> [GridItem] {
        let horizontalPadding: CGFloat = 24
        let spacing: CGFloat = 8
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let width = availableWidth - horizontalPadding
        let optimalColumnCount = max(2, Int(width / (minCardWidth + spacing)))
        let cardWidth = min(maxCardWidth, (width - (CGFloat(optimalColumnCount - 1) * spacing)) / CGFloat(optimalColumnCount))
        
        return Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing), count: optimalColumnCount)
    }
    
    private func makeSheetColumns(availableWidth: CGFloat) -> [GridItem] {
        let horizontalPadding: CGFloat = 32
        let spacing: CGFloat = 12
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let width = availableWidth - horizontalPadding
        let optimalColumnCount = max(2, Int(width / (minCardWidth + spacing)))
        let cardWidth = min(maxCardWidth, (width - (CGFloat(optimalColumnCount - 1) * spacing)) / CGFloat(optimalColumnCount))
        
        return Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing), count: optimalColumnCount)
    }
}

// Zash 样式的代理组卡片
struct ZashGroupCard: View {
    let group: ProxyGroup
    @ObservedObject var viewModel: ProxyViewModel
    let containerWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lowDelayThreshold") private var lowDelayThreshold = 240
    @AppStorage("mediumDelayThreshold") private var mediumDelayThreshold = 500
    
    private var cardDimensions: (width: CGFloat, height: CGFloat) {
        let horizontalPadding: CGFloat = 24
        let spacing: CGFloat = 8
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let width = containerWidth - horizontalPadding
        let optimalColumnCount = max(2, Int(width / (minCardWidth + spacing)))
        let cardWidth = min(maxCardWidth, (width - (CGFloat(optimalColumnCount - 1) * spacing)) / CGFloat(optimalColumnCount))
        
        return (width: cardWidth, height: 90)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    // 获取当前节点的延迟
    private var currentNodeDelay: Int {
        if group.type.lowercased() == "loadbalance" {
            return 0
        }
        let (_, delay) = getActualNodeAndDelay(nodeName: group.now, viewModel: viewModel)
        return delay
    }
    
    // 根据延迟获取颜色
    private var delayColor: Color {
        let delay = currentNodeDelay
        if delay == 0 {
            return .gray
        } else if delay < lowDelayThreshold {
            return .green
        } else if delay < mediumDelayThreshold {
            return .yellow
        } else {
            return .orange
        }
    }
    
    // 添加辅助函数来处理名称
    private var displayInfo: (icon: String, name: String) {
        let name = group.name
        guard let firstScalar = name.unicodeScalars.first,
              firstScalar.properties.isEmoji else {
            return (String(name.prefix(1)).uppercased(), name)
        }
        
        // 如果第一个字符是 emoji，将其作为图标
        let emoji = String(name.unicodeScalars.prefix(1))
        let remainingName = name.dropFirst()
        return (emoji, String(remainingName).trimmingCharacters(in: .whitespaces))
    }
    
    // 添加辅助函数来获取代理组类型的显示文本
    private func getGroupTypeText(_ type: String) -> String {
        switch type.lowercased() {
        case "relay":
            return "链式代理"
        case "load-balance", "loadbalance":
            return "负载均衡"
        case "fallback":
            return "自动回退"
        case "select", "selector":
            return "手动选择"
        case "url-test", "urltest":
            return "自动选择"
        default:
            return type
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧内容区域
            VStack(alignment: .leading, spacing: 4) {
                // 主标题
                Text(group.name)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // 副标题（当前选中的节点）
                if group.type == "LoadBalance" {
                    Text("负载均衡")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(group.now)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                // 类型
                Text(getGroupTypeText(group.type))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 右侧图标
            if let iconUrl = group.icon, !iconUrl.isEmpty {
                CachedAsyncImage(url: iconUrl)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(width: cardDimensions.width, height: cardDimensions.height)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    delayColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                    lineWidth: 0.5
                )
        )
        .overlay(
            // 添加顶部微妙的光泽效果
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.07 : 0.15),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08),
            radius: 8,
            x: 0,
            y: 4
        )
        // 添加内部阴影效果
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05),
                    lineWidth: 1
                )
                .blur(radius: 2)
                .mask(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.black, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        // 根据延迟状态添加微小的边框高亮
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    delayColor.opacity(colorScheme == .dark ? 0.3 : 0.15),
                    lineWidth: 0.5
                )
        )
    }
    
    // 获取实际节点和延迟
    private func getActualNodeAndDelay(nodeName: String, viewModel: ProxyViewModel) -> (ProxyNode?, Int) {
        guard let node = viewModel.nodes.first(where: { $0.name == nodeName }) else {
            return (nil, 0)
        }
        return (node, node.delay)
    }
}

// 添加一个新的视图组件来处理提供者详情
private struct ProviderDetailView: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 详细信息卡片
                InfoCard(provider: provider)
                
                // 节点列表
                NodesGrid(provider: provider, nodes: nodes, viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle(provider.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.healthCheckProvider(providerName: provider.name)
                    }
                } label: {
                    Label("测速", systemImage: "bolt.horizontal")
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
    }
}

// 提供者信息卡片
private struct InfoCard: View {
    let provider: Provider
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let info = provider.subscriptionInfo,
               info.total > 0 || info.upload > 0 || info.download > 0 {
                // 流量使用信息
                TrafficInfo(info: info)
                
                // 到期时间
                if info.expire > 0 {
                    ExpirationInfo(timestamp: info.expire)
                }
            }
            
            // 更新时间
            if let updatedAt = provider.updatedAt {
                UpdateTimeInfo(updatedAt: updatedAt)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// 流量信息组件
private struct TrafficInfo: View {
    let info: SubscriptionInfo
    
    var body: some View {
        HStack {
            Text("流量使用")
                .font(.headline)
            Spacer()
            let usedBytes = formatBytes(Int64(info.upload + info.download))
            let totalBytes = formatBytes(info.total)
            Text("\(usedBytes) / \(totalBytes)")
                .foregroundStyle(.secondary)
        }
    }
    
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
}

// 到期时间组件
private struct ExpirationInfo: View {
    let timestamp: Int64
    
    var body: some View {
        HStack {
            Text("到期时间")
                .font(.headline)
            Spacer()
            Text(formatExpireDate(timestamp))
                .foregroundStyle(.secondary)
        }
    }
    
    private func formatExpireDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// 更新时间组件
private struct UpdateTimeInfo: View {
    let updatedAt: String
    
    var body: some View {
        HStack {
            Text("更新时间")
                .font(.headline)
            Spacer()
            if let updateDate = parseDate(updatedAt) {
                Text(formatRelativeTime(updateDate))
                    .foregroundStyle(.secondary)
            } else {
                Text("未知")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// 节点网格组件
private struct NodesGrid: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    
    var body: some View {
        LazyVGrid(columns: makeColumns(), spacing: 12) {
            ForEach(nodes) { node in
                ProxyNodeCard(
                    nodeName: node.name,
                    node: node,
                    isSelected: false,
                    isTesting: viewModel.testingNodes.contains(node.name),
                    viewModel: viewModel
                )
                .onTapGesture {
                    HapticManager.shared.impact(.light)
                    Task {
                        await viewModel.healthCheckProviderProxy(
                            providerName: provider.name,
                            proxyName: node.name
                        )
                    }
                }
            }
        }
    }
    
    private func makeColumns() -> [GridItem] {
        let screenWidth = UIScreen.main.bounds.width
        let spacing: CGFloat = 12
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let columnsCount = max(2, Int(screenWidth / (minCardWidth + spacing * 2)))
        return Array(repeating: GridItem(.flexible(minimum: minCardWidth, maximum: maxCardWidth), spacing: spacing), count: columnsCount)
    }
}

// Zash 样式的代理提供者卡片
struct ZashProviderCard: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    let containerWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @State private var isUpdating = false
    @State private var showingUpdateSuccess = false
    @State private var showingSheet = false
    
    private var cardDimensions: (width: CGFloat, height: CGFloat) {
        let horizontalPadding: CGFloat = 24
        let spacing: CGFloat = 8
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let width = containerWidth - horizontalPadding
        let optimalColumnCount = max(2, Int(width / (minCardWidth + spacing)))
        let cardWidth = min(maxCardWidth, (width - (CGFloat(optimalColumnCount - 1) * spacing)) / CGFloat(optimalColumnCount))
        
        return (width: cardWidth, height: 90)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    // 获取流量信息
    private var usageInfo: String? {
        let currentProvider = viewModel.providers.first { $0.name == provider.name } ?? provider
        guard let info = currentProvider.subscriptionInfo,
              info.total > 0 || info.upload > 0 || info.download > 0 else { return nil }
        let used = Double(info.upload + info.download)
        let usedFormatted = formatBytes(Int64(used))
        let totalFormatted = formatBytes(info.total)
        return "\(usedFormatted) / \(totalFormatted)"
    }
    
    // 格式化字节
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
    
    var body: some View {
        ZStack {
            // 卡片主体内容
            HStack(spacing: 12) {
                // 左侧内容区域
                VStack(alignment: .leading, spacing: 4) {
                    // 提供者名称
                    Text(provider.name)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // 流量信息
                    if let usage = usageInfo {
                        Text(usage)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("无流量信息")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    // 更新时间
                    if let updatedAt = provider.updatedAt,
                       let updateDate = parseDate(updatedAt) {
                        Text(formatRelativeTime(updateDate))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 右侧占位区域，与按钮大小相同
                Color.clear
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(width: cardDimensions.width, height: cardDimensions.height)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color(.systemGray4).opacity(colorScheme == .dark ? 0.2 : 0.3),
                        lineWidth: 0.5
                    )
            )
            .overlay(
                // 添加顶部微妙的光泽效果
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.07 : 0.15),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08),
                radius: 8,
                x: 0,
                y: 4
            )
            // 添加内部阴影效果
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05),
                        lineWidth: 1
                    )
                    .blur(radius: 2)
                    .mask(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            .scaleEffect(isUpdating ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isUpdating)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.shared.impact(.light)
                showingSheet = true
            }
            
            // 右侧更新按钮，放在 ZStack 的顶层
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        Task {
                            HapticManager.shared.impact(.light)
                            isUpdating = true
                            
                            await withTaskCancellationHandler {
                                await viewModel.updateProxyProvider(providerName: provider.name)
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                await viewModel.fetchProxies()
                                
                                await MainActor.run {
                                    HapticManager.shared.notification(.success)
                                    isUpdating = false
                                    withAnimation {
                                        showingUpdateSuccess = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            showingUpdateSuccess = false
                                        }
                                    }
                                }
                            } onCancel: {
                                Task { @MainActor in
                                    isUpdating = false
                                    HapticManager.shared.notification(.error)
                                }
                            }
                        }
                    } label: {
                        Group {
                            if isUpdating {
                                ProgressView()
                                    .tint(.blue)
                                    .scaleEffect(0.6)
                            } else if showingUpdateSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.system(size: 16, weight: .medium))
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.blue)
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .shadow(
                                    color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                                    radius: 3,
                                    x: 0,
                                    y: 1
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    Color(.systemGray4).opacity(colorScheme == .dark ? 0.2 : 0.15),
                                    lineWidth: 0.5
                                )
                        )
                    }
                    .disabled(isUpdating)
                    .padding(.trailing, 12)
                    .padding(.top, 12)
                    // 关键：使用 zIndex 确保按钮在最上层
                    .zIndex(1)
                    // 关键：使用 background 创建一个透明的点击区域
                    .background(
                        Color.clear
                            .contentShape(Circle())
                            .frame(width: 44, height: 44)
                    )
                }
                Spacer()
            }
            .frame(width: cardDimensions.width, height: cardDimensions.height)
            // 关键：只允许按钮区域接收点击事件，其他区域的点击事件会穿透到下层
            .allowsHitTesting(true)
        }
        .sheet(isPresented: $showingSheet) {
            NavigationStack {
                ZashProviderDetailView(
                    provider: provider,
                    nodes: nodes,
                    viewModel: viewModel
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    // 解析日期
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
    
    // 格式化相对时间
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// 添加 Zash 风格的节点卡片
struct ZashNodeCard: View {
    let nodeName: String
    let node: ProxyNode?
    let isSelected: Bool
    let isTesting: Bool
    @ObservedObject var viewModel: ProxyViewModel
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lowDelayThreshold") private var lowDelayThreshold = 240
    @AppStorage("mediumDelayThreshold") private var mediumDelayThreshold = 500
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    // 获取节点延迟
    private var nodeDelay: Int {
        if let node = node {
            return node.delay
        }
        return 0
    }
    
    // 根据延迟获取颜色
    private var delayColor: Color {
        let delay = nodeDelay
        if delay == 0 {
            return .gray
        } else if delay < lowDelayThreshold {
            return .green
        } else if delay < mediumDelayThreshold {
            return .yellow
        } else {
            return .orange
        }
    }
    
    // 获取节点类型标签
    private var nodeTypeLabel: String {
        if viewModel.groups.contains(where: { $0.name == nodeName }) {
            return "代理组"
        } else if nodeName == "DIRECT" {
            return "直连"
        } else if nodeName == "REJECT" {
            return "拒绝"
        } else {
            return node?.type ?? "未知"
        }
    }
    
    // 获取节点类型标签颜色
    private var nodeTypeLabelColor: Color {
        if nodeName == "DIRECT" {
            return .green
        } else if nodeName == "REJECT" {
            return .red
        } else if viewModel.groups.contains(where: { $0.name == nodeName }) {
            return .blue
        } else {
            return .purple
        }
    }
    
    // 获取延迟显示文本
    private var delayText: String {
        if isTesting {
            return "测速中"
        } else if nodeDelay > 0 {
            return "\(nodeDelay) ms"
        } else {
            return "超时"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 卡片内容
            VStack(alignment: .leading, spacing: 8) {
                // 顶部：节点名称和选中状态
                HStack(alignment: .top, spacing: 8) {
                    // 节点名称
                    Text(nodeName)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // 选中状态指示器
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 18))
                    }
                }
                
                Spacer()
                
                // 底部：节点类型和延迟
                HStack(alignment: .center) {
                    // 节点类型标签
                    Text(nodeTypeLabel)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(nodeTypeLabelColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(nodeTypeLabelColor.opacity(0.1))
                        )
                    
                    Spacer()
                    
                    // 延迟指示器
                    HStack(spacing: 4) {
                        if isTesting {
                            // 测速动画
                            ZashDelayTestingView()
                        } else {
                            // 延迟文本
                            Text(delayText)
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundStyle(delayColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(delayColor.opacity(0.1))
                                )
                        }
                    }
                }
            }
            .padding(12)
            .frame(height: 90)
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                // 选中状态边框
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.blue : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            )
            .overlay(
                // 添加顶部微妙的光泽效果
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.07 : 0.15),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08),
                radius: 8,
                x: 0,
                y: 4
            )
            // 添加内部阴影效果
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05),
                        lineWidth: 1
                    )
                    .blur(radius: 2)
                    .mask(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            // 根据延迟状态添加微小的边框高亮
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        delayColor.opacity(colorScheme == .dark ? 0.3 : 0.15),
                        lineWidth: 0.5
                    )
            )
        }
        .animation(.spring(response: 0.3), value: isSelected)
        .animation(.spring(response: 0.3), value: isTesting)
    }
}

// 添加 Zash 风格的延迟测试动画
struct ZashDelayTestingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 12))
                .foregroundStyle(.blue)
            
            Text("测速中")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.1))
        )
        .opacity(isAnimating ? 0.6 : 1.0)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

// 添加 Zash 风格的提供者详情视图
struct ZashProviderDetailView: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    
    private var filteredNodes: [ProxyNode] {
        if searchText.isEmpty {
            return nodes
        } else {
            return nodes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 提供者信息卡片
                ZashInfoCard(provider: provider)
                
                // 搜索栏 - 修改样式使其更加明显
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜索节点", text: $searchText)
                        .font(.system(.body, design: .rounded))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 3, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                
                // 节点统计信息
                HStack {
                    Text("共 \(nodes.count) 个节点")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // 延迟统计
                    let stats = getDelayStats()
                    HStack(spacing: 8) {
                        DelayStatBadge(count: stats.green, color: .green, label: "低延迟")
                        DelayStatBadge(count: stats.yellow, color: .yellow, label: "中延迟")
                        DelayStatBadge(count: stats.orange, color: .orange, label: "高延迟")
                        DelayStatBadge(count: stats.gray, color: .gray, label: "超时")
                    }
                }
                .padding(.horizontal)
                
                // 节点列表
                ZashNodesGrid(
                    provider: provider,
                    nodes: filteredNodes,
                    viewModel: viewModel
                )
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(provider.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.healthCheckProvider(providerName: provider.name)
                    }
                } label: {
                    Label("测速", systemImage: "bolt.horizontal")
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
    }
    
    // 获取延迟统计
    private func getDelayStats() -> (green: Int, yellow: Int, orange: Int, gray: Int) {
        let lowThreshold = UserDefaults.standard.integer(forKey: "lowDelayThreshold")
        let mediumThreshold = UserDefaults.standard.integer(forKey: "mediumDelayThreshold")
        
        let lowDelay = lowThreshold == 0 ? 240 : lowThreshold
        let mediumDelay = mediumThreshold == 0 ? 500 : mediumThreshold
        
        var green = 0
        var yellow = 0
        var orange = 0
        var gray = 0
        
        for node in nodes {
            if node.delay == 0 {
                gray += 1
            } else if node.delay < lowDelay {
                green += 1
            } else if node.delay < mediumDelay {
                yellow += 1
            } else {
                orange += 1
            }
        }
        
        return (green, yellow, orange, gray)
    }
}

// 延迟统计徽章
struct DelayStatBadge: View {
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        if count > 0 {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text("\(count)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// Zash 风格的提供者信息卡片
struct ZashInfoCard: View {
    let provider: Provider
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 流量信息部分
            if let info = provider.subscriptionInfo,
               info.total > 0 || info.upload > 0 || info.download > 0 {
                
                // 流量使用进度条
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("流量使用")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        let usedBytes = formatBytes(Int64(info.upload + info.download))
                        let totalBytes = formatBytes(info.total)
                        let remainingBytes = formatBytes(max(0, info.total - info.upload - info.download))
                        Text("\(remainingBytes) / \(totalBytes)")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    // 流量进度条 - 显示剩余流量百分比
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            
                            // 进度 - 剩余流量
                            let remainingPercentage = max(0, min(1.0, 1.0 - Double(info.upload + info.download) / Double(info.total)))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * remainingPercentage, height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    // 上传下载详情
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("上传")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            Text(formatBytes(Int64(info.upload)))
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("下载")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            Text(formatBytes(Int64(info.download)))
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundStyle(.purple)
                        }
                    }
                }
                
                Divider()
                
                // 到期时间和更新时间
                HStack {
                    // 到期时间
                    if info.expire > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("到期时间")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            Text(formatExpireDate(info.expire))
                                .font(.system(.subheadline, design: .rounded))
                        }
                    }
                    
                    Spacer()
                    
                    // 更新时间
                    if let updatedAt = provider.updatedAt,
                       let updateDate = parseDate(updatedAt) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("更新时间")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            Text(formatRelativeTime(updateDate))
                                .font(.system(.subheadline, design: .rounded))
                        }
                    }
                }
            } else {
                // 无流量信息时显示
                HStack {
                    Text("无订阅信息")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // 更新时间
                    if let updatedAt = provider.updatedAt,
                       let updateDate = parseDate(updatedAt) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("更新时间")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            Text(formatRelativeTime(updateDate))
                                .font(.system(.subheadline, design: .rounded))
                        }
                    }
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            // 添加顶部微妙的光泽效果
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.07 : 0.15),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08),
            radius: 8,
            x: 0,
            y: 4
        )
        .padding(.horizontal)
    }
    
    // 格式化字节
    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.1fGB", gb)
        } else if mb >= 1 {
            return String(format: "%.1fMB", mb)
        } else if kb >= 1 {
            return String(format: "%.1fKB", kb)
        } else {
            return "\(bytes)B"
        }
    }
    
    // 格式化到期日期
    private func formatExpireDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // 解析日期
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
    
    // 格式化相对时间
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Zash 风格的节点网格
struct ZashNodesGrid: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        if nodes.isEmpty {
            Text("没有找到节点")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else {
            LazyVGrid(columns: makeColumns(), spacing: 12) {
                ForEach(nodes) { node in
                    ZashNodeCard(
                        nodeName: node.name,
                        node: node,
                        isSelected: false,
                        isTesting: viewModel.testingNodes.contains(node.name),
                        viewModel: viewModel
                    )
                    .onTapGesture {
                        HapticManager.shared.impact(.light)
                        Task {
                            await viewModel.healthCheckProviderProxy(
                                providerName: provider.name,
                                proxyName: node.name
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
            .animation(.spring(response: 0.3), value: nodes.count)
        }
    }
    
    private func makeColumns() -> [GridItem] {
        let screenWidth = UIScreen.main.bounds.width
        let spacing: CGFloat = 12
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let columnsCount = max(2, Int(screenWidth / (minCardWidth + spacing * 2)))
        return Array(repeating: GridItem(.flexible(minimum: minCardWidth, maximum: maxCardWidth), spacing: spacing), count: columnsCount)
    }
}

// 添加 Zash 风格的代理组详情视图
struct ZashGroupDetailView: View {
    let group: ProxyGroup
    @ObservedObject var viewModel: ProxyViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @AppStorage("allowManualURLTestGroupSwitch") private var allowManualURLTestGroupSwitch = false
    @State private var showURLTestAlert = false
    
    private var filteredNodes: [String] {
        if searchText.isEmpty {
            return group.all
        } else {
            return group.all.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 搜索栏 - 修改样式使其更加明显
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜索节点", text: $searchText)
                        .font(.system(.body, design: .rounded))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 3, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                
                // 节点统计信息
                HStack {
                    Text("共 \(group.all.count) 个节点")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // 延迟统计
                    let stats = getDelayStats()
                    HStack(spacing: 8) {
                        DelayStatBadge(count: stats.green, color: .green, label: "低延迟")
                        DelayStatBadge(count: stats.yellow, color: .yellow, label: "中延迟")
                        DelayStatBadge(count: stats.orange, color: .orange, label: "高延迟")
                        DelayStatBadge(count: stats.gray, color: .gray, label: "超时")
                    }
                }
                .padding(.horizontal)
                
                // 节点列表
                if filteredNodes.isEmpty {
                    Text("没有找到节点")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    LazyVGrid(columns: makeColumns(), spacing: 12) {
                        ForEach(filteredNodes.indices, id: \.self) { index in
                            let nodeName = filteredNodes[index]
                            ZashNodeCard(
                                nodeName: nodeName,
                                node: viewModel.nodes.first { $0.name == nodeName },
                                isSelected: viewModel.groups.first(where: { $0.name == group.name })?.now == nodeName,
                                isTesting: viewModel.testingNodes.contains(nodeName),
                                viewModel: viewModel
                            )
                            .onTapGesture {
                                HapticManager.shared.impact(.light)
                                
                                if group.type == "URLTest" && !allowManualURLTestGroupSwitch {
                                    // 显示不支持手动切换的提示
                                    showURLTestAlert = true
                                    HapticManager.shared.notification(.error)
                                    return
                                }
                                
                                Task {
                                    await viewModel.selectProxy(groupName: group.name, proxyName: nodeName)
                                    await MainActor.run {
                                        // 添加成功的触觉反馈
                                        HapticManager.shared.notification(.success)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .animation(.spring(response: 0.3), value: filteredNodes.count)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.testGroupSpeed(groupName: group.name)
                    }
                } label: {
                    Label("测速", systemImage: "bolt.horizontal")
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
        .alert("自动测速选择分组", isPresented: $showURLTestAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("该分组不支持手动切换节点，可在全局设置中启用手动切换")
        }
    }
    
    // 获取延迟统计
    private func getDelayStats() -> (green: Int, yellow: Int, orange: Int, gray: Int) {
        let lowThreshold = UserDefaults.standard.integer(forKey: "lowDelayThreshold")
        let mediumThreshold = UserDefaults.standard.integer(forKey: "mediumDelayThreshold")
        
        let lowDelay = lowThreshold == 0 ? 240 : lowThreshold
        let mediumDelay = mediumThreshold == 0 ? 500 : mediumThreshold
        
        var green = 0
        var yellow = 0
        var orange = 0
        var gray = 0
        
        for nodeName in group.all {
            if let node = viewModel.nodes.first(where: { $0.name == nodeName }) {
                if node.delay == 0 {
                    gray += 1
                } else if node.delay < lowDelay {
                    green += 1
                } else if node.delay < mediumDelay {
                    yellow += 1
                } else {
                    orange += 1
                }
            } else {
                gray += 1
            }
        }
        
        return (green, yellow, orange, gray)
    }
    
    private func makeColumns() -> [GridItem] {
        let screenWidth = UIScreen.main.bounds.width
        let spacing: CGFloat = 12
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let columnsCount = max(2, Int(screenWidth / (minCardWidth + spacing * 2)))
        return Array(repeating: GridItem(.flexible(minimum: minCardWidth, maximum: maxCardWidth), spacing: spacing), count: columnsCount)
    }
}

#Preview {
    ZashProxyView(server: ClashServer(name: "测试服务器", url: "192.168.1.1", port: "9090", secret: "123456"))
} 
