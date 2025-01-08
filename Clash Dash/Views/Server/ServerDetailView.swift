import SwiftUI
import Charts


struct ServerDetailView: View {
    let server: ClashServer
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ServerDetailViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var showingModeChangeSuccess = false
    @State private var lastChangedMode = ""
    @State private var showingConfigSubscription = false
    @State private var showingSwitchConfig = false
    @State private var showingCustomRules = false
    @State private var showingRestartService = false
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // 概览标签页
                OverviewTab(server: server)
                    .onAppear {
                        // 添加触觉反馈
                        impactFeedback.impactOccurred()
                    }
                    .tabItem {
                        Label("概览", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(0)
                
                // 代理标签页
                ProxyView(server: server)
                    .onAppear {
                        // 添加触觉反馈
                        impactFeedback.impactOccurred()
                    }
                    .tabItem {
                        Label("代理", systemImage: "globe")
                    }
                    .tag(1)
                
                // 规则标签页
                RulesView(server: server)
                    .onAppear {
                        // 添加触觉反馈
                        impactFeedback.impactOccurred()
                    }
                    .tabItem {
                        Label("规则", systemImage: "ruler")
                    }
                    .tag(2)
                
                // 连接标签页
                ConnectionsView(server: server)
                    .onAppear {
                        // 添加触觉反馈
                        impactFeedback.impactOccurred()
                    }
                    .tabItem {
                        Label("连接", systemImage: "link")
                    }
                    .tag(3)
                
                // 更多标签页
                MoreView(server: server)
                    .onAppear {
                        // 添加触觉反馈
                        impactFeedback.impactOccurred()
                    }
                    .tabItem {
                        Label("More", systemImage: "ellipsis")
                    }
                    .tag(4)
            }
            .navigationTitle(server.name.isEmpty ? "\(server.openWRTUrl ?? server.url):\(server.openWRTPort ?? server.port)" : server.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if server.isQuickLaunch {
                    ToolbarItem(placement: .principal) {
                        HStack {
                            Spacer()
                                .frame(width: 25) // 调整图标与标题的间距，使得标题永远居中
                            Text(server.name.isEmpty ? "\(server.openWRTUrl ?? server.url):\(server.openWRTPort ?? server.port)" : server.name)
                                .font(.headline)
                            Image(systemName: "bolt.circle.fill")
                                .foregroundColor(.yellow)
                                .font(.subheadline)
                        }
                    }
                } else {
                    ToolbarItem(placement: .principal) {
                        Text(server.name.isEmpty ? "\(server.openWRTUrl ?? server.url):\(server.openWRTPort ?? server.port)" : server.name)
                            .font(.headline)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .onAppear {
                networkMonitor.startMonitoring(server: server)
            }
            .onDisappear {
                networkMonitor.stopMonitoring()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(server.name ?? server.url)
            .sheet(isPresented: $showingConfigSubscription) {
                ConfigSubscriptionView(server: server)
            }
            .sheet(isPresented: $showingSwitchConfig) {
                OpenClashConfigView(viewModel: viewModel.serverViewModel, server: server)
            }
            .sheet(isPresented: $showingCustomRules) {
                OpenClashRulesView(server: server)
            }
            .sheet(isPresented: $showingRestartService) {
                RestartServiceView(viewModel: viewModel.serverViewModel, server: server)
            }
        }
    }
    
    private func showModeChangeSuccess(mode: String) {
        lastChangedMode = mode
        withAnimation {
            showingModeChangeSuccess = true
        }
        // 2 秒后隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingModeChangeSuccess = false
            }
        }
    }
}

// 更新速率图表组件
struct SpeedChartView: View {
    let speedHistory: [SpeedRecord]
    
