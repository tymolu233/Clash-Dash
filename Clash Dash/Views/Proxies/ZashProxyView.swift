import SwiftUI

struct ZashProxyView: View {
    let server: ClashServer
    @StateObject private var viewModel: ProxyViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedGroup: ProxyGroup?
    @AppStorage("allowManualURLTestGroupSwitch") private var allowManualURLTestGroupSwitch = false
    @State private var showURLTestAlert = false
    @State private var cachedColumns: [GridItem] = []
    @State private var lastWidth: CGFloat = 0
    @State private var isLoaded = false
    
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
                        // 分开渲染代理组网格和提供者网格，减少一次性渲染的视图数量
                        groupsGridView(width: geometry.size.width)
                            .padding(.bottom, 8)
                        
                        // 代理提供者部分
                        if !UserDefaults.standard.bool(forKey: "hideProxyProviders") {
                            providersGridView(width: geometry.size.width)
                        }
                    }
                }
                .padding(.vertical, 12)
                .opacity(isLoaded ? 1.0 : 0.3)
                .animation(.easeIn(duration: 0.3), value: isLoaded)
            }
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await refreshData()
        }
        .task {
            await loadData()
        }
        .sheet(item: $selectedGroup) { group in
            NavigationStack {
                ZashGroupDetailView(
                    group: group,
                    viewModel: viewModel
                )
                .transition(.opacity)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .background(Color(.systemBackground))
        }
        .alert("自动测速选择分组", isPresented: $showURLTestAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("该分组不支持手动切换节点，可在全局设置中启用手动切换")
        }
    }
    
    // 代理组网格视图
    @ViewBuilder
    private func groupsGridView(width: CGFloat) -> some View {
        let columns = getColumns(availableWidth: width)
        
        // 使用ID参数提高重用效率
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(viewModel.getSortedGroups(), id: \.name) { group in
                ZashGroupCard(group: group, viewModel: viewModel, containerWidth: width)
                    .onTapGesture {
                        HapticManager.shared.impact(.light)
                        selectedGroup = group
                    }
                    .id("\(group.name)-\(group.now)")
            }
        }
        .padding(.horizontal, 12)
    }
    
    // 代理提供者网格视图
    @ViewBuilder
    private func providersGridView(width: CGFloat) -> some View {
        let httpProviders = viewModel.providers
            .filter { ["HTTP", "FILE"].contains($0.vehicleType.uppercased()) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        if !httpProviders.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("代理提供者")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                
                let columns = getColumns(availableWidth: width)
                
                // 使用ID参数提高重用效率
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(httpProviders, id: \.name) { provider in
                        let nodes = viewModel.providerNodes[provider.name] ?? []
                        ZashProviderCard(
                            provider: provider,
                            nodes: nodes,
                            viewModel: viewModel,
                            containerWidth: width
                        )
                        .id("\(provider.name)-\(provider.updatedAt ?? "")")
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
    
    // 优化列计算逻辑，缓存计算结果
    private func getColumns(availableWidth: CGFloat) -> [GridItem] {
        // 如果宽度没有变化，直接使用缓存的结果
        if abs(availableWidth - lastWidth) < 1 && !cachedColumns.isEmpty {
            return cachedColumns
        }
        
        // 重新计算列
        let horizontalPadding: CGFloat = 24
        let spacing: CGFloat = 8
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let width = availableWidth - horizontalPadding
        let optimalColumnCount = max(2, Int(width / (minCardWidth + spacing)))
        let cardWidth = min(maxCardWidth, (width - (CGFloat(optimalColumnCount - 1) * spacing)) / CGFloat(optimalColumnCount))
        
        let newColumns = Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing), count: optimalColumnCount)
        
        // 避免在视图更新过程中直接修改状态
        DispatchQueue.main.async {
            self.lastWidth = availableWidth
            self.cachedColumns = newColumns
        }
        
        return newColumns
    }
    
    // 加载数据
    private func loadData() async {
        // 重置加载状态
        isLoaded = false
        
        // 获取代理数据
        await viewModel.fetchProxies()
        
        // 延迟显示以允许布局计算完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                isLoaded = true
            }
        }
    }
    
    // 刷新数据
    private func refreshData() async {
        await viewModel.fetchProxies()
    }
}

