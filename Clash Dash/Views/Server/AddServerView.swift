import SwiftUI

struct AddServerHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 基本说明
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("基本说明")
                                .font(.headline)
                        }
                        
                        Text("添加的是外部控制器的连接信息，地址一般为运行代理服务应用的设备的地址。")
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    
                    // MihomoTProxy 说明
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(.blue)
                            Text("MihomoTProxy")
                                .font(.headline)
                        }
                        
                        Text("如果使用的是 MihomoTProxy，外部控制器的端口和密钥信息可以在以下位置查看：")
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("MihomoTProxy → 混入配置 → 外部控制配置")
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(cardBackground)
                            .cornerRadius(8)
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    
                    // OpenClash 说明
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(.blue)
                            Text("OpenClash")
                                .font(.headline)
                        }
                        
                        Text("如果使用的是 OpenClash，外部控制器的信息显示在 OpenClash 运行状态页面：")
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("• 控制面板登录 IP")
                            Text("• 控制面板登录端口")
                            Text("• 控制面板登录密钥（如果未设置则可以留空）")
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground)
                        .cornerRadius(8)
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    
                    // Sing-Box 说明
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(.blue)
                            Text("Sing-Box")
                                .font(.headline)
                        }
                        
                        Text("如果使用的是 Sing-Box，外部控制的信息在所使用的配置文件中可以找到（external-controller）")
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    
                    // 故障排除
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("故障排除")
                                .font(.headline)
                        }
                        
                        Text("如果添加失败，请检查以下内容：")
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("1. 确认地址和端口是否正确")
                            Text("2. 检查设备是否在同一网络")
                            Text("3. 查看运行日志以获取详细错误信息")
                            Text("4. 如果使用域名访问，确保已启用 HTTPS")
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardBackground)
                        .cornerRadius(8)
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("使用帮助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    
    @State private var name = ""
    @State private var url = ""
    @State private var port = ""
    @State private var secret = ""
    @State private var useSSL = false
    @State private var showingHelp = false
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    private func checkIfHostname(_ urlString: String) -> Bool {
        let ipPattern = "^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$"
        let ipPredicate = NSPredicate(format: "SELF MATCHES %@", ipPattern)
        let trimmedUrl = urlString.trimmingCharacters(in: .whitespaces)
        return !ipPredicate.evaluate(with: trimmedUrl) && !trimmedUrl.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称（可选）", text: $name)
                    TextField("控制面板登录地址", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("控制面板登录端口", text: $port)
                        .keyboardType(.numberPad)
                    TextField("控制面板登录密钥（可选）", text: $secret)
                        .textInputAutocapitalization(.never)
                    
                    Toggle(isOn: $useSSL) {
                        Label {
                            Text("使用 HTTPS")
                        } icon: {
                            Image(systemName: "lock.fill")
                                .foregroundColor(useSSL ? .green : .secondary)
                        }
                    }
                } header: {
                    Text("外部控制器信息")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("如果外部控制器启用了 HTTPS，请打开 HTTPS 开关")
                    }
                }
                
                Section {
                    Button {
                        showingHelp = true
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("使用帮助")
                        }
                    }
                }
            }
            .navigationTitle("添加外部控制器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let server = ClashServer(
                            name: name,
                            url: url,
                            port: port,
                            secret: secret,
                            useSSL: useSSL
                        )
                        viewModel.addServer(server)
                        dismiss()
                    }
                    .disabled(url.isEmpty || port.isEmpty)
                }
            }
            .sheet(isPresented: $showingHelp) {
                AddServerHelpView()
            }
        }
    }
} 