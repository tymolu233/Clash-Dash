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
    @State private var editingRule: OpenClashRule?
    @State private var isCustomRulesEnabled = false
    @State private var showingHelp = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: 200)
                } else {
                    VStack {
                        if rules.isEmpty {
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
                                            editingRule = rule  // 设置要编辑的规则，触发编辑视图
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
                                                  systemImage: rule.isEnabled ? "livephoto.slash" : "livephoto")
                                        }
                                        .tint(rule.isEnabled ? .orange : .green)
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                        }
                    }
                    .navigationTitle("覆写规则")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("关闭", action: { dismiss() })
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HStack(spacing: 16) {
                                Button {
                                    showingHelp = true
                                } label: {
                                    Image(systemName: "info.circle")
                                }
                                
                                Toggle("", isOn: $isCustomRulesEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                                    .onChange(of: isCustomRulesEnabled) { newValue in
                                        Task {
                                            await toggleCustomRules(enabled: newValue)
                                        }
                                    }
                                
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
            .sheet(isPresented: $showingAddSheet) {
                RuleEditView(server: server) { rule in
                    Task {
                        await addRule(rule)
                    }
                }
            }
            .sheet(item: $editingRule) { rule in
                RuleEditView(title: "编辑规则", rule: rule, server: server) { updatedRule in
                    Task {
                        await updateRule(updatedRule)
                    }
                }
            }
            .sheet(isPresented: $showingHelp) {
                OpenClashRulesHelpView()
            }
        }
    }
    
    private func loadRules() async {
        print("🔄 开始加载规则...")
        isLoading = true
        defer { 
            isLoading = false
            print("✅ 规则加载完成")
        }
        
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            print("❌ 错误: 未设置 OpenWRT 用户名或密码")
            errorMessage = "未设置 OpenWRT 用户名或密码"
            showError = true
            return
        }
        
        do {
            print("🔑 正在获取认证 token...")
            let token = try await viewModel.getAuthToken(server, username: username, password: password)
            print("✅ 成功获取 token")
            
            let scheme = server.openWRTUseSSL ? "https" : "http"
            let baseURL = "\(scheme)://\(server.openWRTUrl):\(server.openWRTPort ?? "80")"
            
            // 获取自定义规则启用状态
            guard let statusUrl = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
                errorMessage = "无效的服务器地址"
                showError = true
                return
            }
            
            var statusRequest = URLRequest(url: statusUrl)
            statusRequest.httpMethod = "POST"
            statusRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let statusPayload: [String: Any] = [
                "method": "exec",
                "params": ["uci get openclash.config.enable_custom_clash_rules"]
            ]
            
            statusRequest.httpBody = try JSONSerialization.data(withJSONObject: statusPayload)
            
            let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
            if let statusResponse = try? JSONDecoder().decode(OpenClashRuleResponse.self, from: statusData),
               let statusResult = statusResponse.result {
                let enabled = statusResult.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
                await MainActor.run {
                    self.isCustomRulesEnabled = enabled
                }
                print("📍 自定义规则状态: \(enabled ? "启用" : "禁用")")
            }
            
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
                print("❌ 服务器返回错误: \(error)")
                errorMessage = "服务器错误: \(error)"
                showError = true
                return
            }
            
            guard let result = response.result else {
                print("❌ 服务器返回空结果")
                errorMessage = "服务器返回空结果"
                showError = true
                return
            }
            
            // 添加日志查看服务器返回的原始内容
            print("📥 服务器返回的原始内容:\n\(result)")
            
            // 解析规则
            let ruleLines = result.components(separatedBy: CharacterSet.newlines)
            print("📝 开始解析规则，总行数: \(ruleLines.count)")
            
            var parsedRules: [OpenClashRule] = []
            var isInRulesSection = false
            
            for (index, line) in ruleLines.enumerated() {
                let trimmedLine = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if trimmedLine == "rules:" {
                    isInRulesSection = true
                    print("✅ 在第 \(index) 行找到 rules: 标记")
                    continue
                }
                
                if isInRulesSection {
                    if trimmedLine.hasPrefix("-") || trimmedLine.hasPrefix("##-") {
                        print("🔍 解析规则行: \(trimmedLine)")
                        let rule = OpenClashRule(from: trimmedLine)
                        if !rule.type.isEmpty {
                            parsedRules.append(rule)
                            print("✅ 成功解析规则: \(rule.target)")
                        } else {
                            print("⚠️ 规则解析失败: \(trimmedLine)")
                        }
                    }
                }
            }
            
            print("📊 规则解析完成，找到 \(parsedRules.count) 条有效规则")
            
            await MainActor.run {
                self.rules = parsedRules
            }
            
            print("📝 解析到 \(parsedRules.count) 条规则")
            
        } catch {
            print("❌ 错误: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func generateRulesContent() -> String {
        // 添加日志来查看生成的内容
        var content = "rules:\n"
        for rule in rules {
            let prefix = rule.isEnabled ? "- " : "##- "
            let comment = rule.comment.map { " #\($0)" } ?? ""
            content += "\(prefix)\(rule.type),\(rule.target),\(rule.action)\(comment)\n"
        }
        print("📄 生成的规则内容:\n\(content)")  // 添加这行来查看生成的内容
        return content
    }
    
    private func saveRules() async throws {
        print("💾 开始保存规则...")
        isProcessing = true
        defer { 
            isProcessing = false 
            print("✅ 规则保存完成")
        }
        
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
        }
        
        let scheme = server.openWRTUseSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.openWRTUrl):\(server.openWRTPort ?? "80")"
        
        // 使用 viewModel 获取 token
        let token = try await viewModel.getAuthToken(server, username: username, password: password)
        
        // 构建请求
        guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
            throw NetworkError.invalidURL
        }
        
        // 生成规则内容
        let content = generateRulesContent()
        print("📄 准备写入的内容:\n\(content)")
        
        // 构建写入命令，使用 echo 直接写入
        let filePath = "/etc/openclash/custom/openclash_custom_rules.list"
        let escapedContent = content.replacingOccurrences(of: "'", with: "'\\''")
        let cmd = "echo '\(escapedContent)' > \(filePath) 2>&1 && echo '写入成功' || echo '写入失败'"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
        
        let command: [String: Any] = [
            "method": "exec",
            "params": [cmd]
        ]
        
        print("📝 执行命令: \(cmd)")
        request.httpBody = try JSONSerialization.data(withJSONObject: command)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 添加响应状态码日志
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 服务器响应状态码: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 服务器响应内容: \(responseString)")
                
                if let responseData = try? JSONDecoder().decode(OpenClashRuleResponse.self, from: data) {
                    if let error = responseData.error {
                        print("❌ 服务器返回错误: \(error)")
                        throw NetworkError.serverError(500)
                    }
                    if let result = responseData.result {
                        print("📄 命令执行结果: \(result)")
                        if result.contains("写入失败") {
                            throw NetworkError.serverError(500)
                        }
                    }
                    
                    // 验证文件内容
                    let verifyCmd = "cat \(filePath)"
                    let verifyPayload: [String: Any] = [
                        "method": "exec",
                        "params": [verifyCmd]
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: verifyPayload)
                    
                    let (verifyData, _) = try await URLSession.shared.data(for: request)
                    if let verifyResponse = try? JSONDecoder().decode(OpenClashRuleResponse.self, from: verifyData),
                       let verifyResult = verifyResponse.result {
                        print("✅ 文件内容验证:\n\(verifyResult)")
                    }
                }
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            print("❌ 服务器返回错误状态码: \(statusCode)")
            throw NetworkError.serverError(statusCode)
        }
    }
    
    private func toggleRule(_ rule: OpenClashRule) async {
        print("🔄 切换规则态: \(rule.target) - 当前状态: \(rule.isEnabled)")
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { 
            print("❌ 未找到要切换的规则")
            return 
        }
        
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
        print("🗑️ 删除规则: \(rule.target)")
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { 
            print("❌ 未找到要删除的规则")
            return 
        }
        
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
            return .cyan          // XX用于源IP
        case "DST-PORT":
            return .teal         // 青色用于目标端口
        case "SRC-PORT":
            return .mint         // 薄荷色用于源端口
        default:
            return .secondary
        }
    }
    
    private func addRule(_ rule: OpenClashRule) async {
        print("➕ 添加新规则: \(rule.target)")
        rules.insert(rule, at: 0)
        do {
            try await saveRules()
            print("✅ 规则添加成功")
        } catch {
            rules.removeFirst()
            print("❌ 规则添加失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func updateRule(_ rule: OpenClashRule) async {
        print("📝 更新规则: \(rule.target)")
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { 
            print("❌ 未找到要更新的规则")
            return 
        }
        let originalRule = rules[index]
        rules[index] = rule
        
        do {
            try await saveRules()
        } catch {
            rules[index] = originalRule
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func toggleCustomRules(enabled: Bool) async {
        print("🔄 切换自定义规则状态: \(enabled)")
        isProcessing = true
        defer { isProcessing = false }
        
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            errorMessage = "未设置 OpenWRT 用户名或密码"
            showError = true
            return
        }
        
        do {
            let token = try await viewModel.getAuthToken(server, username: username, password: password)
            let scheme = server.openWRTUseSSL ? "https" : "http"
            let baseURL = "\(scheme)://\(server.openWRTUrl):\(server.openWRTPort ?? "80")"
            
            guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
                throw NetworkError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // 设置启用状态
            let setCmd = "uci set openclash.config.enable_custom_clash_rules='\(enabled ? "1" : "0")' && uci commit openclash"
            let payload: [String: Any] = [
                "method": "exec",
                "params": [setCmd]
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 服务器响应: \(responseString)")
            }
            
            // 重启 OpenClash 服务使配置生效
            // let restartCmd = "/etc/init.d/openclash restart"
            // let restartPayload: [String: Any] = [
            //     "method": "exec",
            //     "params": [restartCmd]
            // ]
            
            // request.httpBody = try JSONSerialization.data(withJSONObject: restartPayload)
            
            // let (_, restartResponse) = try await URLSession.shared.data(for: request)
            
            // guard let restartHttpResponse = restartResponse as? HTTPURLResponse,
            //       restartHttpResponse.statusCode == 200 else {
            //     throw NetworkError.serverError((restartResponse as? HTTPURLResponse)?.statusCode ?? 500)
            // }
            
            print("✅ 自定义规则状态已更新为: \(enabled ? "启用" : "禁用")")
            
        } catch {
            print("❌ 切换自定义规则状态失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
            // 恢复UI状态
            await MainActor.run {
                self.isCustomRulesEnabled = !enabled
            }
        }
    }
}

struct OpenClashRuleResponse: Codable {
    let result: String?
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
            return .cyan          // XX用于源IP
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
                      systemImage: rule.isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
            }
            .tint(rule.isEnabled ? .green : .orange)
        }
    }
}
