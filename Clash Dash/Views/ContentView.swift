import SwiftUI
import UIKit
import SafariServices

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
    @State private var showingSourceCode = false
    @AppStorage("appThemeMode") private var appThemeMode = AppThemeMode.system
    @Environment(\.scenePhase) private var scenePhase
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
                            .padding(.bottom, 40)
                        }
                    } else {
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
                                    .serverContextMenu(
                                        viewModel: viewModel,
                                        settingsViewModel: settingsViewModel,
                                        server: server,
                                        onEdit: { editingServer = server },
                                        onModeChange: { mode in showModeChangeSuccess(mode: mode) },
                                        onShowConfigSubscription: { showConfigSubscriptionView(for: server) },
                                        onShowSwitchConfig: { showSwitchConfigView(for: server) },
                                        onShowCustomRules: { showCustomRulesView(for: server) },
                                        onShowRestartService: { showRestartServiceView(for: server) }
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onTapGesture {
                                impactFeedback.impactOccurred()
                            }
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
                        
                        Button {
                            impactFeedback.impactOccurred()
                            showingSourceCode = true
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(.body)
                                    .foregroundColor(.purple)
                                    .frame(width: 32)
                                
                                Text("源码查看")
                                    .font(.body)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    
                    // 版本信息
                    Text("Ver: 1.2.9 (TestFlight Build 7)")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .padding(.top, 8)
                }
                .padding()
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
            .sheet(isPresented: $showingSourceCode) {
                if let url = URL(string: "https://github.com/bin64/Clash-Dash") {
                    SafariWebView(url: url)
                        .ignoresSafeArea()
                }
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
                        Text("已切换至\(ModeUtils.getModeText(lastChangedMode))")
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
        .preferredColorScheme(colorScheme)
        .onAppear {
            // 首次打开时刷新服务器列表
            Task {
                await viewModel.checkAllServersStatus()
            }
            
            if let quickLaunchServer = viewModel.servers.first(where: { $0.isQuickLaunch }) {
                selectedQuickLaunchServer = quickLaunchServer
                showQuickLaunchDestination = true
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // 从后台返回前台时刷新服务器列表
                Task {
                    await viewModel.checkAllServersStatus()
                }
            }
        }
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
    
    private var colorScheme: ColorScheme? {
        switch appThemeMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
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

