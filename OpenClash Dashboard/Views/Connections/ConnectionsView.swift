import SwiftUI

struct ConnectionsView: View {
    let server: ClashServer
    @StateObject private var viewModel = ConnectionsViewModel()
    @StateObject private var tagViewModel = ClientTagViewModel()
    @State private var searchText = ""
    @State private var selectedProtocols: Set<String> = ["TCP", "UDP"]
    @State private var connectionFilter: ConnectionFilter = .active
    @State private var showMenu = false
    @State private var isDetectingLongPress = false
    @State private var showClientTagSheet = false
    
    // 添加定时器状态
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // 添加连接状态属性
    @State private var isConnecting = false
    
    // 添加枚举类型
    private enum ConnectionFilter {
        case active   // 正活跃
        case closed   // 已断开
        
        var title: String {
            switch self {
            case .active: return "正活跃"
            case .closed: return "已断开"
            }
        }
    }
    
    // 添加计算属性来获取不同类型的连接数量
    private var activeConnectionsCount: Int {
        viewModel.connections.filter { $0.isAlive }.count
    }
    
    private var closedConnectionsCount: Int {
        viewModel.connections.filter { !$0.isAlive }.count
    }
    
    private var tcpConnectionsCount: Int {
        viewModel.connections.filter { connection in
            let isMatchingState = connectionFilter == .active ? connection.isAlive : !connection.isAlive
            return isMatchingState && connection.metadata.network.uppercased() == "TCP"
        }.count
    }
    
    private var udpConnectionsCount: Int {
        viewModel.connections.filter { connection in
            let isMatchingState = connectionFilter == .active ? connection.isAlive : !connection.isAlive
            return isMatchingState && connection.metadata.network.uppercased() == "UDP"
        }.count
    }
    
    private var filteredConnections: [ClashConnection] {
        viewModel.connections.filter { connection in
            // 根据连接状态过滤
            switch connectionFilter {
            case .active:
                guard connection.isAlive else { return false }
            case .closed:
                guard !connection.isAlive else { return false }
            }
            
            // 如果选择了任何协议，则按协议过滤
            if !selectedProtocols.isEmpty {
                guard selectedProtocols.contains(connection.metadata.network.uppercased()) else {
                    return false
                }
            }
            
            return true
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // 连接状态栏
                HStack {
                    // 状态信息
                    Image(systemName: viewModel.connectionState.statusIcon)
                        .foregroundColor(viewModel.connectionState.statusColor)
                        .rotationEffect(viewModel.connectionState.isConnecting ? .degrees(360) : .degrees(0))
                        .animation(viewModel.connectionState.isConnecting ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.connectionState)
                    
                    Text(viewModel.connectionState.message)
                        .font(.footnote)
                    
                    if viewModel.connectionState.isConnecting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    Spacer()
                    
                    // 流量统计
                    HStack(spacing: 12) {
                        Label(viewModel.formatBytes(viewModel.totalDownload), systemImage: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Label(viewModel.formatBytes(viewModel.totalUpload), systemImage: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                    }
                    .font(.footnote)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(viewModel.connectionState.statusColor.opacity(0.1))
                
                // 过滤标签栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // 连接状态切换器
                        Picker("连接状态", selection: $connectionFilter) {
                            Text("正活跃 (\(activeConnectionsCount))")
                                .tag(ConnectionFilter.active)
                            Text("已断开 (\(closedConnectionsCount))")
                                .tag(ConnectionFilter.closed)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)  // 增加宽度以适应数字
                        
                        // 协议过滤器
                        ForEach(["TCP", "UDP"], id: \.self) { protocolType in
                            FilterChip(
                                title: "\(protocolType) (\(protocolType == "TCP" ? tcpConnectionsCount : udpConnectionsCount))",
                                isSelected: selectedProtocols.contains(protocolType),
                                action: {
                                    if selectedProtocols.contains(protocolType) {
                                        selectedProtocols.remove(protocolType)
                                    } else {
                                        selectedProtocols.insert(protocolType)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // 连接列表
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredConnections) { connection in
                            ConnectionRow(
                                connection: connection,
                                viewModel: viewModel,
                                tagViewModel: tagViewModel
                            )
                        }
                    }
                    .animation(.default, value: filteredConnections)
                }
                .listStyle(.plain)
                .background(Color(.systemGroupedBackground))
                .overlay {
                    if filteredConnections.isEmpty && viewModel.connectionState == .connected {
                        ContentUnavailableView(
                            label: {
                                Label("没有连接", systemImage: "network.slash")
                            },
                            description: {
                                if !searchText.isEmpty {
                                    Text("没有找到匹配的连接")
                                } else {
                                    Text("当前没有活动的连接")
                                }
                            }
                        )
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索连接")
            .refreshable {
                await viewModel.refresh()
            }
            
            // 添加浮动暂停按钮
            FloatingActionButton(
                viewModel: viewModel,
                tagViewModel: tagViewModel,
                showClientTagSheet: $showClientTagSheet
            )
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
        .onAppear {
            viewModel.startMonitoring(server: server)
        }
        .onDisappear {
            viewModel.stopMonitoring()
            timer.upstream.connect().cancel()
        }
        .sheet(isPresented: $showClientTagSheet) {
            ClientTagView(
                viewModel: viewModel,
                tagViewModel: tagViewModel
            )
        }
    }
}

// 过滤器标签组件
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundColor(isSelected ? .white : .secondary)
                .cornerRadius(16)
        }
    }
}

// 添加新的 FloatingActionButton 组件
struct FloatingActionButton: View {
    let viewModel: ConnectionsViewModel
    let tagViewModel: ClientTagViewModel
    @Binding var showClientTagSheet: Bool
    @State private var showMenu = false
    @GestureState private var isDetectingLongPress = false
    
    var body: some View {
        VStack(spacing: 12) {
            if showMenu {
                // 暂停/继续监控
                MenuButton(
                    icon: viewModel.isMonitoring ? "pause.fill" : "play.fill",
                    color: .accentColor,
                    action: {
                        viewModel.toggleMonitoring()
                        showMenu = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                // 客户端标签
                MenuButton(
                    icon: "tag.fill",
                    color: .blue,
                    action: {
                        showClientTagSheet = true
                        showMenu = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                // 刷新视图
                MenuButton(
                    icon: "arrow.clockwise",
                    color: .green,
                    action: {
                        Task {
                            await viewModel.refresh()
                        }
                        showMenu = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                // 清理已断开连接
                MenuButton(
                    icon: "trash.fill",
                    color: .orange,
                    action: {
                        viewModel.clearClosedConnections()
                        showMenu = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                // 终止所有连接
                MenuButton(
                    icon: "xmark.circle.fill",
                    color: .red,
                    action: {
                        viewModel.closeAllConnections()
                        showMenu = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 主按钮 - 功能菜单图标
            Button(action: {
                if !showMenu {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showMenu = true
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showMenu = false
                    }
                }
            }) {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    .overlay {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .scaleEffect(isDetectingLongPress ? 1.1 : 1.0)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.3)
                    .updating($isDetectingLongPress) { currentState, gestureState, _ in
                        gestureState = currentState
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showMenu = true
                        }
                    }
            )
        }
    }
}

// 菜单按钮组件
struct MenuButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 40, height: 40)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                .overlay {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 14, weight: .semibold))
                }
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionsView(
            server: ClashServer(
                name: "测试服务器",
                url: "10.1.1.2",
                port: "9090",
                secret: "123456"
            )
        )
    }
} 
