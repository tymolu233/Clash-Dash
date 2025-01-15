import SwiftUI
import Charts
import Darwin


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
    @EnvironmentObject private var bindingManager: WiFiBindingManager
    @StateObject private var subscriptionManager: SubscriptionManager
    
    // 添加触觉反馈生成器
    
    
    init(server: ClashServer) {
        self.server = server
        self._subscriptionManager = StateObject(wrappedValue: SubscriptionManager(server: server))
        
        // 设置 UITabBar 的外观
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().standardAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 概览标签页
            OverviewTab(server: server, monitor: networkMonitor)
                .onAppear {
                    HapticManager.shared.impact(.light)
                }
                .tabItem {
                    Label("概览", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(0)
            
            // 代理标签页
            ProxyView(server: server)
                .onAppear {
                    HapticManager.shared.impact(.light)
                }
                .tabItem {
                    Label("代理", systemImage: "globe")
                }
                .tag(1)
            
            // 规则标签页
            RulesView(server: server)
                .onAppear {
                    HapticManager.shared.impact(.light)
                }
                .tabItem {
                    Label("规则", systemImage: "ruler")
                }
                .tag(2)
            
            // 连接标签页
            ConnectionsView(server: server)
                .onAppear {
                    HapticManager.shared.impact(.light)
                }
                .tabItem {
                    Label("连接", systemImage: "link")
                }
                .tag(3)
            
            // 更多标签页
            MoreView(server: server)
                .onAppear {
                    HapticManager.shared.impact(.light)
                }
                .tabItem {
                    Label("更多", systemImage: "ellipsis")
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
                            .frame(width: 25)
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
            viewModel.serverViewModel.setBingingManager(bindingManager)
            // 如果当前是概览标签页，启动监控
            if selectedTab == 0 {
                networkMonitor.startMonitoring(server: server)
            }
        }
        .onDisappear {
            networkMonitor.stopMonitoring()
        }
        .onChange(of: selectedTab) { newTab in
            // 当标签页切换时，根据是否是概览标签页来启动或停止监控
            if newTab == 0 {
                networkMonitor.startMonitoring(server: server)
            } else {
                networkMonitor.stopMonitoring()
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

// 添加订阅信息模型
// struct SubscriptionCardInfo: Identifiable {
//     let id = UUID()
//     let name: String?
//     let expiryDate: Date?
//     let lastUpdateTime: Date
//     let usedTraffic: Double
//     let totalTraffic: Double
// }

// 订阅信息卡片组件


// 2. 更新 OverviewTab
struct OverviewTab: View {
    let server: ClashServer
    @ObservedObject var monitor: NetworkMonitor
    @StateObject private var settings = OverviewCardSettings()
    @StateObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) var colorScheme
    
    init(server: ClashServer, monitor: NetworkMonitor) {
        self.server = server
        self.monitor = monitor
        self._subscriptionManager = StateObject(wrappedValue: SubscriptionManager(server: server))
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? 
            Color(.systemGray6) : 
            Color(.systemBackground)
    }
    
    private func maxMemoryValue(_ memoryHistory: [MemoryRecord]) -> Double {
        // 获取当前数据中的最大值
        let maxMemory = memoryHistory.map { $0.usage }.max() ?? 0
        
        // 如果没有数据或数据小，使用最小刻度
        if maxMemory < 50 { // 小于 50MB
            return 50 // 50MB
        }
        
        // 计算合适的刻度值
        let magnitude = pow(10, floor(log10(maxMemory)))
        let normalized = maxMemory / magnitude
        
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
                            if settings.cardVisibility[.speed] ?? true {
                                HStack(spacing: 16) {
                                    StatusCard(
                                        title: "下载",
                                        value: monitor.downloadSpeed,
                                        icon: "arrow.down.circle",
                                        color: .blue,
                                        monitor: monitor
                                    )
                                    StatusCard(
                                        title: "上传",
                                        value: monitor.uploadSpeed,
                                        icon: "arrow.up.circle",
                                        color: .green,
                                        monitor: monitor
                                    )
                                }
                            }
                            
                        case .totalTraffic:
                            // 总流量卡片
                            HStack(spacing: 16) {
                                StatusCard(
                                    title: "下载总量",
                                    value: monitor.totalDownload,
                                    icon: "arrow.down.circle.fill",
                                    color: .blue,
                                    monitor: monitor
                                )
                                StatusCard(
                                    title: "上传总量",
                                    value: monitor.totalUpload,
                                    icon: "arrow.up.circle.fill",
                                    color: .green,
                                    monitor: monitor
                                )
                            }
                            
                        case .status:
                            // 状态卡片
                            HStack(spacing: 16) {
                                StatusCard(
                                    title: "活动连接",
                                    value: "\(monitor.activeConnections)",
                                    icon: "link.circle.fill",
                                    color: .orange,
                                    monitor: monitor
                                )
                                StatusCard(
                                    title: "内存使用",
                                    value: monitor.memoryUsage,
                                    icon: "memorychip",
                                    color: .purple,
                                    monitor: monitor
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
                                    Chart {
                                        // 添加预设的网格线和标签
                                        ForEach(Array(stride(from: 0, to: maxMemoryValue(monitor.memoryHistory), by: maxMemoryValue(monitor.memoryHistory)/4)), id: \.self) { value in
                                            RuleMark(
                                                y: .value("Memory", value)
                                            )
                                            .lineStyle(StrokeStyle(lineWidth: 1))
                                            .foregroundStyle(.gray.opacity(0.1))
                                        }
                                        
                                        ForEach(monitor.memoryHistory) { record in
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
                                    .chartYScale(domain: 0...maxMemoryValue(monitor.memoryHistory))
                                    .chartXAxis {
                                        AxisMarks(values: .automatic(desiredCount: 3))
                                    }
                                }
                            }
                            
                        case .modeSwitch:
                            ModeSwitchCard(server: server)
                            
                        case .subscription:
                            if !subscriptionManager.subscriptions.isEmpty {
                                let subscriptions = subscriptionManager.subscriptions
                                let lastUpdateTime = subscriptionManager.lastUpdateTime
                                let isLoading = subscriptionManager.isLoading
                                
                                SubscriptionInfoCard(
                                    subscriptions: subscriptions,
                                    lastUpdateTime: lastUpdateTime,
                                    isLoading: isLoading
                                ) {
                                    await subscriptionManager.refresh()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            monitor.resetData() // 重置监控数据
            Task {
                await subscriptionManager.fetchSubscriptionInfo() // 获取订阅信息
            }
        }
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

// 波浪背景组件
struct WaveBackground: View {
    let color: Color
    let speed: Double
    @ObservedObject var monitor: NetworkMonitor
    let isDownload: Bool
    @State private var phase: CGFloat = 0
    @State private var displayLink: Timer?
    @State private var currentSpeed: CGFloat = 0.01 // 当前实际移动速度
    private let waveWidth: CGFloat = 4 * .pi
    private let fixedAmplitude: CGFloat = 0.2 // 固定的波浪振幅
    private let accelerationFactor: CGFloat = 0.01 // 加速因子
    private let decelerationFactor: CGFloat = 0.01    // 减速因子
    
    var body: some View {
        Canvas { context, size in
            let baseHeight = size.height * 0.7
            
            // 绘制波浪
            var path = Path()
            path.move(to: CGPoint(x: size.width, y: size.height))
            
            let points = 200
            for i in 0...points {
                let x = size.width - (CGFloat(i) / CGFloat(points)) * size.width
                
                // 计算波形，使用固定振幅
                let normalizedX = (CGFloat(i) / CGFloat(points)) * waveWidth
                let wavePhase = normalizedX - phase
                let baseWave = Darwin.sin(wavePhase)
                let waveHeight = baseWave * size.height * 0.4 * fixedAmplitude
                
                let y = baseHeight + waveHeight
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
            
            context.fill(path, with: .color(color.opacity(0.3)))
        }
        .onAppear {
            // 创建动画定时器
            displayLink = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
                // 计算目标速度
                let targetSpeed = calculateTargetSpeed()
                
                // 平滑加速或减速
                if currentSpeed < targetSpeed {
                    // 加速
                    currentSpeed += (targetSpeed - currentSpeed) * accelerationFactor
                } else if currentSpeed > targetSpeed {
                    // 减速
                    currentSpeed -= (currentSpeed - targetSpeed) * decelerationFactor
                }
                
                // 更新相位
                phase += currentSpeed
                if phase >= waveWidth {
                    phase = 0
                }
            }
        }
        .onDisappear {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
    
    private func calculateTargetSpeed() -> CGFloat {
        let currentSpeed = isDownload ? monitor.downloadSpeed : monitor.uploadSpeed
        let components = currentSpeed.split(separator: " ")
        guard components.count == 2,
              let value = Double(components[0]) else {
            return 0.01
        }
        
        let bytesPerSecond: Double
        switch components[1] {
        case "MB/s":
            bytesPerSecond = value * 1_000_000
        case "KB/s":
            bytesPerSecond = value * 1_000
        case "B/s":
            bytesPerSecond = value
        default:
            bytesPerSecond = 0
        }
        
        let baseSpeed = 2_000_000.0 // 2MB/s作为基准速度
        let speedRatio = bytesPerSecond / baseSpeed
        
        // 使用线性映射来控制移动速度
        let minSpeed: CGFloat = 0.01
        let maxSpeed: CGFloat = 0.1
        
        // 使用对数函数使速度变化更加平滑
        let normalizedSpeed = CGFloat(log(speedRatio + 1) / log(2))
        return minSpeed + (maxSpeed - minSpeed) * min(normalizedSpeed, 1.0)
    }
}

// 水滴效果组件
struct WaterDrop: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    var speed: Double
    var scale: CGFloat
    var isGrowing: Bool
    var widthParameter: CGFloat  // a parameter
    var heightParameter: CGFloat // b parameter
    var accumulatedData: Int  // 累积的数据量
    var shouldFall: Bool  // 是否应该下落
    var acceleration: Double = 0  // 添加加速度属性
}

struct TeardropShape: Shape {
    let widthParameter: CGFloat  // a parameter
    let heightParameter: CGFloat // b parameter
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let centerX = rect.midX
        let centerY = rect.midY
        
        // 使用 1000 个点来绘制曲线
        let points = 1000
        let scale = min(width, height) / 5.2  // 缩放因子，基于 y 轴范围 (-5.2, 0.2)
        
        // 计算第一个点
        let firstT = 0.0
        let firstX = widthParameter * (1 - sin(firstT)) * cos(firstT)
        let firstY = heightParameter * (sin(firstT) - 1)
        let scaledFirstX = centerX + firstX * scale
        let scaledFirstY = centerY - firstY * scale  // 翻转 Y 坐标
        
        path.move(to: CGPoint(x: scaledFirstX, y: scaledFirstY))
        
        // 使用参数方程绘制曲线
        for i in 1...points {
            let t = Double(i) * 2 * .pi / Double(points)
            
            // Piriform of Longchamps 方程
            let x = widthParameter * (1 - sin(t)) * cos(t)
            let y = heightParameter * (sin(t) - 1)
            
            // 缩放和平移坐标以适应视图，注意 y 坐标取反
            let scaledX = centerX + x * scale
            let scaledY = centerY - y * scale  // 翻转 Y 坐标
            
            path.addLine(to: CGPoint(x: scaledX, y: scaledY))
        }
        
        path.closeSubpath()
        return path
    }
}

struct WaterSplash: Identifiable {
    let id = UUID()
    var position: CGPoint
    var width: CGFloat
    var height: CGFloat
    var opacity: Double
    var createdAt: Date
    var delayStart: Date  // 添加延迟开始时间
}

struct WaterDropEffect: View {
    let color: Color
    @ObservedObject var monitor: NetworkMonitor
    let isUpload: Bool  // 是否是上传总量
    @State private var drops: [WaterDrop] = []
    @State private var timer: Timer?
    @State private var lastValue: Int = 0  // 使用原始数据
    @State private var timeWindowStart: Date = Date()  // 时间窗口开始时间
    @State private var currentDifference: Int = 0  // 当前时间窗口内的累积差值
    @State private var dropGenerationProgress: CGFloat = 0  // 水滴生成进度
    @State private var splashes: [WaterSplash] = []
    private let splashDuration: TimeInterval = 0.8  // 水花效果持续时间
    
    private let timeWindowDuration: TimeInterval = 2.0  // 2秒时间窗口
    private let dropGenerationDuration: TimeInterval = 2.0  // 水滴生成时间
    private let minDropSize: CGFloat = 2  // 最小水滴大小
    private let maxDropSize: CGFloat = 20  // 最大水滴大小
    private let maxDataThreshold: Int = 10 * 1024 * 1024  // 10MB 阈值
    private let animationInterval: TimeInterval = 0.005  // 动画更新间隔
    private let scaleStepFactor: CGFloat = 0.02  // 缩放变化步长
    private let sizeStepFactor: CGFloat = 0.03  // 大小变化步长
    
    private func calculateDropParameters(accumulatedData: Int) -> (CGFloat, CGFloat, CGFloat) {
        // 修改进度计算方式，使其更容易达到最大值
        let cappedData = min(accumulatedData, 10 * 1024 * 1024)  // 限制在10MB
        let mbAccumulated = Double(cappedData) / Double(1024 * 1024)
        var progress: CGFloat
        if mbAccumulated >= 10 {
            progress = 1.0  // 达到10MB时直接使用最大值
        } else {
            // 使用更直接的比例计算，让大小增长更明显
            let baseProgress = CGFloat(mbAccumulated / 10.0)  // 线性增长
            // 使用 pow 函数让初期增长更快
            progress = CGFloat(pow(Double(baseProgress), 0.5))
        }
        
        let size = minDropSize + (maxDropSize - minDropSize) * progress
        
        // 形状参数使用固定的最小和最大值
        let minWidthParameter: CGFloat = 1.0
        let maxWidthParameter: CGFloat = 1.5
        let minHeightParameter: CGFloat = 2.5
        let maxHeightParameter: CGFloat = 3.5
        
        // 根据进度计算形状参数
        let widthParameter = minWidthParameter + (maxWidthParameter - minWidthParameter) * progress
        let heightParameter = minHeightParameter + (maxHeightParameter - minHeightParameter) * progress
        
        return (size, widthParameter, heightParameter)
    }
    
    private func calculateFloatOffset(size: CGFloat, time: TimeInterval) -> CGFloat {
        // 修改浮动幅度计算，使其更线性
        let progress = (size - minDropSize) / (maxDropSize - minDropSize)
        let maxFloat: CGFloat = 6.0  // 进一步增大最大浮动幅度
        let amplitude = maxFloat * progress
        return sin(time * 1.5) * amplitude
    }
    
    private func createDrop(withInitialData data: Int = 0) -> WaterDrop {
        let randomX = CGFloat.random(in: 10...90)
        let (targetSize, targetWidth, targetHeight) = calculateDropParameters(accumulatedData: data)
        
        // 如果初始数据量大，直接创建对应大小的水滴
        let initialSize = data >= maxDataThreshold ? targetSize : minDropSize
        let initialWidth = data >= maxDataThreshold ? targetWidth : 1.0
        let initialHeight = data >= maxDataThreshold ? targetHeight : 2.5
        
        return WaterDrop(
            position: CGPoint(x: randomX, y: 0),
            size: initialSize,
            opacity: 0.8,
            speed: Double.random(in: 80...160),
            scale: 1.0,
            isGrowing: data < maxDataThreshold,  // 只有小水滴需要生长
            widthParameter: initialWidth,
            heightParameter: initialHeight,
            accumulatedData: data,
            shouldFall: data >= maxDataThreshold,  // 大水滴直接开始下落
            acceleration: 0.5
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 水面效果
                ForEach(splashes) { splash in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: splash.width, height: splash.height)
                        .position(x: splash.position.x, y: splash.position.y)
                        .opacity(splash.opacity)
                }
                
                // 水滴连接线
                ForEach(drops) { drop in
                    if !drop.shouldFall && !drop.isGrowing {
                        Path { path in
                            let startY: CGFloat = 0
                            let endY = drop.position.y + drop.size * 0.3  // 直接连接到水滴的中心位置
                            path.move(to: CGPoint(x: drop.position.x, y: startY))
                            path.addLine(to: CGPoint(x: drop.position.x, y: endY))
                        }
                        .stroke(color.opacity(0.5), lineWidth: max(0.2, 1.5 * (1.0 - abs(drop.position.y) / 6.0)))  // 根据浮动位置动态调整线宽
                    }
                }
                
                // 水滴
                ForEach(drops) { drop in
                    TeardropShape(widthParameter: drop.widthParameter, heightParameter: drop.heightParameter)
                        .fill(color)
                        .frame(width: drop.size, height: drop.size * 1.3)
                        .scaleEffect(drop.scale)
                        .position(drop.position)
                        .opacity(drop.opacity)
                }
            }
            .onAppear {
                // 初始化时记录当前值，但不计入差值计算
                lastValue = isUpload ? monitor.rawTotalUpload : monitor.rawTotalDownload
                timeWindowStart = Date()
                currentDifference = 0  // 确保初始差值为0
                
                timer = Timer.scheduledTimer(withTimeInterval: animationInterval, repeats: true) { _ in
                    withAnimation(.linear(duration: animationInterval)) {
                        let currentValue = isUpload ? monitor.rawTotalUpload : monitor.rawTotalDownload
                        let difference = currentValue - lastValue
                        
                        if difference > 0 {
                            // 只有在非初始状态下才累积差值
                            if lastValue > 0 {
                                currentDifference += difference
                            }
                            
                            // 检查时间窗口
                            let now = Date()
                            let elapsedTime = now.timeIntervalSince(timeWindowStart)
                            
                            // 水滴生成和更新逻辑
                            if drops.isEmpty {
                                // 如果累积数据超过1MB，直接创建对应大小的水滴
                                if currentDifference >= 1024 * 1024 {
                                    let newDrop = createDrop(withInitialData: currentDifference)
                                    drops.append(newDrop)
                                    dropGenerationProgress = 0
                                } else {
                                    // 正常的水滴生成进度
                                    dropGenerationProgress = min(elapsedTime / dropGenerationDuration, 1.0)
                                    if dropGenerationProgress >= 1.0 {
                                        let newDrop = createDrop()
                                        drops.append(newDrop)
                                        dropGenerationProgress = 0
                                    }
                                }
                            }
                            
                            // 每个时间窗口结束时更新水滴
                            if elapsedTime >= timeWindowDuration {
                                if let lastIndex = drops.indices.last {
                                    // 更新现有水滴的累积数据
                                    let oldAccumulated = drops[lastIndex].accumulatedData
                                    let newAccumulated = oldAccumulated + currentDifference
                                    drops[lastIndex].accumulatedData = newAccumulated
                                    
                                    // 计算目标参数
                                    let (targetSize, targetWidth, targetHeight) = calculateDropParameters(accumulatedData: newAccumulated)
                                    
                                    // 平滑地更新参数
                                    let currentSize = drops[lastIndex].size
                                    let currentWidth = drops[lastIndex].widthParameter
                                    let currentHeight = drops[lastIndex].heightParameter
                                    
                                    drops[lastIndex].size = currentSize + (targetSize - currentSize) * sizeStepFactor
                                    drops[lastIndex].widthParameter = currentWidth + (targetWidth - currentWidth) * sizeStepFactor
                                    drops[lastIndex].heightParameter = currentHeight + (targetHeight - currentHeight) * sizeStepFactor
                                    
                                    // 只有累积到10MB并且不在生长状态时才开始下落
                                    if newAccumulated >= maxDataThreshold && !drops[lastIndex].isGrowing {
                                        drops[lastIndex].shouldFall = true
                                    }
                                }
                                
                                // 重置时间窗口和当前差值
                                timeWindowStart = now
                                currentDifference = 0
                            }
                        }
                        
                        // 更新现有水滴
                        for i in drops.indices {
                            var drop = drops[i]
                            
                            if drop.isGrowing {
                                // 计算目标大小
                                let (targetSize, targetWidth, targetHeight) = calculateDropParameters(accumulatedData: drop.accumulatedData)
                                
                                // 平滑地更新大小
                                let currentSize = drop.size
                                let sizeProgress = (currentSize - minDropSize) / (targetSize - minDropSize)
                                
                                // 使用 easeOut 效果使初始增长更快
                                let easedProgress = 1 - pow(1 - sizeProgress, 3)
                                
                                // 更新大小
                                drop.size = currentSize + (targetSize - currentSize) * sizeStepFactor
                                
                                // 同时更新形状参数
                                let shapeProgress = easedProgress
                                let targetWidthParam = 1.0 + shapeProgress * 0.5
                                let targetHeightParam = 2.5 + shapeProgress * 1.0
                                
                                drop.widthParameter = drop.widthParameter + (targetWidthParam - drop.widthParameter) * sizeStepFactor
                                drop.heightParameter = drop.heightParameter + (targetHeightParam - drop.heightParameter) * sizeStepFactor
                                
                                // 当接近目标大小时结束生长状态
                                if abs(drop.size - targetSize) < 0.1 {
                                    drop.isGrowing = false
                                }
                            } else if drop.shouldFall {
                                // 水滴下落阶段，设置统一的下落大小
                                // if drop.size != maxDropSize {
                                //     drop.size = maxDropSize  // 所有下落的水滴使用相同的大小
                                //     drop.widthParameter = 1.5  // 统一的形状参数
                                //     drop.heightParameter = 3.5
                                // }
                                
                                drop.speed += drop.acceleration  // 应用加速度
                                drop.position.y += drop.speed/120
                                
                                // 下落过程中的变形效果
                                let fallProgress = min(drop.position.y / (geometry.size.height * 0.7), 1.0)
                                let maxWidthIncrease: CGFloat = 0.02  // 最大宽度增加1%
                                let maxHeightDecrease: CGFloat = 0.02  // 最大高度减少1%
                                
                                // 使用 easeInOut 效果使变形更自然
                                let easedProgress = 1 - pow(1 - fallProgress, 2)
                                
                                // 应用变形
                                drop.widthParameter = 1.5 * (1 + maxWidthIncrease * easedProgress)
                                drop.heightParameter = 3.5 * (1 - maxHeightDecrease * easedProgress)
                                
                                // 接近底部时逐渐降低透明度和变形
                                if drop.position.y >= geometry.size.height - drop.size * 2 {
                                    let distanceToBottom: CGFloat = CGFloat(geometry.size.height) - drop.position.y
                                    let squashProgress = 1.0 - (distanceToBottom / (drop.size * 2))  // 0到1的进度
                                    
                                    // 逐渐增加宽度和减小高度
                                    drop.widthParameter = drop.widthParameter * (1 + squashProgress * 0.8)
                                    drop.heightParameter = drop.heightParameter * (1 - squashProgress * 0.9)
                                    
                                    // 同时降低透明度
                                    drop.opacity = Double(max(0, distanceToBottom / (drop.size * 3)))
                                    
                                    // 在这里创建和更新水面效果
                                    if splashes.isEmpty {
                                        let splash = WaterSplash(
                                            position: CGPoint(x: geometry.size.width/2, y: geometry.size.height),
                                            width: geometry.size.width,
                                            height: 0,
                                            opacity: 0.3,
                                            createdAt: Date(),
                                            delayStart: Date().addingTimeInterval(0.05)  // 添加0.05秒延迟
                                        )
                                        splashes.append(splash)
                                    }
                                }
                            } else {
                                // 水滴悬停，浮动幅度与大小相关
                                let floatOffset = calculateFloatOffset(size: drop.size, time: Date().timeIntervalSince1970)
                                drop.position.y = floatOffset
                            }
                            
                            // 检查是否碰到底部
                            if drop.position.y >= geometry.size.height {
                                drops.remove(at: i)
                                break
                            }
                            
                            drops[i] = drop
                        }
                        
                        // 清理超出范围的水滴
                        drops.removeAll { $0.position.y > geometry.size.height }
                        
                        // 更新水面效果
                        for i in splashes.indices {
                            let now = Date()
                            let timeSinceCreation = now.timeIntervalSince(splashes[i].createdAt)
                            
                            // 检查是否已经到达延迟开始时间
                            if now < splashes[i].delayStart {
                                continue  // 如果还没到延迟时间，保持初始状态
                            }
                            
                            let timeSinceDelay = now.timeIntervalSince(splashes[i].delayStart)
                            let progress = timeSinceDelay / splashDuration
                            
                            if progress >= 1.0 {
                                splashes.remove(at: i)
                                break
                            }
                            
                            // 水面高度和透明度动画
                            let normalizedProgress = progress * 2 * .pi
                            let dampingFactor = 1 - progress
                            
                            let oscillation = sin(normalizedProgress * 3) * dampingFactor
                            let baseHeight = 1 - pow(progress - 0.5, 2) * 4
                            
                            let finalHeight = max(0, baseHeight + oscillation * 0.3)
                            splashes[i].height = 8 * finalHeight
                            splashes[i].opacity = max(0, 1 - progress * 1.2)
                        }
                        
                        lastValue = currentValue
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }
}

// 状态卡片组件
struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var monitor: NetworkMonitor
    @AppStorage("showWaveEffect") private var showWaveEffect = true
    @AppStorage("showWaterDropEffect") private var showWaterDropEffect = true
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? 
            Color(.systemGray6) : 
            Color(.systemBackground)
    }
    
    private func extractSpeed() -> Double {
        let components = value.split(separator: " ")
        guard components.count == 2,
              let speed = Double(components[0]),
              let unit = components.last else {
            return 0
        }
        
        switch unit {
        case "MB/s":
            return speed * 1_000_000
        case "KB/s":
            return speed * 1_000
        case "B/s":
            return speed
        default:
            return 0
        }
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
        .background(
            ZStack {
                cardBackgroundColor
                if showWaveEffect && (title == "下载" || title == "上传") && !title.contains("总量") {
                    WaveBackground(
                        color: color,
                        speed: extractSpeed(),
                        monitor: monitor,
                        isDownload: title == "下载"
                    )
                }
                if showWaterDropEffect && title.contains("总量") {
                    WaterDropEffect(
                        color: color,
                        monitor: monitor,
                        isUpload: title.contains("上传")
                    )
                }
            }
        )
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
        ServerDetailView(server: ClashServer(name: "测试服务器", url: "10.1.1.166", port: "8099", secret: "123456"))
    }
} 
