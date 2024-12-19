import SwiftUI

struct OpenClashRulesView: View {
    let server: ClashServer
    @StateObject private var viewModel = ServerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var rules: [OpenClashRule] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAddSheet = false
    @State private var showError = false
    @State private var isUpdating = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: 200)
                } else if rules.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.bottom, 10)
                        
                        Text("没有规则")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("点击添加按钮来添加一个新的规则")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding(.top, 40)
                } else {
                    List {
                        ForEach(rules) { rule in
                            HStack(spacing: 12) {
                                // 左侧：目标
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rule.target)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(rule.isEnabled ? .primary : .secondary)
                                        .lineLimit(1)
                                    
                                    if let comment = rule.comment {
                                        Text(comment)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                // 右侧：类型和动作
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(rule.type)
                                        .font(.caption)
                                        .foregroundColor(typeColor(for: rule.type))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(typeColor(for: rule.type).opacity(0.12))
                                        .cornerRadius(4)
                                    
                                    Text(rule.action)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                            .opacity(rule.isEnabled ? 1 : 0.6)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task {
                                        await deleteRule(rule)
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button {
                                    // TODO: 实现编辑功能
                                    print("编辑规则: \(rule.target)")
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                                
                                Button {
                                    Task {
                                        await toggleRule(rule)
                                    }
                                } label: {
                                    Label(rule.isEnabled ? "禁用" : "启用", 
                                          systemImage: rule.isEnabled ? "eye.slash" : "eye")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("覆写规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", action: { dismiss() })
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        // 更新按钮
                        Button {
                            Task {
                                await loadRules()
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .disabled(isUpdating)
                        
                        // 添加按钮
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .overlay {
                if isUpdating {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.8))
                }
            }
        }
        .task {
            await loadRules()
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func loadRules() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            errorMessage = "未设置 OpenWRT 用户名或密码"
            showError = true
            return
        }
        
        do {
            // 使用 viewModel 获取 token
            let token = try await viewModel.getAuthToken(server, username: username, password: password)
            
            let scheme = server.useSSL ? "https" : "http"
            let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
            
            // 获取规则内容
            guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
                errorMessage = "无效的服务器地址"
                showError = true
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let payload: [String: Any] = [
                "method": "exec",
                "params": ["cat /etc/openclash/custom/openclash_custom_rules.list"]
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(OpenClashRuleResponse.self, from: data)
            
            if let error = response.error {
                errorMessage = "服务器错误: \(error)"
                showError = true
                return
            }
            
            // 解析规则
            let ruleLines = response.result.components(separatedBy: CharacterSet.newlines)
            var parsedRules: [OpenClashRule] = []
            
            var isInRulesSection = false
            for line in ruleLines {
                let trimmedLine = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if trimmedLine == "rules:" {
                    isInRulesSection = true
                    continue
                }
                
                if isInRulesSection {
                    if trimmedLine.hasPrefix("-") || trimmedLine.hasPrefix("##-") {
                        let rule = OpenClashRule(from: trimmedLine)
                        if !rule.type.isEmpty {
                            parsedRules.append(rule)
                        }
                    }
                }
            }
            
            await MainActor.run {
                self.rules = parsedRules
            }
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func generateRulesContent() -> String {
        var content = "rules:\n"
        for rule in rules {
            let prefix = rule.isEnabled ? "- " : "##- "
            let comment = rule.comment.map { " #\($0)" } ?? ""
            content += "\(prefix)\(rule.type),\(rule.target),\(rule.action)\(comment)\n"
        }
        return content
    }
    
    private func saveRules() async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
        }
        
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        
        // 使用 viewModel 获取 token
        let token = try await viewModel.getAuthToken(server, username: username, password: password)
        
        // 构建请求
        guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
            throw NetworkError.invalidURL
        }
        
        // 生成规则内容
        let content = generateRulesContent()
        
        // 将内容转换为 base64
        guard let contentData = content.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }
        let base64Content = contentData.base64EncodedString()
        
        // 构建写入命令
        let filePath = "/etc/openclash/custom/openclash_custom_rules.list"
        let cmd = "echo '\(base64Content)' | base64 -d | tee \(filePath) >/dev/null 2>&1"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sysauth=\(token)", forHTTPHeaderField: "Cookie")
        
        let command: [String: Any] = [
            "method": "exec",
            "params": [cmd]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: command)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
    }
    
    private func toggleRule(_ rule: OpenClashRule) async {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        
        let updatedRule = rule.toggled()
        let originalRule = rules[index]
        rules[index] = updatedRule
        
        do {
            try await saveRules()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            // 恢复原始状态
            rules[index] = originalRule
        }
    }
    
    private func deleteRule(_ rule: OpenClashRule) async {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        
        let originalRules = rules
        rules.remove(at: index)
        
        do {
            try await saveRules()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            // 恢复原始状态
            rules = originalRules
        }
    }
    
    private func typeColor(for type: String) -> Color {
        switch type {
        case "DOMAIN":
            return .purple        // 纯紫色用于精确域名匹配
        case "DOMAIN-SUFFIX":
            return .indigo       // 靛蓝色用于域名后缀
        case "DOMAIN-KEYWORD":
            return .blue         // 蓝色用于域名关键字
        case "PROCESS-NAME":
            return .green        // 绿色用于进程名
        case "IP-CIDR":
            return .orange       // 橙色用于目标IP
        case "SRC-IP-CIDR":
            return .red          // 红色用于源IP
        case "DST-PORT":
            return .teal         // 青色用于目标端口
        case "SRC-PORT":
            return .mint         // 薄荷色用于源端口
        default:
            return .secondary
        }
    }
}

struct OpenClashRuleResponse: Codable {
    let result: String
    let error: String?
}

struct OpenWRTAuthResponse: Codable {
    let id: Int?
    let result: String?
    let error: String?
}

struct RuleRowView: View {
    let rule: OpenClashRule
    let onToggle: () async -> Void
    let onEdit: () -> Void
    let onDelete: () async -> Void
    
    private var typeColor: Color {
        switch rule.type {
        case "DOMAIN":
            return .purple        // 纯紫色用于精确域名匹配
        case "DOMAIN-SUFFIX":
            return .indigo       // 靛蓝色用于域名后缀
        case "DOMAIN-KEYWORD":
            return .blue         // 蓝色用于域名关键字
        case "PROCESS-NAME":
            return .green        // 绿色用于进程名
        case "IP-CIDR":
            return .orange       // 橙色用于目标IP
        case "SRC-IP-CIDR":
            return .red          // 红色用于源IP
        case "DST-PORT":
            return .teal         // 青色用于目标端口
        case "SRC-PORT":
            return .mint         // 薄荷色用于源端口
        default:
            return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧：目标
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.target)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(rule.isEnabled ? .primary : .secondary)
                    .lineLimit(1)
                
                if let comment = rule.comment {
                    Text(comment)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 右侧：类型和动作
            VStack(alignment: .trailing, spacing: 4) {
                Text(rule.type)
                    .font(.caption)
                    .foregroundColor(typeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.12))
                    .cornerRadius(4)
                
                Text(rule.action)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .opacity(rule.isEnabled ? 1 : 0.6)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task {
                    await onDelete()
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
            
            Button {
                onEdit()
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
            
            Button {
                Task {
                    await onToggle()
                }
            } label: {
                Label(rule.isEnabled ? "禁用" : "启用", 
                      systemImage: rule.isEnabled ? "eye.slash" : "eye")
            }
            .tint(.orange)
        }
    }
}
