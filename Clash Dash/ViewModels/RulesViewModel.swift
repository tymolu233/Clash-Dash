import Foundation

class RulesViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var isLoading = true
    @Published var rules: [Rule] = []
    @Published var providers: [RuleProvider] = []
    @Published var isRefreshingAll = false  // 添加更新全部状态标记
    
    let server: ClashServer
    
    struct Rule: Codable, Identifiable, Hashable {
        let type: String
        let payload: String
        let proxy: String
        let size: Int?  // 改为可选类型，适配原版 Clash 内核
        
        var id: String { "\(type)-\(payload)" }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: Rule, rhs: Rule) -> Bool {
            lhs.id == rhs.id
        }
        
        var sectionKey: String {
            let firstChar = String(payload.prefix(1)).uppercased()
            return firstChar.first?.isLetter == true ? firstChar : "#"
        }
    }
    
    struct RuleProvider: Codable, Identifiable {
        var name: String
        let behavior: String
        let type: String
        let ruleCount: Int
        let updatedAt: String
        let format: String?  // 改为可选类型
        let vehicleType: String
        var isRefreshing: Bool = false  // 添加刷新状态标记
        
        var id: String { name }
        
        enum CodingKeys: String, CodingKey {
            case behavior, type, ruleCount, updatedAt, format, vehicleType
            case name
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = ""
            self.behavior = try container.decode(String.self, forKey: .behavior)
            self.type = try container.decode(String.self, forKey: .type)
            self.ruleCount = try container.decode(Int.self, forKey: .ruleCount)
            self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
            self.format = try container.decodeIfPresent(String.self, forKey: .format)  // 使用 decodeIfPresent
            self.vehicleType = try container.decode(String.self, forKey: .vehicleType)
        }
        
        var formattedUpdateTime: String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
            
            guard let date = formatter.date(from: updatedAt) else {
                // 尝试使用备用格式
                let backupFormatter = DateFormatter()
                backupFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS'Z'"
                backupFormatter.timeZone = TimeZone(identifier: "UTC")
                
                guard let backupDate = backupFormatter.date(from: updatedAt) else {
                    return "未知"
                }
                return formatRelativeTime(from: backupDate)
            }
            
            return formatRelativeTime(from: date)
        }
        
        private func formatRelativeTime(from date: Date) -> String {
            let now = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
            
            if let years = components.year, years > 0 {
                return "\(years)年前"
            }
            if let months = components.month, months > 0 {
                return "\(months)个月前"
            }
            if let days = components.day, days > 0 {
                return "\(days)天前"
            }
            if let hours = components.hour, hours > 0 {
                return "\(hours)小时前"
            }
            if let minutes = components.minute, minutes > 0 {
                return "\(minutes)分钟前"
            }
            return "刚刚"
        }
    }
    
    init(server: ClashServer) {
        self.server = server
        Task { await fetchData() }
    }
    
    @MainActor
    func fetchData() async {
        isLoading = true
        defer { isLoading = false }
        
        // 获取规则
        if let rulesData = try? await fetchRules() {
            self.rules = rulesData.rules
        }
        
        // 获取规则提供者
        if let providersData = try? await fetchProviders() {
            self.providers = providersData.providers.map { name, provider in
                var provider = provider
                provider.name = name
                return provider
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }  // 按名称排序
        }
    }
    
    private func fetchRules() async throws -> RulesResponse {
        guard let url = server.clashBaseURL?.appendingPathComponent("rules") else {
            throw URLError(.badURL)
        }
        print("🔐 规则请求 URL: \(url.absoluteString)")
        print("🔐 SSL设置: clashUseSSL = \(server.clashUseSSL)")
        print("🔐 OpenWRT SSL设置: openWRTUseSSL = \(server.openWRTUseSSL)")
        print("🔐 服务器类型: \(server.source.rawValue)")
        print("🔐 服务器源: \(server.source)")
        print("🔐 服务器 URL: \(server.url)")
        print("🔐 服务器端口: \(server.port)")
        
        var request = try server.makeRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await URLSession.secure.data(for: request)
        return try JSONDecoder().decode(RulesResponse.self, from: data)
    }
    
    private func fetchProviders() async throws -> ProvidersResponse {
        guard let url = server.clashBaseURL?.appendingPathComponent("providers/rules") else {
            throw URLError(.badURL)
        }
        print("🔐 规则提供者请求 URL: \(url.absoluteString)")
        print("🔐 SSL设置: clashUseSSL = \(server.clashUseSSL)")
        print("🔐 OpenWRT SSL设置: openWRTUseSSL = \(server.openWRTUseSSL)")
        print("🔐 服务器类型: \(server.source.rawValue)")
        print("🔐 服务器源: \(server.source)")
        print("🔐 服务器 URL: \(server.url)")
        print("🔐 服务器端口: \(server.port)")
        
        var request = try server.makeRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await URLSession.secure.data(for: request)
        return try JSONDecoder().decode(ProvidersResponse.self, from: data)
    }
    
    @MainActor
    func refreshProvider(_ name: String) async {
        do {
            // 找到要刷新的提供者
//            guard let provider = providers.first(where: { $0.name == name }) else {
//                return
//            }
            
            // 更新该提供者的加载状态
            if let index = providers.firstIndex(where: { $0.name == name }) {
                providers[index].isRefreshing = true
            }
            
            // 构建刷新 URL
            guard let baseURL = server.baseURL else {
                throw URLError(.badURL)
            }
            
            let url = baseURL
                .appendingPathComponent("providers")
                .appendingPathComponent("rules")
                .appendingPathComponent(name)
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (_, response) = try await URLSession.secure.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 {
                    await fetchData()
                }
            }
        } catch {
            // 错误处理但不打印
        }
        
        // 重置刷新状态
        if let index = providers.firstIndex(where: { $0.name == name }) {
            providers[index].isRefreshing = false
        }
    }
    
    @MainActor
    func refreshAllProviders() async {
        guard !isRefreshingAll else { return }  // 防止重复刷新
        
        isRefreshingAll = true
        
        for provider in providers {
            await refreshProvider(provider.name)
        }
        
        isRefreshingAll = false
    }
}

// Response models
struct RulesResponse: Codable {
    let rules: [RulesViewModel.Rule]
}

struct ProvidersResponse: Codable {
    let providers: [String: RulesViewModel.RuleProvider]
} 