    private var maxValue: Double {
        // 获取当前数据中的最大值
        let maxUpload = speedHistory.map { $0.upload }.max() ?? 0
        let maxDownload = speedHistory.map { $0.download }.max() ?? 0
        let currentMax = max(maxUpload, maxDownload)
        
        // 如果没有数据或数据小，使用最小刻度
        if currentMax < 100_000 { // 小于 100KB/s
            return 100_000 // 100KB/s
        }
        
        // 计算合适的刻度值
        let magnitude = pow(10, floor(log10(currentMax)))
        let normalized = currentMax / magnitude
        
        // 选择合适的刻度倍数：1, 2, 5, 10
        let scale: Double
        if normalized <= 1 {
            scale = 1
        } else if normalized <= 2 {
            scale = 2
        } else if normalized <= 5 {
            scale = 5
        } else {
            scale = 10
        }
        
        // 计算最终的最大值，并留出一些余量（120%）
        return magnitude * scale * 1.2
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        if speed >= 1_000_000 {
            return String(format: "%.1f MB/s", speed / 1_000_000)
        } else if speed >= 1_000 {
            return String(format: "%.1f KB/s", speed / 1_000)
        } else {
            return String(format: "%.0f B/s", speed)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("速率图表")
                    .font(.headline)
            }
            
            Chart {
                // 添加预设的网格线和标签
                ForEach(Array(stride(from: 0, to: maxValue, by: maxValue/4)), id: \.self) { value in
                    RuleMark(
                        y: .value("Speed", value)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.gray.opacity(0.1))
                }
                
                // 上传数据
                ForEach(speedHistory) { record in
                    LineMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Speed", record.upload),
                        series: .value("Type", "上传")
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                
                ForEach(speedHistory) { record in
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        yStart: .value("Speed", 0),
                        yEnd: .value("Speed", record.upload),
                        series: .value("Type", "上传")
                    )
                    .foregroundStyle(.green.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
                
                // 下载数据
                ForEach(speedHistory) { record in
                    LineMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Speed", record.download),
                        series: .value("Type", "下载")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                
                ForEach(speedHistory) { record in
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        yStart: .value("Speed", 0),
                        yEnd: .value("Speed", record.download),
                        series: .value("Type", "下载")
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(preset: .extended, position: .leading) { value in
                    if let speed = value.as(Double.self) {
                        AxisGridLine()
                        AxisValueLabel(horizontalSpacing: 0) {
                            Text(formatSpeed(speed))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...maxValue)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            
            // 图例
            HStack {
                Label("下载", systemImage: "circle.fill")
                    .foregroundColor(.blue)
                Label("上传", systemImage: "circle.fill")
                    .foregroundColor(.green)
            }
            .font(.caption)
        }
    }
}

// 2. 更新 OverviewTab
struct OverviewTab: View {
    let server: ClashServer
    @StateObject private var monitor = NetworkMonitor()
    @StateObject private var settings = OverviewCardSettings()
    @Environment(\.colorScheme) var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? 
            Color(.systemGray6) : 
            Color(.systemBackground)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Color.clear
                    .frame(height: 8)
                
                ForEach(settings.cardOrder) { card in
                    if settings.cardVisibility[card] ?? true {
                        switch card {
                        case .speed:
                            // 速度卡片
                            HStack(spacing: 16) {
                                StatusCard(
                                    title: "下载",
                                    value: monitor.downloadSpeed,
                                    icon: "arrow.down.circle",
                                    color: .blue
                                )
                                StatusCard(
                                    title: "上传",
                                    value: monitor.uploadSpeed,
                                    icon: "arrow.up.circle",
                                    color: .green
                                )
                            }
                            
                        case .totalTraffic:
                            // 总流量卡片
                            HStack(spacing: 16) {
                                StatusCard(
                                    title: "下载总量",
                                    value: monitor.totalDownload,
                                    icon: "arrow.down.circle.fill",
                                    color: .blue
                                )
                                StatusCard(
                                    title: "上传总量",
                                    value: monitor.totalUpload,
                                    icon: "arrow.up.circle.fill",
                                    color: .green
                                )
                            }
                            
                        case .status:
                            // 状态卡片
                            HStack(spacing: 16) {
                                StatusCard(
                                    title: "活动连接",
                                    value: "\(monitor.activeConnections)",
                                    icon: "link.circle.fill",
                                    color: .orange
                                )
                                StatusCard(
                                    title: "内存使用",
                                    value: monitor.memoryUsage,
                                    icon: "memorychip",
                                    color: .purple
                                )
                            }
                            
                        case .speedChart:
                            // 速率图表
                            SpeedChartView(speedHistory: monitor.speedHistory)
                                .padding()
                                .background(cardBackgroundColor)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            
                        case .memoryChart:
                            // 只在 Meta 服务器上显示内存图表
                            if server.serverType != .premium {
                                ChartCard(title: "内存使用", icon: "memorychip") {
                                    Chart(monitor.memoryHistory) { record in
                                        AreaMark(
                                            x: .value("Time", record.timestamp),
                                            y: .value("Memory", record.usage)
                                        )
                                        .foregroundStyle(.purple.opacity(0.3))
                                        
                                        LineMark(
                                            x: .value("Time", record.timestamp),
                                            y: .value("Memory", record.usage)
                                        )
                                        .foregroundStyle(.purple)
                                    }
                                    .frame(height: 200)
                                    .chartYAxis {
                                        AxisMarks(position: .leading) { value in
                                            if let memory = value.as(Double.self) {
                                                AxisGridLine()
                                                AxisValueLabel {
                                                    Text("\(Int(memory)) MB")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .automatic(desiredCount: 3))
                                    }
                                }
                            }
                            
                        case .modeSwitch:
                            ModeSwitchCard(server: server)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { monitor.startMonitoring(server: server) }
        .onDisappear { monitor.stopMonitoring() }
    }
}

// 添加 UIVisualEffectView 包装器
struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

// 状态卡片组件
struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? 
            Color(.systemGray6) : 
            Color(.systemBackground)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .bold()
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// 图表卡片组件
struct ChartCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    @Environment(\.colorScheme) var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? 
            Color(.systemGray6) : 
            Color(.systemBackground)
    }
    
    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// 辅助视图组件
struct ProxyGroupRow: View {
    @State private var selectedProxy = "Auto"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("代理组名称")
                .font(.headline)
            
            Picker("选择理", selection: $selectedProxy) {
                Text("Auto").tag("Auto")
                Text("香港 01").tag("HK01")
                Text("新加坡 01").tag("SG01")
                Text("日本 01").tag("JP01")
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, 4)
    }
}

// struct LogRow: View {
//     let type: String
//     let message: String
    
//     var typeColor: Color {
//         switch type {
//         case "INFO": return .primary
//         case "WARNING": return .orange
//         case "ERROR": return .red
//         case "DEBUG": return .secondary
//         default: return .primary
//         }
//     }
    
//     var body: some View {
//         VStack(alignment: .leading, spacing: 4) {
//             Text(type)
//                 .font(.caption)
//                 .foregroundColor(typeColor)
//             Text(message)
//                 .font(.system(.body, design: .monospaced))
//         }
//         .padding(.vertical, 2)
//     }
// }

#Preview {
    NavigationStack {
        ServerDetailView(server: ClashServer(name: "测试服务器", url: "10.1.1.2", port: "9090", secret: "123456"))
    }
} 
