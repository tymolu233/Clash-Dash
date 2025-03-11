import SwiftUI

struct HelpView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        List {
            Section("基本使用") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("1. 添加服务器")
                        .font(.headline)
                    Text("点击右上角的+号添加新的服务器配置。需要填写服务器地址、端口和密钥（如果有）。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("2. 检查服务器状态")
                        .font(.headline)
                    Text("服务器列表会显示每个服务器的连接状态。绿色表示正常，黄色表示未授权，红色表示错误。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("3. 管理服务器")
                        .font(.headline)
                    Text("长按服务器项目可以进行编辑或删除操作。下拉列表可以刷新所有服务器状态。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("4. 快速启动")
                        .font(.headline)
                    Text("长按服务器可以将其设置为快速启动（闪电图标）。设置后，App 启动时会自动打开该服务器的详情页面。每次只能设置一个快速启动服务器。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section("常见问题") {
                DisclosureGroup("为什么没有订阅信息卡片出现？") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("订阅信息卡片是需要 Clash Dash 从后端获取到订阅信息后才会展示。具体的逻辑：")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("1. 如果您添加的控制器中添加了 OpenWrt 的登录信息，那会尝试从 OpenWrt 运行的插件处获取，如果获取失败，则会尝试从 Clash 控制器处获取。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("2. 从 Clash 控制器处获取的时候，只有当配置文件中使用了 proxy-providers 字段的时候才有可能提供订阅信息。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("3. 所以如果你没有订阅信息卡片出现，请确保您的 OpenClash 或者 Nikki 上能够展示订阅信息，或者 Clash 的配置文件中使用了 proxy-providers 配置。您也可以查看运行日志来进行确认。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("查看")
                                .font(.subheadline)
                            Button {
                                if let url = URL(string: "https://wiki.metacubex.one/en/config/proxy-providers") {
                                    openURL(url)
                                }
                            } label: {
                                Text("proxy-providers 配置文档")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }
                
                DisclosureGroup("为什么我的代理页面没有图标？") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("需要在 Clash 配置文件中配置 icon 字段。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("查看")
                                .font(.subheadline)
                            Button {
                                if let url = URL(string: "https://wiki.metacubex.one/config/proxy-groups/?h=icon#icon") {
                                    openURL(url)
                                }
                            } label: {
                                Text("icon 配置文档")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("使用帮助")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HelpView()
    }
} 
