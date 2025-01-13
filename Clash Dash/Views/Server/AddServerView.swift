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
    
    // 添加错误处理相关状态
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // OpenWRT 相关状态
    @State private var isOpenWRT = false
    @State private var openWRTUrl = ""
    @State private var openWRTPort = ""
    @State private var openWRTUseSSL = false
    @State private var openWRTUsername = ""
    @State private var openWRTPassword = ""
    @State private var luciPackage: LuCIPackage = .openClash
    
    // 添加触觉反馈生成器
    
    
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
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    TextField("控制器地址", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("控制器端口", text: $port)
                        .keyboardType(.numberPad)
                    TextField("控制器密钥（可选）", text: $secret)
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
                    Toggle("添加 OpenWRT 控制", isOn: $isOpenWRT)
                        .onChange(of: isOpenWRT) { newValue in
                            HapticManager.shared.impact(.light)
                        }
                    
                    if isOpenWRT {
                        TextField("OpenWRT地址（192.168.1.1）", text: $openWRTUrl)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                        
                        TextField("网页端口（80）", text: $openWRTPort)
                            .keyboardType(.numberPad)
                        
                        Toggle(isOn: $openWRTUseSSL) {
                            Label {
                                Text("使用 HTTPS")
                            } icon: {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(openWRTUseSSL ? .green : .secondary)
                            }
                        }
                        
                        TextField("用户名（root）", text: $openWRTUsername)
                            .textContentType(.username)
                            .autocapitalization(.none)
                        
                        SecureField("密码", text: $openWRTPassword)
                            .textContentType(.password)
                        
                        Text("选择你使用的管理器")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        Picker("", selection: $luciPackage) {
                            Text("OpenClash").tag(LuCIPackage.openClash)
                            Text("MihomoTProxy").tag(LuCIPackage.mihomoTProxy)
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("高级")
                } footer: {
                    if isOpenWRT {
                        Text("添加 OpenWRT 控制后，可以直接在 App 中所选的管理器中进行订阅管理、切换配置、附加规则、重启服务等操作")
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
            .navigationTitle("添加控制器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        Task {
                            isLoading = true
                            do {
                                if isOpenWRT {
                                    // 创建 OpenWRT 服务器
                                    let cleanHost = openWRTUrl.replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
                                    var server = ClashServer(
                                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                        url: cleanHost,
                                        port: "",
                                        secret: "",
                                        status: .unknown,
                                        version: nil,
                                        clashUseSSL: false,
                                        source: .openWRT
                                    )
                                    
                                    // 设置 OpenWRT 相关信息
                                    server.openWRTUrl = cleanHost
                                    server.openWRTUsername = openWRTUsername
                                    server.openWRTPassword = openWRTPassword
                                    server.openWRTPort = openWRTPort
                                    server.openWRTUseSSL = openWRTUseSSL
                                    server.luciPackage = luciPackage
                                    
                                    // 设置外部控制器信息
                                    server.url = url
                                    server.port = port
                                    server.secret = secret
                                    server.clashUseSSL = useSSL
                                    
                                    // 验证 OpenWRT 服务器
                                    _ = try await viewModel.validateOpenWRTServer(server, username: openWRTUsername, password: openWRTPassword)
                                    
                                    // 验证成功后添加服务器
                                    viewModel.addServer(server)
                                    await MainActor.run {
                                        dismiss()
                                    }
                                } else {
                                    // 创建普通服务器
                                    let server = ClashServer(
                                        name: name,
                                        url: url,
                                        port: port,
                                        secret: secret,
                                        clashUseSSL: useSSL
                                    )
                                    viewModel.addServer(server)
                                    await MainActor.run {
                                        dismiss()
                                    }
                                }
                            } catch {
                                await MainActor.run {
                                    if let networkError = error as? NetworkError {
                                        errorMessage = networkError.localizedDescription
                                    } else {
                                        errorMessage = error.localizedDescription
                                    }
                                    showError = true
                                    isLoading = false
                                }
                            }
                            await MainActor.run {
                                if !showError {
                                    isLoading = false
                                }
                            }
                        }
                    }
                    .disabled(url.isEmpty || port.isEmpty || (isOpenWRT && (openWRTUrl.isEmpty || openWRTPort.isEmpty || openWRTUsername.isEmpty || openWRTPassword.isEmpty)))
                }
            }
            .sheet(isPresented: $showingHelp) {
                AddServerHelpView()
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
} 