// Zash 样式的代理组卡片 - 简化版本
struct ZashGroupCard: View {
    let group: ProxyGroup
    @ObservedObject var viewModel: ProxyViewModel
    let containerWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lowDelayThreshold") private var lowDelayThreshold = 240
    @AppStorage("mediumDelayThreshold") private var mediumDelayThreshold = 500
    // 缓存计算结果
    @State private var cardSize: (width: CGFloat, height: CGFloat) = (width: 160, height: 90)
    
    // 优化计算，减少频繁计算
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    // 获取当前节点的延迟
    private var currentNodeDelay: Int {
        if group.type.lowercased() == "loadbalance" {
            return 0
        }
        if let node = viewModel.nodes.first(where: { $0.name == group.now }) {
            return node.delay
        }
        return 0
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
        // 计算卡片尺寸（只在初始化和宽度变化时计算）
        let dimensions = calculateCardDimensions(containerWidth: containerWidth)
        
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
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(width: dimensions.width, height: dimensions.height)
        .background(
            ZStack {
                // 基本背景
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackgroundColor)
                
                // 边框高亮 (使用固定颜色，与延迟无关)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.secondary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                        lineWidth: 0.5
                    )
                
                // 顶部光泽效果 (简化，只在暗模式下显示)
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.07), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            }
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.05),
            radius: 3,
            x: 0,
            y: 1
        )
        .onAppear {
            // 在视图出现时更新卡片尺寸缓存
            self.cardSize = calculateCardDimensions(containerWidth: containerWidth)
        }
        .onChange(of: containerWidth) { newWidth in
            // 当容器宽度变化时更新卡片尺寸缓存
            self.cardSize = calculateCardDimensions(containerWidth: newWidth)
        }
    }
    
    // 优化尺寸计算，减少不必要的计算
    private func calculateCardDimensions(containerWidth: CGFloat) -> (width: CGFloat, height: CGFloat) {
        let horizontalPadding: CGFloat = 24
        let spacing: CGFloat = 8
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let width = containerWidth - horizontalPadding
        let optimalColumnCount = max(2, Int(width / (minCardWidth + spacing)))
        let cardWidth = min(maxCardWidth, (width - (CGFloat(optimalColumnCount - 1) * spacing)) / CGFloat(optimalColumnCount))
        
        return (width: cardWidth, height: 90)
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
            Text("流量剩余")
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
        formatter.locale = Locale(identifier: "zh_CN")
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

// Zash 样式的代理提供者卡片 - 简化版本
struct ZashProviderCard: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    let containerWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @State private var isUpdating = false
    @State private var showingUpdateSuccess = false
    @State private var showingSheet = false
    @State private var cardSize: (width: CGFloat, height: CGFloat) = (width: 160, height: 90)
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    // 获取流量信息
    private var usageInfo: String? {
        let currentProvider = viewModel.providers.first { $0.name == provider.name } ?? provider
        guard let info = currentProvider.subscriptionInfo,
              info.total > 0 || info.upload > 0 || info.download > 0 else { return nil }
        let remaining = max(0, info.total - info.upload - info.download)
        let remainingFormatted = formatBytes(Int64(remaining))
        let totalFormatted = formatBytes(info.total)
        return "\(remainingFormatted) / \(totalFormatted)"
    }
    
    // 获取剩余流量百分比
    private var remainingPercentage: Double {
        let currentProvider = viewModel.providers.first { $0.name == provider.name } ?? provider
        guard let info = currentProvider.subscriptionInfo,
              info.total > 0 else { return 1.0 }
        return max(0, min(1.0, 1.0 - Double(info.upload + info.download) / Double(info.total)))
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
        // 计算卡片尺寸
        let dimensions = calculateCardDimensions(containerWidth: containerWidth)
        
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(usage)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            
                            // 添加流量进度条
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // 背景
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 4)
                                    
                                    // 进度 - 剩余流量
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * remainingPercentage, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("无流量信息")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    // 更新时间
                    if let updatedAt = provider.updatedAt,
                       let updateDate = parseDate(updatedAt) {
                        Text(formatRelativeTime(updateDate) + "更新")
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
            .frame(width: dimensions.width, height: dimensions.height)
            .background(
                ZStack {
                    // 基本背景
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackgroundColor)
                    
                    // 边框 (简化)
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4).opacity(colorScheme == .dark ? 0.2 : 0.3), lineWidth: 0.5)
                    
                    // 顶部光泽效果 (简化，只在暗模式下显示)
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.07), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                }
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.05),
                radius: 3,
                x: 0,
                y: 1
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
                                    color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.1),
                                    radius: 2,
                                    x: 0,
                                    y: 1
                                )
                        )
                    }
                    .disabled(isUpdating)
                    .padding(.trailing, 12)
                    .padding(.top, 12)
                    .zIndex(1)
                    .background(
                        Color.clear
                            .contentShape(Circle())
                            .frame(width: 44, height: 44)
                    )
                }
                Spacer()
            }
            .frame(width: dimensions.width, height: dimensions.height)
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
        .onAppear {
            // 在视图出现时更新卡片尺寸缓存
            self.cardSize = calculateCardDimensions(containerWidth: containerWidth)
        }
        .onChange(of: containerWidth) { newWidth in
            // 当容器宽度变化时更新卡片尺寸缓存
            self.cardSize = calculateCardDimensions(containerWidth: newWidth)
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
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // 优化尺寸计算，减少不必要的计算
    private func calculateCardDimensions(containerWidth: CGFloat) -> (width: CGFloat, height: CGFloat) {
        let horizontalPadding: CGFloat = 24
        let spacing: CGFloat = 8
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let width = containerWidth - horizontalPadding
        let optimalColumnCount = max(2, Int(width / (minCardWidth + spacing)))
        let cardWidth = min(maxCardWidth, (width - (CGFloat(optimalColumnCount - 1) * spacing)) / CGFloat(optimalColumnCount))
        
        return (width: cardWidth, height: 90)
    }
}

