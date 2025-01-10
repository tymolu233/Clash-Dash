import SwiftUI

struct ServerContextMenu: ViewModifier {
    @ObservedObject var viewModel: ServerViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var showingDeleteAlert = false
    let server: ClashServer
    var onEdit: () -> Void
    var onModeChange: (String) -> Void
    var onShowConfigSubscription: () -> Void
    var onShowSwitchConfig: () -> Void
    var onShowCustomRules: () -> Void
    var onShowRestartService: () -> Void
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    func body(content: Content) -> some View {
        content.contextMenu {
            // 基础操作组
            Group {
                
                
                Button {
                    impactFeedback.impactOccurred()
                    onEdit()
                } label: {
                    Label("编辑", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    impactFeedback.impactOccurred()
                    showingDeleteAlert = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            
            if viewModel.servers.count > 1 {
                Divider()
                
                // 添加上移和下移选项
                Group {
                    // 上移选项
                    if let index = viewModel.servers.firstIndex(where: { $0.id == server.id }), index > 0 {
                        Button {
                            impactFeedback.impactOccurred()
                            viewModel.moveServerUp(server)
                        } label: {
                            Label("上移", systemImage: "arrow.up")
                        }
                    }
                    
                    // 下移选项
                    if let index = viewModel.servers.firstIndex(where: { $0.id == server.id }), index < viewModel.servers.count - 1 {
                        Button {
                            impactFeedback.impactOccurred()
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
                impactFeedback.impactOccurred()
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
                    impactFeedback.impactOccurred()
                    onShowConfigSubscription()
                } label: {
                    Label("订阅管理", systemImage: "cloud")
                }
                
                Button {
                    impactFeedback.impactOccurred()
                    onShowSwitchConfig()
                } label: {
                    Label("配置管理", systemImage: "document.badge.gearshape")
                }
                
                Button {
                    impactFeedback.impactOccurred()
                    onShowCustomRules()
                } label: {
                    Label("附加规则", systemImage: "list.bullet.rectangle")
                }
                
                Button {
                    impactFeedback.impactOccurred()
                    onShowRestartService()
                } label: {
                    Label("重启服务", systemImage: "arrow.clockwise.circle")
                }
            }

            // mihomoTProxy 特有功能组
            if server.luciPackage == .mihomoTProxy && server.source == .openWRT {
                Divider()
                
                Button {
                    impactFeedback.impactOccurred()
                    onShowConfigSubscription()
                } label: {
                    Label("订阅管理", systemImage: "cloud")
                }
                
                Button {
                    impactFeedback.impactOccurred()
                    onShowSwitchConfig()
                } label: {
                    Label("配置管理", systemImage: "document.badge.gearshape")
                }
                
                // Button {
                //     impactFeedback.impactOccurred()
                //     onShowCustomRules()
                // } label: {
                //     Label("附加规则", systemImage: "list.bullet.rectangle")
                // }
                
                Button {
                    impactFeedback.impactOccurred()
                    onShowRestartService()
                } label: {
                    Label("重启服务", systemImage: "arrow.clockwise.circle")
                }
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
            onEdit: onEdit,
            onModeChange: onModeChange,
            onShowConfigSubscription: onShowConfigSubscription,
            onShowSwitchConfig: onShowSwitchConfig,
            onShowCustomRules: onShowCustomRules,
            onShowRestartService: onShowRestartService
        ))
    }
} 