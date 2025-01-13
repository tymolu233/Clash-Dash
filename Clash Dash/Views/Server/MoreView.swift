import SwiftUI

struct MoreView: View {
    let server: ClashServer
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = ServerDetailViewModel()
    @State private var showingConfigSubscription = false
    @State private var showingSwitchConfig = false
    @State private var showingCustomRules = false
    @State private var showingRestartService = false
    @State private var showingServiceLog = false
    
    // 添加触觉反馈生成器
    
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? 
            Color(.systemGray6) : 
            Color(.systemBackground)
    }
    
    private var versionDisplay: String {
        guard let version = server.version else { return "未知版本" }
        return version
    }
    
    private var kernelType: String {
        guard let type = server.serverType else { return "未知内核" }
        switch type {
        case .meta: return "Mihomo (meta)"
        case .premium: return "Clash Premium"
        case .singbox: return "Sing-Box"
        case .unknown: return "未知内核"
        }
    }
    
    var body: some View {
        List {
            NavigationLink {
                SettingsView(server: server)
            } label: {
                HStack {
                    Image(systemName: "gearshape")
                        .foregroundColor(.blue)
                        .frame(width: 25)
                    Text("配置")
                }
            }
            
            NavigationLink {
                LogView(server: server)
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                        .frame(width: 25)
                    Text("日志")
                }
            }
            
            // 添加域名查询工具
            NavigationLink {
                DNSQueryView(server: server)
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                        .frame(width: 25)
                    Text("解析")
                }
            }
            
            // OpenClash 功能组
            if server.luciPackage == .openClash && server.source == .openWRT {
                Section("OpenClash 插件控制") {
                    Button {
                        HapticManager.shared.impact(.light)
                        showingServiceLog = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.below.ecg")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text("运行日志")
                        }
                    }
                    
                    Button {
                        HapticManager.shared.impact(.light)
                        showingConfigSubscription = true
                    } label: {
                        HStack {
                            Image(systemName: "cloud")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text("订阅管理")
                        }
                    }
                    
                    Button {
                        HapticManager.shared.impact(.light)
                        showingSwitchConfig = true
                    } label: {
                        HStack {
                            Image(systemName: "filemenu.and.selection")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text("配置管理")
                        }
                    }
                    
                    Button {
                        HapticManager.shared.impact(.light)
                        showingCustomRules = true
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text("附加规则")
                        }
                    }
                    
                    Button {
                        HapticManager.shared.impact(.light)
                        showingRestartService = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text("重启服务")
                        }
                    }
                }
            }

            // MihomoTProxy 功能组
            if server.luciPackage == .mihomoTProxy && server.source == .openWRT {
                Section("MihomoTProxy 插件控制") {
                    Button {
                        HapticManager.shared.impact(.light)
                        showingServiceLog = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.below.ecg")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text("运行日志")
                        }
                    }
                    
                    Button {
                        HapticManager.shared.impact(.light)
                        showingConfigSubscription = true
                    } label: {
                        HStack {
                            Image(systemName: "cloud")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text("订阅管理")
                        }
                    }
                    
                    // Button {
                    //     HapticManager.shared.impact(.light)
                    //     showingCustomRules = true
                    // } label: {
                    //     HStack {
                    //         Image(systemName: "list.bullet.rectangle")
                    //             .foregroundColor(.blue)
                    //             .frame(width: 25)
                    //         Text("附加规则")
                    //     }
                    // }
                    
                    Button {
                        HapticManager.shared.impact(.light)
                        showingRestartService = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text("重启服务")
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingConfigSubscription) {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                NavigationStack {
                    ConfigSubscriptionView(server: server)
                }
            }
        }
        .sheet(isPresented: $showingSwitchConfig) {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                NavigationStack {
                    OpenClashConfigView(viewModel: viewModel.serverViewModel, server: server)
                }
            }
        }
        .sheet(isPresented: $showingCustomRules) {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                NavigationStack {
                    OpenClashRulesView(server: server)
                }
            }
        }
        .sheet(isPresented: $showingRestartService) {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                NavigationStack {
                    RestartServiceView(viewModel: viewModel.serverViewModel, server: server)
                }
            }
        }
        .sheet(isPresented: $showingServiceLog) {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                NavigationStack {
                    ServiceLogView(server: server)
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if server.status == .ok {
                VStack(spacing: 4) {
                    Label {
                        Text(kernelType)
                    } icon: {
                        Image(systemName: "cpu")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Label {
                        Text(versionDisplay)
                    } icon: {
                        Image(systemName: "tag")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MoreView(server: ClashServer(name: "测试服务器", url: "10.1.1.2", port: "9090", secret: "123456"))
    }
} 