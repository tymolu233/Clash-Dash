import SwiftUI

struct MoreView: View {
    let server: ClashServer
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = ServerDetailViewModel()
    @State private var showingConfigSubscription = false
    @State private var showingSwitchConfig = false
    @State private var showingCustomRules = false
    @State private var showingRestartService = false
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
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
                Section("OpenClash 功能") {
                    Button {
                        impactFeedback.impactOccurred()
                        showingConfigSubscription = true
                    } label: {
                        HStack {
                            Image(systemName: "cloud.fill")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text("订阅管理")
                        }
                    }
                    
                    Button {
                        impactFeedback.impactOccurred()
                        showingSwitchConfig = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.2.circlepath")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text("切换配置")
                        }
                    }
                    
                    Button {
                        impactFeedback.impactOccurred()
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
                        impactFeedback.impactOccurred()
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
            NavigationStack {
                ConfigSubscriptionView(server: server)
            }
        }
        .sheet(isPresented: $showingSwitchConfig) {
            NavigationStack {
                OpenClashConfigView(viewModel: viewModel.serverViewModel, server: server)
            }
        }
        .sheet(isPresented: $showingCustomRules) {
            NavigationStack {
                OpenClashRulesView(server: server)
            }
        }
        .sheet(isPresented: $showingRestartService) {
            NavigationStack {
                RestartServiceView(viewModel: viewModel.serverViewModel, server: server)
            }
        }
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