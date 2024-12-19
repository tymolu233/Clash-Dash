import SwiftUI

struct OpenClashRulesView: View {
    let server: ClashServer
    @State private var rules: [OpenClashRule] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            ForEach(rules) { rule in
                HStack {
                    // 左侧目标
                    Text(rule.target)
                        .foregroundColor(rule.isEnabled ? .primary : .secondary)
                    
                    Spacer()
                    
                    // 右侧类型和动作
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(rule.type)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(rule.action)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .opacity(rule.isEnabled ? 1 : 0.6)
            }
        }
        .navigationTitle("覆写规则")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRules()
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .alert("加载错误", isPresented: .constant(errorMessage != nil)) {
            Button("确定") {
                errorMessage = nil
            }
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
            return
        }
        
        do {
            // 构建认证请求
            let scheme = server.useSSL ? "https" : "http"
            let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
            
            // 1. 获取认证令牌
            guard let loginURL = URL(string: "\(baseURL)/cgi-bin/luci/rpc/auth") else {
                errorMessage = "无效的服务器地址"
                return
            }
            
            var loginRequest = URLRequest(url: loginURL)
            loginRequest.httpMethod = "POST"
            loginRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let loginPayload: [String: Any] = [
                "id": 1,
                "method": "login",
                "params": [username, password]
            ]
            
            loginRequest.httpBody = try JSONSerialization.data(withJSONObject: loginPayload)
            
            let (loginData, _) = try await URLSession.shared.data(for: loginRequest)
            let authResponse = try JSONDecoder().decode(OpenWRTAuthResponse.self, from: loginData)
            
            guard let token = authResponse.result, !token.isEmpty else {
                if let error = authResponse.error {
                    errorMessage = "认证失败: \(error)"
                    return
                }
                errorMessage = "认证失败: 服务器未返回有效的认证令牌"
                return
            }
            
            // 2. 获取规则内容
            guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
                errorMessage = "无效的服务器地址"
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