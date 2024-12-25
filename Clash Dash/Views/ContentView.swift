import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = ServerViewModel()
    @State private var showingAddSheet = false
    @State private var editingServer: ClashServer?
    @State private var selectedQuickLaunchServer: ClashServer?
    @State private var showQuickLaunchDestination = false
    @State private var showingAddOpenWRTSheet = false
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var showingModeChangeSuccess = false
    @State private var lastChangedMode = ""
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.servers.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                            .frame(height: 60)
                        
                        Image(systemName: "server.rack")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.bottom, 10)
                        
                        Text("没有服务器")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("点击添加按钮来添加一个新的服务器")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Menu {
                            Button(action: {
                                impactFeedback.impactOccurred()
                                showingAddSheet = true
                            }) {
                                Label("Clash 控制器", systemImage: "server.rack")
                            }
                            
                            Button(action: {
                                impactFeedback.impactOccurred()
                                showingAddOpenWRTSheet = true
                            }) {
                                Label("OpenWRT 服务器", systemImage: "wifi.router")
                            }
                        } label: {
                            Text("添加服务器")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 160, height: 44)
                                .background(Color.blue)
                                .cornerRadius(22)
                                .onTapGesture {
                                    impactFeedback.impactOccurred()
                                }
                        }
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 20) {
                        // 服务器卡片列表
                        ForEach(viewModel.servers) { server in
                            NavigationLink {
                                ServerDetailView(server: server)
                                    .onAppear {
                                        // 添加触觉反馈
                                        impactFeedback.impactOccurred()
                                    }
                            } label: {
                                ServerRowView(server: server)
                                    .contextMenu {
                                        // 基础操作组
                                        Group {
                                            Button(role: .destructive) {
                                                impactFeedback.impactOccurred()
                                                viewModel.deleteServer(server)
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                            
                                            Button {
                                                impactFeedback.impactOccurred()
                                                editingServer = server
                                            } label: {
                                                Label("编辑", systemImage: "pencil")
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        // 快速启动组
                                        Button {
                                            impactFeedback.impactOccurred()
                                            viewModel.setQuickLaunch(server)
                                        } label: {
                                            Label(server.isQuickLaunch ? "取消快速启动" : "设为快速启动", 
                                                  systemImage: server.isQuickLaunch ? "bolt.slash.circle" : "bolt.circle")
                                        }
                                        
                                        Menu {
                                            Button {
                                                impactFeedback.impactOccurred()
                                                settingsViewModel.updateConfig("mode", value: "rule", server: server) { 
                                                    settingsViewModel.mode = "rule"
                                                    showModeChangeSuccess(mode: "rule")
                                                }
                                            } label: {
                                                Label("规则模式", systemImage: settingsViewModel.mode == "rule" ? "checkmark" : "circle")
                                            }
                                            
                                            Button {
                                                impactFeedback.impactOccurred()
                                                settingsViewModel.updateConfig("mode", value: "direct", server: server) { 
                                                    settingsViewModel.mode = "direct"
                                                    showModeChangeSuccess(mode: "direct")
                                                }
                                            } label: {
                                                Label("直连模式", systemImage: settingsViewModel.mode == "direct" ? "checkmark" : "circle")
                                            }
                                            
                                            Button {
                                                impactFeedback.impactOccurred()
                                                settingsViewModel.updateConfig("mode", value: "global", server: server) { 
                                                    settingsViewModel.mode = "global"
                                                    showModeChangeSuccess(mode: "global")
                                                }
                                            } label: {
                                                Label("全局模式", systemImage: settingsViewModel.mode == "global" ? "checkmark" : "circle")
                                            }
                                        } label: {
                                            Label(getModeText(settingsViewModel.mode), systemImage: getModeIcon(settingsViewModel.mode))
                                        }
                                        .onAppear {
                                            settingsViewModel.getCurrentMode(server: server) { currentMode in
                                                settingsViewModel.mode = currentMode
                                            }
                                        }
                                        
                                        // OpenWRT 特有功能组
                                        if server.source == .openWRT {
                                            Divider()
                                            Button {
                                                impactFeedback.impactOccurred()
                                                showConfigSubscriptionView(for: server)
                                            } label: {
                                                Label("订阅管理", systemImage: "cloud.fill")
                                            }
                                            
                                            Button {
                                                impactFeedback.impactOccurred()
                                                showSwitchConfigView(for: server)
                                            } label: {
                                                Label("切换配置", systemImage: "arrow.2.circlepath")
                                            }
                                            
                                            Button {
                                                impactFeedback.impactOccurred()
                                                showCustomRulesView(for: server)
                                            } label: {
                                                Label("覆写规则", systemImage: "list.bullet.rectangle")
                                            }
                                            
                                            Button {
                                                impactFeedback.impactOccurred()
                                                showRestartServiceView(for: server)
                                            } label: {
                                                Label("重启服务", systemImage: "arrow.clockwise.circle")
                                            }
                                        }
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onTapGesture {
                                impactFeedback.impactOccurred()
                            }
                        }
                        
                        // 设置卡片
                        VStack(spacing: 16) {
                            SettingsLinkRow(
                                title: "全局配置",
                                icon: "gearshape.fill",
                                iconColor: .gray,
                                destination: GlobalSettingsView()
                            )
                            
                            SettingsLinkRow(
                                title: "运行日志",
                                icon: "doc.text.fill",
                                iconColor: .orange,
                                destination: LogsView()
                            )
                            
                            SettingsLinkRow(
                                title: "如何使用",
                                icon: "questionmark.circle.fill",
                                iconColor: .blue,
                                destination: HelpView()
                            )
                            
                            // SettingsLinkRow(
                            //     title: "给APP评分",
                            //     icon: "star.fill",
                            //     iconColor: .yellow,
                            //     destination: RateAppView()
                            // )
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        
                        // 版本信息
                        Text("Ver: 1.2.5")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Clash Dash")
            .navigationDestination(isPresented: $showQuickLaunchDestination) {
                if let server = selectedQuickLaunchServer ?? viewModel.servers.first {
                    ServerDetailView(server: server)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            impactFeedback.impactOccurred()
                            showingAddSheet = true
                        }) {
                            Label("Clash 控制器", systemImage: "server.rack")
                        }
                        
                        Button(action: {
                            impactFeedback.impactOccurred()
                            showingAddOpenWRTSheet = true
                        }) {
                            Label("OpenWRT 服务器", systemImage: "wifi.router")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .onTapGesture {
                                impactFeedback.impactOccurred()
                            }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddServerView(viewModel: viewModel)
            }
            .sheet(item: $editingServer) { server in
                if server.source == .clashController {
                    EditServerView(viewModel: viewModel, server: server)
                } else {
                    OpenWRTServerView(viewModel: viewModel, server: server)
                }
            }
            .sheet(isPresented: $showingAddOpenWRTSheet) {
                OpenWRTServerView(viewModel: viewModel)
            }
            .refreshable {
                await viewModel.checkAllServersStatus()
            }
            .alert("连接错误", isPresented: $viewModel.showError) {
                Button("确定", role: .cancel) {}
            } message: {
                if let details = viewModel.errorDetails {
                    Text("\(viewModel.errorMessage ?? "")\n\n\(details)")
                } else {
                    Text(viewModel.errorMessage ?? "")
                }
            }
            .overlay(alignment: .bottom) {
                if showingModeChangeSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        Text("已切换至\(getModeText(lastChangedMode))")
                            .foregroundColor(.primary)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(25)
                    .shadow(radius: 10, x: 0, y: 5)
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            if let quickLaunchServer = viewModel.servers.first(where: { $0.isQuickLaunch }) {
                selectedQuickLaunchServer = quickLaunchServer
                showQuickLaunchDestination = true
            }
        }
    }
    
    private func showManagementView(for server: ClashServer) {
        // 显示管理页的逻辑
    }
    
    private func showSwitchConfigView(for server: ClashServer) {
        editingServer = nil  // 清除编辑状态
        let configView = OpenClashConfigView(viewModel: viewModel, server: server)
        let sheet = UIHostingController(rootView: configView)
        
        // 设置 sheet 的首选样式
        sheet.modalPresentationStyle = .formSheet
        sheet.sheetPresentationController?.detents = [.medium(), .large()]
        sheet.sheetPresentationController?.prefersGrabberVisible = true
        
        // 获取当前的 window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(sheet, animated: true)
        }
    }
    
    private func showConfigSubscriptionView(for server: ClashServer) {
        editingServer = nil  // 清除编辑状态
        let configView = ConfigSubscriptionView(server: server)
        let sheet = UIHostingController(rootView: configView)
        
        // 设置 sheet 的首选样式
        sheet.modalPresentationStyle = .formSheet
        sheet.sheetPresentationController?.detents = [.medium(), .large()]
        sheet.sheetPresentationController?.prefersGrabberVisible = true
        
        // 获取当前的 window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(sheet, animated: true)
        }
    }
    
    private func showCustomRulesView(for server: ClashServer) {
        editingServer = nil  // 清除编辑状态
        let rulesView = OpenClashRulesView(server: server)
        let sheet = UIHostingController(rootView: rulesView)
        
        sheet.modalPresentationStyle = .formSheet
        sheet.sheetPresentationController?.detents = [.medium(), .large()]
        sheet.sheetPresentationController?.prefersGrabberVisible = true
        sheet.sheetPresentationController?.selectedDetentIdentifier = .medium
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(sheet, animated: true)
        }
    }
    
    private func showRestartServiceView(for server: ClashServer) {
        editingServer = nil  // 清除编辑状态
        let restartView = RestartServiceView(viewModel: viewModel, server: server)
        let sheet = UIHostingController(rootView: restartView)
        
        sheet.modalPresentationStyle = .formSheet
        sheet.sheetPresentationController?.detents = [.medium(), .large()]
        sheet.sheetPresentationController?.prefersGrabberVisible = true
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(sheet, animated: true)
        }
    }
    
    private func getModeText(_ mode: String) -> String {
        switch mode {
        case "rule": return "规则模式"
        case "direct": return "直连模式"
        case "global": return "全局模式"
        default: return "切换模式"
        }
    }
    
    private func getModeIcon(_ mode: String) -> String {
        switch mode {
        case "rule": return "list.bullet"
        case "direct": return "arrow.up.right"
        case "global": return "globe"
        default: return "shuffle"
        }
    }
    
    private func showModeChangeSuccess(mode: String) {
        lastChangedMode = mode
        withAnimation {
            showingModeChangeSuccess = true
        }
        // 1秒后隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                showingModeChangeSuccess = false
            }
        }
    }
}



struct SettingsLinkRow<Destination: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 32)
                
                Text(title)
                    .font(.body)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}

