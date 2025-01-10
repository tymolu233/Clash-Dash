import SwiftUI

struct RestartServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ServerViewModel
    let server: ClashServer
    
    @State private var logs: [String] = []
    @State private var isRestarting = false
    @State private var error: Error?
    @State private var showConfirmation = true
    @State private var isRestartSuccessful = false
    
    init(viewModel: ServerViewModel, server: ClashServer) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.server = server
    }
    
    private func logColor(_ log: String) -> Color {
        if log.contains("警告") {
            return .orange
        } else if log.contains("错误") {
            return .red
        }else if log.contains("提示") {
            return .yellow
        } else if log.contains("成功") {
            return .green
        }
        return .secondary
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(logs.reversed(), id: \.self) { log in
                            Text(log)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(logColor(log))
                                .textSelection(.enabled)
                                .padding(.horizontal)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: logs) { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(logs.first, anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("重启服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    if isRestartSuccessful {
                        Label("重启成功", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .alert("确认重启", isPresented: $showConfirmation) {
            Button("取消", role: .cancel) {
                dismiss()
            }
            Button("确认重启", role: .destructive) {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await restartService()
                }
            }
        } message: {
            Text("重启 OpenClash 服务将导致：\n\n1. 所有当前连接会被中断\n2. 服务在重启期间不可用\n\n是否确认重启？")
        }
        .alert("错误", isPresented: .constant(error != nil)) {
            Button("确定") {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func restartService() async {
        isRestarting = true
        isRestartSuccessful = false
        logs.removeAll()
        
        do {
            // 1. 先发送重启命令
            let stream = try await viewModel.restartOpenClash(
                server,
                packageName: server.luciPackage == .openClash ? "openclash" : "mihomoTProxy",
                isSubscription: false
            )
            
            // 2. 开始轮询日志
            let scheme = server.openWRTUseSSL ? "https" : "http"
            guard let openWRTUrl = server.openWRTUrl else {
                throw NetworkError.invalidURL
            }
            let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
            
            guard let username = server.openWRTUsername,
                  let password = server.openWRTPassword else {
                throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
            }
            
            // 获取认证令牌
            let token = try await viewModel.getAuthToken(server, username: username, password: password)
            
            // 3. 持续获取日志，直到服务完全启动或超时
            var retryCount = 0
            let maxRetries = 300 // 最多尝试300次，每次0.1秒
            
            while retryCount < maxRetries {
                let random = Int.random(in: 1...1000000000)
                guard let logURL = URL(string: "\(baseURL)/cgi-bin/luci/admin/services/openclash/startlog?\(random)") else {
                    throw NetworkError.invalidURL
                }
                
                var logRequest = URLRequest(url: logURL)
                logRequest.setValue("sysauth_http=\(token); sysauth=\(token)", forHTTPHeaderField: "Cookie")
                
                let (logData, _) = try await URLSession.shared.data(for: logRequest)
                let logResponse = try JSONDecoder().decode(StartLogResponse.self, from: logData)
                
                if !logResponse.startlog.isEmpty {
                    let newLogs = logResponse.startlog
                        .components(separatedBy: "\n")
                        .filter { !$0.isEmpty }
                    
                    for log in newLogs {
                        if !logs.contains(log) {
                            withAnimation {
                                logs.append(log)
                            }
                            
                            // 检查重启成功标记
                            if log.contains("第九步") || log.contains("第八步") || log.contains("启动成功") {
                                // 等待2秒后标记成功
                                try await Task.sleep(nanoseconds: 2_000_000_000)
                                isRestartSuccessful = true
                                isRestarting = false
                                
                                // 再等待1秒后关闭sheet
                                try await Task.sleep(nanoseconds: 1_000_000_000)
                                await MainActor.run {
                                    dismiss()
                                }
                                return
                            }
                        }
                    }
                }
                
                retryCount += 1
                try await Task.sleep(nanoseconds: 100_000_000) // 等待0.1秒
            }
            
            // 如果超时，添加提示信息
            withAnimation {
                logs.append("⚠️ 获取日志超时，请自行检查服务状态")
            }
            
        } catch {
            self.error = error
        }
        
        isRestarting = false
    }
}

