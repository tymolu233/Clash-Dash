import SwiftUI

struct EditServerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    let server: ClashServer
    
    @State private var name: String
    @State private var url: String
    @State private var port: String
    @State private var secret: String
    @State private var useSSL: Bool
    @State private var showingHelp = false
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    private func checkIfHostname(_ urlString: String) -> Bool {
        let ipPattern = "^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$"
        let ipPredicate = NSPredicate(format: "SELF MATCHES %@", ipPattern)
        let trimmedUrl = urlString.trimmingCharacters(in: .whitespaces)
        return !ipPredicate.evaluate(with: trimmedUrl) && !trimmedUrl.isEmpty
    }
    
    init(viewModel: ServerViewModel, server: ClashServer) {
        self.viewModel = viewModel
        self.server = server
        self._name = State(initialValue: server.name)
        self._url = State(initialValue: server.url)
        self._port = State(initialValue: server.port)
        self._secret = State(initialValue: server.secret)
        self._useSSL = State(initialValue: server.useSSL)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称（可选）", text: $name)
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
                    Button {
                        showingHelp = true
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("使用帮助")
                        }
                    }
                }
                
                if server.source != .openWRT {
                    Section {
                        Button(role: .destructive) {
                            viewModel.deleteServer(server)
                            dismiss()
                        } label: {
                            Text("删除服务器")
                        }
                    }
                }
            }
            .navigationTitle("编辑外部控制器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let updatedServer = ClashServer(
                            id: server.id,
                            name: name,
                            url: url,
                            port: port,
                            secret: secret,
                            status: server.status,
                            version: server.version,
                            useSSL: useSSL,
                            isQuickLaunch: server.isQuickLaunch
                        )
                        viewModel.updateServer(updatedServer)
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