// 添加 Zash 风格的节点卡片 - 简化版本
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
            .background(
                ZStack {
                    // 基本背景
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackgroundColor)
                    
                    // 选中状态边框
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 2)
                    }
                    
                    // 顶部光泽效果 (简化，只在暗模式下显示)
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.07), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                }
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.05),
                radius: 3,
                x: 0,
                y: 1
            )
            // 根据延迟状态添加微小的边框高亮 - 改为与延迟无关的固定颜色
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.blue : Color.secondary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// 添加 Zash 风格的延迟测试动画 - 简化版本
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
    @State private var isLoaded = false
    
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
            .opacity(isLoaded ? 1.0 : 0.3)
            .animation(.easeIn(duration: 0.3), value: isLoaded)
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
        .onAppear {
            // 延迟显示内容，减轻初始化负担
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    isLoaded = true
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
                        Text("流量剩余")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                        
                        Spacer()
                        
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
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Zash 风格的节点网格 - 优化版本
struct ZashNodesGrid: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var cachedColumns: [GridItem] = []
    @State private var lastScreenWidth: CGFloat = 0
    
    var body: some View {
        if nodes.isEmpty {
            Text("没有找到节点")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else {
            LazyVGrid(columns: getColumns(), spacing: 12) {
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
        }
    }
    
    private func getColumns() -> [GridItem] {
        let screenWidth = UIScreen.main.bounds.width
        
        // 如果屏幕宽度没有变化，使用缓存的结果
        if abs(screenWidth - lastScreenWidth) < 1 && !cachedColumns.isEmpty {
            return cachedColumns
        }
        
        let spacing: CGFloat = 12
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let columnsCount = max(2, Int(screenWidth / (minCardWidth + spacing * 2)))
        let newColumns = Array(repeating: GridItem(.flexible(minimum: minCardWidth, maximum: maxCardWidth), spacing: spacing), count: columnsCount)
        
        // 避免在视图更新过程中直接修改状态
        DispatchQueue.main.async {
            self.lastScreenWidth = screenWidth
            self.cachedColumns = newColumns
        }
        
        return newColumns
    }
}

// 添加 Zash 风格的代理组详情视图 - 优化版本
struct ZashGroupDetailView: View {
    let group: ProxyGroup
    @ObservedObject var viewModel: ProxyViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @AppStorage("allowManualURLTestGroupSwitch") private var allowManualURLTestGroupSwitch = false
    @State private var showURLTestAlert = false
    @State private var cachedColumns: [GridItem] = []
    @State private var lastScreenWidth: CGFloat = 0
    @State private var isInitialAppear = true
    @State private var isLoaded = false
    @State private var delayStats: (green: Int, yellow: Int, orange: Int, gray: Int) = (0, 0, 0, 0)
    
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
                searchBarView
                
                // 节点统计信息
                statsView
                
                // 节点列表
                if filteredNodes.isEmpty {
                    Text("没有找到节点")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    // 使用懒加载方式优化列表渲染
                    nodeListView
                }
            }
            .padding(.vertical)
            // 仅在视图完全加载后显示
            .opacity(isLoaded ? 1 : 0)
            .animation(.easeIn(duration: 0.3), value: isLoaded)
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
        .onAppear {
            // 初始显示时，计算延迟统计并缓存列
            calculateDelayStats()
            // 延迟加载以优化性能
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isLoaded = true
            }
        }
    }
    
    // 搜索栏视图
    private var searchBarView: some View {
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
    }
    
    // 统计信息视图
    private var statsView: some View {
        HStack {
            Text("共 \(group.all.count) 个节点")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // 延迟统计 - 使用缓存的统计数据
            HStack(spacing: 8) {
                DelayStatBadge(count: delayStats.green, color: .green, label: "低延迟")
                DelayStatBadge(count: delayStats.yellow, color: .yellow, label: "中延迟")
                DelayStatBadge(count: delayStats.orange, color: .orange, label: "高延迟")
                DelayStatBadge(count: delayStats.gray, color: .gray, label: "超时")
            }
        }
        .padding(.horizontal)
    }
    
    // 节点列表视图 - 使用优化的列表渲染
    private var nodeListView: some View {
        LazyVGrid(columns: getColumns(), spacing: 12) {
            ForEach(filteredNodes.indices, id: \.self) { index in
                let nodeName = filteredNodes[index]
                let isNodeSelected = viewModel.groups.first(where: { $0.name == group.name })?.now == nodeName
                let isNodeTesting = viewModel.testingNodes.contains(nodeName)
                // 使用ID优化ForEach
                ZashNodeCardOptimized(
                    nodeName: nodeName,
                    node: viewModel.nodes.first { $0.name == nodeName },
                    isSelected: isNodeSelected,
                    isTesting: isNodeTesting,
                    viewModel: viewModel,
                    onTap: {
                        handleNodeTap(nodeName: nodeName)
                    }
                )
                .id("\(nodeName)-\(isNodeSelected)-\(isNodeTesting)")
            }
        }
        .padding(.horizontal)
    }
    
    // 处理节点点击
    private func handleNodeTap(nodeName: String) {
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
    
    // 优化列计算以使用缓存
    private func getColumns() -> [GridItem] {
        let screenWidth = UIScreen.main.bounds.width
        
        // 如果屏幕宽度没有变化，使用缓存的结果
        if abs(screenWidth - lastScreenWidth) < 1 && !cachedColumns.isEmpty {
            return cachedColumns
        }
        
        let spacing: CGFloat = 12
        let minCardWidth: CGFloat = 160
        let maxCardWidth: CGFloat = 200
        
        let columnsCount = max(2, Int(screenWidth / (minCardWidth + spacing * 2)))
        let newColumns = Array(repeating: GridItem(.flexible(minimum: minCardWidth, maximum: maxCardWidth), spacing: spacing), count: columnsCount)
        
        // 避免在视图更新过程中直接修改状态
        DispatchQueue.main.async {
            self.lastScreenWidth = screenWidth
            self.cachedColumns = newColumns
        }
        
        return newColumns
    }
    
    // 计算延迟统计并缓存结果
    private func calculateDelayStats() {
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
        
        self.delayStats = (green, yellow, orange, gray)
    }
}

// 优化版节点卡片 - 减少不必要的重绘
struct ZashNodeCardOptimized: View {
    let nodeName: String
    let node: ProxyNode?
    let isSelected: Bool
    let isTesting: Bool
    let viewModel: ProxyViewModel
    let onTap: () -> Void
    
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
        Button(action: onTap) {
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
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.blue : Color.secondary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.05),
                radius: 3,
                x: 0,
                y: 1
            )
        }
        .buttonStyle(PlainButtonStyle()) // 使用PlainButtonStyle避免按钮动画
    }
}

#Preview {
    ZashProxyView(server: ClashServer(name: "测试服务器", url: "192.168.1.1", port: "9090", secret: "123456"))
} 
