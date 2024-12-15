import Foundation

@MainActor
class ConfigSubscriptionViewModel: ObservableObject {
    @Published var subscriptions: [ConfigSubscription] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let server: ClashServer
    
    init(server: ClashServer) {
        self.server = server
    }
    
    func loadSubscriptions() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            subscriptions = try await fetchSubscriptions()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func fetchSubscriptions() async throws -> [ConfigSubscription] {
        let token = try await getAuthToken()
        
        // 构建请求
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sysauth=\(token)", forHTTPHeaderField: "Cookie")
        
        let command: [String: Any] = [
            "method": "exec",
            "params": ["uci show openclash | grep \"config_subscribe\" | sed 's/openclash\\.//g' | sort"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: command)
        
        let session = URLSession.shared
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(500)
        }
        
        struct UCIResponse: Codable {
            let result: String
            let error: String?
        }
        
        let uciResponse = try JSONDecoder().decode(UCIResponse.self, from: data)
        if let error = uciResponse.error, !error.isEmpty {
            throw NetworkError.serverError(500)
        }
        
        // 解析结果
        var subscriptions: [ConfigSubscription] = []
        var currentId: Int?
        var currentSub = ConfigSubscription(id: 0, name: "", address: "", enabled: true, subUA: "Clash", subConvert: false)
        
        let lines = uciResponse.result.components(separatedBy: "\n")
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            
            let key = String(parts[0])
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            value = value.replacingOccurrences(of: "'", with: "")
            
            if key.hasPrefix("@config_subscribe[") {
                if let idStr = key.firstMatch(of: /\[(\d+)\]/)?.1,
                   let id = Int(idStr) {
                    if id != currentId {
                        if currentId != nil {
                            subscriptions.append(currentSub)
                        }
                        currentId = id
                        currentSub = ConfigSubscription(id: id, name: "", address: "", enabled: true, subUA: "Clash", subConvert: false)
                    }
                    
                    if key.contains(".name") {
                        currentSub.name = value
                    } else if key.contains(".address") {
                        currentSub.address = value
                    } else if key.contains(".enabled") {
                        currentSub.enabled = value == "1"
                    } else if key.contains(".sub_ua") {
                        currentSub.subUA = value
                    } else if key.contains(".sub_convert") {
                        currentSub.subConvert = value == "1"
                    } else if key.contains(".keyword") {
                        currentSub.keyword = value
                    } else if key.contains(".ex_keyword") {
                        currentSub.exKeyword = value
                    }
                }
            }
        }
        
        if currentId != nil {
            subscriptions.append(currentSub)
        }
        
        return subscriptions
    }
    
    private func getAuthToken() async throws -> String {
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            throw NetworkError.unauthorized
        }
        
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/auth") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "id": 1,
            "method": "login",
            "params": [username, password]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.unauthorized
        }
        
        struct AuthResponse: Codable {
            let result: String?
            let error: String?
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        guard let token = authResponse.result else {
            throw NetworkError.unauthorized
        }
        
        return token
    }
    
    func addSubscription(_ subscription: ConfigSubscription) async {
        // TODO: 实现添加订阅的逻辑
    }
    
    func updateSubscription(_ subscription: ConfigSubscription) async {
        // TODO: 实现更新订阅的逻辑
    }
    
    func toggleSubscription(_ subscription: ConfigSubscription, enabled: Bool) async {
        // TODO: 实现启用/禁用订阅的逻辑
    }
} 