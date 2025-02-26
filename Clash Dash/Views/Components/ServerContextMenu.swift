import SwiftUI

struct ServerContextMenu: ViewModifier {
    @ObservedObject var viewModel: ServerViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var showingDeleteAlert = false
    @State private var showingServiceLog = false
    @State private var showingWebView = false
    @State private var isLiveActivityActive = false
    let server: ClashServer
    let showMoveOptions: Bool
    var onEdit: () -> Void
    var onModeChange: (String) -> Void
    var onShowConfigSubscription: () -> Void
    var onShowSwitchConfig: () -> Void
    var onShowCustomRules: () -> Void
    var onShowRestartService: () -> Void
    
    init(viewModel: ServerViewModel, 
         settingsViewModel: SettingsViewModel, 
         server: ClashServer, 
         showMoveOptions: Bool, 
         onEdit: @escaping () -> Void, 
         onModeChange: @escaping (String) -> Void, 
         onShowConfigSubscription: @escaping () -> Void, 
         onShowSwitchConfig: @escaping () -> Void, 
         onShowCustomRules: @escaping () -> Void, 
         onShowRestartService: @escaping () -> Void) {
        self.viewModel = viewModel
        self.settingsViewModel = settingsViewModel
        self.server = server
        self.showMoveOptions = showMoveOptions
        self.onEdit = onEdit
        self.onModeChange = onModeChange
        self.onShowConfigSubscription = onShowConfigSubscription
        self.onShowSwitchConfig = onShowSwitchConfig
        self.onShowCustomRules = onShowCustomRules
        self.onShowRestartService = onShowRestartService
        
        // 检查灵动岛活动状态
        var isRunning = false
        if #available(iOS 16.1, *) {
            isRunning = LiveActivityManager.shared.isActivityRunning(for: server)
        }
        self._isLiveActivityActive = State(initialValue: isRunning)
    }
    
    private func startLiveActivity() {
        HapticManager.shared.notification(.success)
        print("🚀 开始启动灵动岛活动 - ServerContextMenu")
        // 调用LiveActivityManager启动灵动岛活动
        if #available(iOS 16.1, *) {
            Task {
                print("📱 服务器信息: \(server.name) (\(server.url))")
                await LiveActivityManager.shared.startActivity(for: server)
                print("✅ LiveActivityManager.startActivity已调用")
                
                // 等待一秒后检查活动状态
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let running = LiveActivityManager.shared.isActivityRunning(for: server)
                print("📊 活动状态检查: \(running ? "运行中" : "未运行")")
                
                isLiveActivityActive = running
                print("🔄 更新UI状态: isLiveActivityActive = \(isLiveActivityActive)")
            }
        }
    }
    
    private func stopLiveActivity() {
        HapticManager.shared.notification(.success)
        print("🛑 开始停止灵动岛活动 - ServerContextMenu")
        // 调用LiveActivityManager停止灵动岛活动
        if #available(iOS 16.1, *) {
            Task {
                await LiveActivityManager.shared.stopActivity()
                print("✅ LiveActivityManager.stopActivity已调用")
                
                // 等待一秒后检查活动状态
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let running = LiveActivityManager.shared.isActivityRunning(for: server)
                print("📊 活动状态检查: \(running ? "仍在运行" : "已停止")")
                
                isLiveActivityActive = running
                print("🔄 更新UI状态: isLiveActivityActive = \(isLiveActivityActive)")
            }
        }
    }
    
    func body(content: Content) -> some View {
        content.contextMenu {
            // 基础操作组
            Group {
                
                if #available(iOS 16.1, *) {
                    if isLiveActivityActive {
                        Button {
                            HapticManager.shared.impact(.light)
                            // 停止灵动岛显示
                            stopLiveActivity()
                        } label: {
                            Label("停止灵动岛显示", systemImage: "chart.line.downtrend.xyaxis.circle")
                        }
                    } else {
                        Button {
                            HapticManager.shared.impact(.light)
                            // 启动灵动岛显示实时速度
                            startLiveActivity()
                        } label: {
                            Label("在灵动岛显示", systemImage: "chart.line.uptrend.xyaxis.circle")
                        }
                    }
                }
                
                Button {
                    HapticManager.shared.impact(.light)
                    onEdit()
                } label: {
                    Label("编辑", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    HapticManager.shared.impact(.light)
                    showingDeleteAlert = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            
            if viewModel.servers.count > 1 && showMoveOptions {
                Divider()
                
                // 添加上移和下移选项
                Group {
                    // 上移选项
                    if let index = viewModel.servers.firstIndex(where: { $0.id == server.id }), index > 0 {
                        Button {
                            HapticManager.shared.impact(.light)
                            viewModel.moveServerUp(server)
                        } label: {
                            Label("上移", systemImage: "arrow.up")
                        }
                    }
                    
                    // 下移选项
                    if let index = viewModel.servers.firstIndex(where: { $0.id == server.id }), index < viewModel.servers.count - 1 {
                        Button {
                            HapticManager.shared.impact(.light)
                            viewModel.moveServerDown(server)
                        } label: {
                            Label("下移", systemImage: "arrow.down")
                        }
                    }
                }
                
                Divider()
            }
            
            // 快速启动组
            Button {
                HapticManager.shared.impact(.light)
                viewModel.setQuickLaunch(server)
            } label: {
                Label(server.isQuickLaunch ? "取消快速启动" : "设为快速启动", 
                      systemImage: server.isQuickLaunch ? "bolt.slash.circle" : "bolt.circle")
            }
            
            ModeSelectionMenu(settingsViewModel: settingsViewModel, 
                            server: server, 
                            onModeChange: onModeChange)
            
            // OpenClash 特有功能组
            if server.luciPackage == .openClash && server.source == .openWRT {
                Divider()

                Button {
                    HapticManager.shared.impact(.light)
                    showingServiceLog = true
                } label: {
                    Label("运行日志", systemImage: "doc.text.below.ecg")
                }
                
                Button {
                    HapticManager.shared.impact(.light)
                    onShowConfigSubscription()
                } label: {
                    Label("订阅管理", systemImage: "cloud")
                }
                
                Button {
                    HapticManager.shared.impact(.light)
                    onShowSwitchConfig()
                } label: {
                    Label("配置管理", systemImage: "filemenu.and.selection")
                }
                
                Button {
                    HapticManager.shared.impact(.light)
                    onShowCustomRules()
                } label: {
                    Label("附加规则", systemImage: "list.bullet.rectangle")
                }
                
                Button {
                    HapticManager.shared.impact(.light)
                    onShowRestartService()
                } label: {
                    Label("重启服务", systemImage: "arrow.clockwise.circle")
                }

                Button {
                    HapticManager.shared.impact(.light)
                    showingWebView = true
                } label: {
                    Label("网页访问", systemImage: "safari")
                }
            }

            // mihomoTProxy 特有功能组
            if server.luciPackage == .mihomoTProxy && server.source == .openWRT {
                Divider()

                Button {
                    HapticManager.shared.impact(.light)
                    showingServiceLog = true
                } label: {
                    Label("运行日志", systemImage: "doc.text.below.ecg")
                }
                
                Button {
                    HapticManager.shared.impact(.light)
                    onShowConfigSubscription()
                } label: {
                    Label("订阅管理", systemImage: "cloud")
                }
                
                Button {
                    HapticManager.shared.impact(.light)
                    onShowSwitchConfig()
                } label: {
                    Label("配置管理", systemImage: "filemenu.and.selection")
                }
                
                Button {
                    HapticManager.shared.impact(.light)
                    onShowCustomRules()
                } label: {
                    Label("附加规则", systemImage: "list.bullet.rectangle")
                }
                
                Button {
                    HapticManager.shared.impact(.light)
                    onShowRestartService()
                } label: {
                    Label("重启服务", systemImage: "arrow.clockwise.circle")
                }

                Button {
                    HapticManager.shared.impact(.light)
                    showingWebView = true
                } label: {
                    Label("网页访问", systemImage: "safari")
                }
            }
        }
        .sheet(isPresented: $showingServiceLog) {
            NavigationStack {
                ServiceLogView(server: server)
            }
        }
        .sheet(isPresented: $showingWebView) {
            NavigationStack {
                LuCIWebView(server: server)
            }
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                viewModel.deleteServer(server)
            }
        } message: {
            Text("是否确认删除此控制器？此操作不可撤销。")
        }
    }
}

extension View {
    func serverContextMenu(
        viewModel: ServerViewModel,
        settingsViewModel: SettingsViewModel,
        server: ClashServer,
        showMoveOptions: Bool = true,
        onEdit: @escaping () -> Void,
        onModeChange: @escaping (String) -> Void,
        onShowConfigSubscription: @escaping () -> Void,
        onShowSwitchConfig: @escaping () -> Void,
        onShowCustomRules: @escaping () -> Void,
        onShowRestartService: @escaping () -> Void
    ) -> some View {
        modifier(ServerContextMenu(
            viewModel: viewModel,
            settingsViewModel: settingsViewModel,
            server: server,
            showMoveOptions: showMoveOptions,
            onEdit: onEdit,
            onModeChange: onModeChange,
            onShowConfigSubscription: onShowConfigSubscription,
            onShowSwitchConfig: onShowSwitchConfig,
            onShowCustomRules: onShowCustomRules,
            onShowRestartService: onShowRestartService
        ))
    }
} 