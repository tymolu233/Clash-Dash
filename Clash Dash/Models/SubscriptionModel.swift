import Foundation
import SwiftUI

// 订阅信息响应模型
struct SubInfoResponse: Codable {
    struct SubscriptionInfo: Codable {
        let surplus: String
        let total: String
        let dayLeft: Int
        let used: String
        let expire: String
        let percent: String
        
        enum CodingKeys: String, CodingKey {
            case surplus
            case total
            case dayLeft = "day_left"
            case used
            case expire
            case percent
        }
    }
    
    struct Provider: Codable {
        let subscriptionInfo: SubscriptionInfo
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case subscriptionInfo = "subscription_info"
            case updatedAt = "updated_at"
        }
    }
    
    private let providers: [String: Provider]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var providers: [String: Provider] = [:]
        
        for key in container.allKeys {
            providers[key.stringValue] = try container.decode(Provider.self, forKey: key)
        }
        
        self.providers = providers
    }
    
    var allSubscriptions: [(name: String, provider: Provider)] {
        return providers.map { (name: $0.key, provider: $0.value) }
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
}

// 代理提供者响应模型
struct ProxyProviderResponse: Codable {
    struct Provider: Codable {
        let vehicleType: String?
        let subscriptionInfo: SubscriptionInfo?
    }
    
    struct SubscriptionInfo: Codable {
        let Total: Int64
        let Upload: Int64
        let Download: Int64
        let Expire: TimeInterval
    }
    
    let providers: [String: Provider]
}

// HTTP 客户端协议
protocol HTTPClient {
    func login() async throws -> String
    func makeRequest(method: String, url: URL, headers: [String: String], body: Data?) async throws -> (Data, URLResponse)
}

// 默认 HTTP 客户端实现
class DefaultHTTPClient: HTTPClient {
    private let server: ClashServer
    
    init(server: ClashServer) {
        self.server = server
    }
    
    func login() async throws -> String {
        let scheme = server.openWRTUseSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.openWRTUrl ?? server.url):\(server.openWRTPort ?? server.port)"
        let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/auth")!
             
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginData = [
            "id": 1,
            "method": "login",
            "params": [server.openWRTUsername ?? "root", server.openWRTPassword ?? ""]
        ] as [String : Any]
        
        print("Sending login request to: \(url)")
        
        let loginBody = try JSONSerialization.data(withJSONObject: loginData)
        print("Login request body: \(String(data: loginBody, encoding: .utf8) ?? "")")
        request.httpBody = loginBody
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Login response status code: \(httpResponse.statusCode)")
            print("Login response headers: \(httpResponse.allHeaderFields)")
        }
        
        // 打印接收到的数据
        if let responseString = String(data: data, encoding: .utf8) {
            print("Login response: \(responseString)")
            
            // 检查响应是否为空或无效
            if responseString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Login response is empty"])
            }
            
            // 尝试清理响应数据
            let cleanedResponse = responseString
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 如果清理后的响应不是以 { 开头，可能需要进一步处理
            if !cleanedResponse.hasPrefix("{") {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Login response is not a valid JSON object"])
            }
            
            // 尝试解析响应
            do {
                guard let cleanedData = cleanedResponse.data(using: .utf8) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert cleaned response to data"])
                }
                
                struct LoginResponse: Codable {
                    let id: Int
                    let result: String
                    let error: String?
                }
                
                let response = try JSONDecoder().decode(LoginResponse.self, from: cleanedData)
                
                // 只有当 error 字段存在且不为 null 时才认为是错误
                if let error = response.error {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Login failed: \(error)"])
                }
                
                return response.result
                
            } catch {
                print("Error decoding login response: \(error)")
                if let jsonError = error as? DecodingError {
                    switch jsonError {
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context)")
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context)")
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context)")
                    case .valueNotFound(let type, let context):
                        print("Value of type '\(type)' not found: \(context)")
                    @unknown default:
                        print("Unknown decoding error: \(jsonError)")
                    }
                }
                throw error
            }
        } else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not convert login response data to string"])
        }
    }
    
    func makeRequest(method: String, url: URL, headers: [String: String], body: Data?) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return try await URLSession.shared.data(for: request)
    }
}

// Clash 客户端协议
protocol ClashClient {
    func getCurrentConfig() async throws -> String?
    func getSubscriptionInfo(config: String) async throws -> [String: SubscriptionCardInfo]?
    func getProxyProvider() async throws -> [String: SubscriptionCardInfo]?
}

// OpenClash 客户端实现
class OpenClashClient: ClashClient {
    private let httpClient: HTTPClient
    private let server: ClashServer
    private var token: String?
    
    init(server: ClashServer, httpClient: HTTPClient) {
        self.server = server
        self.httpClient = httpClient
    }
    
    func getCurrentConfig() async throws -> String? {
        if token == nil {
            token = try await httpClient.login()
        }
        
        let scheme = server.openWRTUseSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.openWRTUrl ?? server.url):\(server.openWRTPort ?? server.port)"
        let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys")!
        
        let headers = [
            "Content-Type": "application/json",
            "Cookie": "sysauth=\(token!);sysauth_http=\(token!)"
        ]
        
        let requestData = [
            "method": "exec",
            "params": ["uci get openclash.config.config_path"]
        ] as [String : Any]
        
        print("Getting current config from: \(url)")
        print("Headers: \(headers)")
        print("Request data: \(requestData)")
        
        let body = try JSONSerialization.data(withJSONObject: requestData)
        let (data, response) = try await httpClient.makeRequest(method: "POST", url: url, headers: headers, body: body)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Config response status code: \(httpResponse.statusCode)")
            print("Config response headers: \(httpResponse.allHeaderFields)")
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Config response: \(responseString)")
            
            // 尝试清理响应数据
            let cleanedResponse = responseString
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            do {
                guard let cleanedData = cleanedResponse.data(using: .utf8) else {
                    print("Failed to convert cleaned config response to data")
                    return nil
                }
                
                struct Response: Codable {
                    let result: String
                }
                
                let response = try JSONDecoder().decode(Response.self, from: cleanedData)
                let config = response.result
                    .replacingOccurrences(of: "/etc/openclash/config/", with: "")
                    .replacingOccurrences(of: ".yaml", with: "")
                    .replacingOccurrences(of: ".yml", with: "")
                    .replacingOccurrences(of: "\n", with: "")
                
                print("Parsed config: \(config)")
                return config
                
            } catch {
                print("Error decoding config response: \(error)")
                if let jsonError = error as? DecodingError {
                    switch jsonError {
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context)")
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context)")
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context)")
                    case .valueNotFound(let type, let context):
                        print("Value of type '\(type)' not found: \(context)")
                    @unknown default:
                        print("Unknown decoding error: \(jsonError)")
                    }
                }
                throw error
            }
        } else {
            print("Could not convert config response data to string")
            return nil
        }
    }
    
    struct OpenClashConfigResponse: Codable {
        let config: String
    }
    
    func getSubscriptionInfo(config: String) async throws -> [String: SubscriptionCardInfo]? {
        if token == nil {
            token = try await httpClient.login()
        }
        
        guard !config.isEmpty else {
            return try await getProxyProvider()
        }
        
        let scheme = server.openWRTUseSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.openWRTUrl ?? server.url):\(server.openWRTPort ?? server.port)"
        let randomNumber = String(Int.random(in: 1000000000000...9999999999999))
        let url = URL(string: "\(baseURL)/cgi-bin/luci/admin/services/openclash/sub_info_get")!
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: randomNumber, value: "null"),
            URLQueryItem(name: "filename", value: config)
        ]
        
        let headers = [
            "Cookie": "sysauth=\(token!);sysauth_http=\(token!)",
            "Content-Type": "application/x-www-form-urlencoded; charset=utf-8"
        ]
        
        print("Sending request to: \(urlComponents.url!)")
        print("Headers: \(headers)")
        
        let (data, response) = try await httpClient.makeRequest(method: "GET", url: urlComponents.url!, headers: headers, body: nil)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Response status code: \(httpResponse.statusCode)")
            print("Response headers: \(httpResponse.allHeaderFields)")
        }
        
        // 打印接收到的数据
        if let responseString = String(data: data, encoding: .utf8) {
            print("Received response: \(responseString)")
            
            // 尝试清理响应数据
            let cleanedResponse = responseString
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 尝试解析响应
            do {
                guard let cleanedData = cleanedResponse.data(using: .utf8) else {
                    print("Failed to convert cleaned response to data")
                    return try await getProxyProvider()
                }
                
                struct Response: Codable {
                    let subInfo: String
                    let surplus: String
                    let total: String
                    let dayLeft: Int
                    let used: String
                    let expire: String
                    let percent: String
                    
                    enum CodingKeys: String, CodingKey {
                        case subInfo = "sub_info"
                        case surplus, total, dayLeft = "day_left", used, expire, percent
                    }
                }
                
                let response = try JSONDecoder().decode(Response.self, from: cleanedData)
                
                if response.subInfo == "Successful" {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    guard let expireDate = dateFormatter.date(from: response.expire) else {
                        print("Failed to parse expire date: \(response.expire)")
                        return try await getProxyProvider()
                    }
                    
                    return [
                        config: SubscriptionCardInfo(
                            name: config,
                            expiryDate: expireDate,
                            lastUpdateTime: Date(),
                            usedTraffic: parseTrafficString(response.used),
                            totalTraffic: parseTrafficString(response.total)
                        )
                    ]
                }
                
                return try await getProxyProvider()
                
            } catch {
                print("Error decoding cleaned response: \(error)")
                if let jsonError = error as? DecodingError {
                    switch jsonError {
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context)")
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context)")
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context)")
                    case .valueNotFound(let type, let context):
                        print("Value of type '\(type)' not found: \(context)")
                    @unknown default:
                        print("Unknown decoding error: \(jsonError)")
                    }
                }
                return try await getProxyProvider()
            }
        } else {
            print("Could not convert response data to string")
            return try await getProxyProvider()
        }
    }
    
    func getProxyProvider() async throws -> [String: SubscriptionCardInfo]? {
        let scheme = server.clashUseSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.port)"
        let url = URL(string: "\(baseURL)/providers/proxies")!
        
        let headers = [
            "Authorization": "Bearer \(server.secret)",
            "Content-Type": "application/json"
        ]
        
        let (data, _) = try await httpClient.makeRequest(method: "GET", url: url, headers: headers, body: nil)
        let response = try JSONDecoder().decode(ProxyProviderResponse.self, from: data)
        
        var result: [String: SubscriptionCardInfo] = [:]
        
        for (name, provider) in response.providers {
            if let vehicleType = provider.vehicleType,
               ["HTTP", "FILE"].contains(vehicleType.uppercased()),
               let subInfo = provider.subscriptionInfo {
                
                let total = Double(subInfo.Total) / (1024 * 1024 * 1024)
                let used = Double(subInfo.Upload + subInfo.Download) / (1024 * 1024 * 1024)
                let expireDate = Date(timeIntervalSince1970: subInfo.Expire)
                
                result[name] = SubscriptionCardInfo(
                    name: name,
                    expiryDate: expireDate,
                    lastUpdateTime: Date(),
                    usedTraffic: used * 1024 * 1024 * 1024,
                    totalTraffic: total * 1024 * 1024 * 1024
                )
            }
        }
        
        return result
    }
    
    private func parseTrafficString(_ traffic: String) -> Double {
        let components = traffic.split(separator: " ")
        guard components.count == 2,
              let value = Double(components[0]) else {
            return 0
        }
        
        let unit = String(components[1]).uppercased()
        switch unit {
        case "GB":
            return value * 1024 * 1024 * 1024
        case "MB":
            return value * 1024 * 1024
        case "KB":
            return value * 1024
        default:
            return value
        }
    }
}

// Mihomo 客户端实现
class MihomoClient: ClashClient {
    private let httpClient: HTTPClient
    private let server: ClashServer
    private var token: String?
    
    init(server: ClashServer, httpClient: HTTPClient) {
        self.server = server
        self.httpClient = httpClient
    }
    
    func getCurrentConfig() async throws -> String? {
        if token == nil {
            token = try await httpClient.login()
        }
        
        let scheme = server.openWRTUseSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.openWRTUrl ?? server.url):\(server.openWRTPort ?? server.port)"
        let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys")!
        
        let headers = [
            "Content-Type": "application/json",
            "Cookie": "sysauth=\(token!);sysauth_http=\(token!)"
        ]
        
        let requestData = [
            "id": 1,
            "method": "exec",
            "params": ["uci get mihomo.config.profile"]
        ] as [String : Any]
        
        print("Getting current config from: \(url)")
        print("Headers: \(headers)")
        print("Request data: \(requestData)")
        
        let body = try JSONSerialization.data(withJSONObject: requestData)
        let (data, response) = try await httpClient.makeRequest(method: "POST", url: url, headers: headers, body: body)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Config response status code: \(httpResponse.statusCode)")
            print("Config response headers: \(httpResponse.allHeaderFields)")
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Config response: \(responseString)")
            
            // 尝试清理响应数据
            let cleanedResponse = responseString
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            do {
                guard let cleanedData = cleanedResponse.data(using: .utf8) else {
                    print("Failed to convert cleaned config response to data")
                    return nil
                }
                
                struct Response: Codable {
                    let result: String
                }
                
                let response = try JSONDecoder().decode(Response.self, from: cleanedData)
                let result = response.result
                    .replacingOccurrences(of: "\\u000a", with: "")
                    .replacingOccurrences(of: "\n", with: "")
                
                print("Parsed result: \(result)")
                
                let parts = result.split(separator: ":")
                let config = parts.count > 1 && parts[0] == "subscription" ? String(parts[1]) : nil
                print("Final config: \(config ?? "nil")")
                return config
                
            } catch {
                print("Error decoding config response: \(error)")
                if let jsonError = error as? DecodingError {
                    switch jsonError {
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context)")
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context)")
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context)")
                    case .valueNotFound(let type, let context):
                        print("Value of type '\(type)' not found: \(context)")
                    @unknown default:
                        print("Unknown decoding error: \(jsonError)")
                    }
                }
                throw error
            }
        } else {
            print("Could not convert config response data to string")
            return nil
        }
    }
    
    struct MihomoConfigResponse: Codable {
        let result: String
    }
    
    struct MihomoSubscriptionData {
        let name: String
        let available: String
        let total: String
        let used: String
        let expire: String
        
        static func parse(from result: String) -> MihomoSubscriptionData? {
            var data: [String: String] = [:]
            let lines = result.split(separator: "\n")
            
            for line in lines {
                let parts = line.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0].split(separator: ".").last ?? "")
                    let value = String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
                    data[key] = value
                }
            }
            
            guard let name = data["name"],
                  let available = data["avaliable"],
                  let total = data["total"],
                  let used = data["used"],
                  let expire = data["expire"] else {
                return nil
            }
            
            return MihomoSubscriptionData(
                name: name,
                available: available,
                total: total,
                used: used,
                expire: expire
            )
        }
    }
    
    func getSubscriptionInfo(config: String) async throws -> [String: SubscriptionCardInfo]? {
        if token == nil {
            token = try await httpClient.login()
        }
        
        guard !config.isEmpty else {
            return try await getProxyProvider()
        }
        
        let scheme = server.openWRTUseSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.openWRTUrl ?? server.url):\(server.openWRTPort ?? server.port)"
        let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys")!
        
        let headers = [
            "Content-Type": "application/json",
            "Cookie": "sysauth=\(token!);sysauth_http=\(token!)"
        ]
        
        let requestData = [
            "id": 1,
            "method": "exec",
            "params": ["uci show mihomo.\(config)"]
        ] as [String : Any]
        
        let body = try JSONSerialization.data(withJSONObject: requestData)
        let (data, _) = try await httpClient.makeRequest(method: "POST", url: url, headers: headers, body: body)
        
        // 打印接收到的数据
        if let responseString = String(data: data, encoding: .utf8) {
            print("Received response: \(responseString)")
        }
        
        // 尝试解析响应
        do {
            struct Response: Codable {
                let result: String
            }
            
            let response = try JSONDecoder().decode(Response.self, from: data)
            guard let subscriptionData = MihomoSubscriptionData.parse(from: response.result) else {
                print("Failed to parse subscription data from result")
                return try await getProxyProvider()
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            guard let expireDate = dateFormatter.date(from: subscriptionData.expire) else {
                print("Failed to parse expire date: \(subscriptionData.expire)")
                return try await getProxyProvider()
            }
            
            return [
                subscriptionData.name: SubscriptionCardInfo(
                    name: subscriptionData.name,
                    expiryDate: expireDate,
                    lastUpdateTime: Date(),
                    usedTraffic: parseTrafficString(subscriptionData.used),
                    totalTraffic: parseTrafficString(subscriptionData.total)
                )
            ]
        } catch {
            print("Error decoding response: \(error)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")")
            throw error
        }
    }
    
    func getProxyProvider() async throws -> [String: SubscriptionCardInfo]? {
        let scheme = server.clashUseSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.port)"
        let url = URL(string: "\(baseURL)/providers/proxies")!
        
        let headers = [
            "Authorization": "Bearer \(server.secret)",
            "Content-Type": "application/json"
        ]
        
        let (data, _) = try await httpClient.makeRequest(method: "GET", url: url, headers: headers, body: nil)
        let response = try JSONDecoder().decode(ProxyProviderResponse.self, from: data)
        
        var result: [String: SubscriptionCardInfo] = [:]
        
        for (name, provider) in response.providers {
            if let vehicleType = provider.vehicleType,
               ["HTTP", "FILE"].contains(vehicleType.uppercased()),
               let subInfo = provider.subscriptionInfo {
                
                let total = Double(subInfo.Total) / (1024 * 1024 * 1024)
                let used = Double(subInfo.Upload + subInfo.Download) / (1024 * 1024 * 1024)
                let expireDate = Date(timeIntervalSince1970: subInfo.Expire)
                
                result[name] = SubscriptionCardInfo(
                    name: name,
                    expiryDate: expireDate,
                    lastUpdateTime: Date(),
                    usedTraffic: used * 1024 * 1024 * 1024,
                    totalTraffic: total * 1024 * 1024 * 1024
                )
            }
        }
        
        return result
    }
    
    private func parseTrafficString(_ traffic: String) -> Double {
        let components = traffic.split(separator: " ")
        guard components.count == 2,
              let value = Double(components[0]) else {
            return 0
        }
        
        let unit = String(components[1]).uppercased()
        switch unit {
        case "GB":
            return value * 1024 * 1024 * 1024
        case "MB":
            return value * 1024 * 1024
        case "KB":
            return value * 1024
        default:
            return value
        }
    }
}

// 订阅信息管理器
class SubscriptionManager: ObservableObject {
    @Published var subscriptions: [SubscriptionCardInfo] = []
    private let server: ClashServer
    private let httpClient: HTTPClient
    private var clashClient: ClashClient
    
    init(server: ClashServer) {
        self.server = server
        self.httpClient = DefaultHTTPClient(server: server)
        
        // 根据 luciPackage 选择对应的客户端
        switch server.luciPackage {
        case .mihomoTProxy:
            self.clashClient = MihomoClient(server: server, httpClient: httpClient)
        case .openClash:
            self.clashClient = OpenClashClient(server: server, httpClient: httpClient)
        }
    }
    
    func fetchSubscriptionInfo() async {
        do {
            if let config = try await clashClient.getCurrentConfig() {
                if let subscriptionInfo = try await clashClient.getSubscriptionInfo(config: config) {
                    DispatchQueue.main.async {
                        self.subscriptions = Array(subscriptionInfo.values)
                    }
                    return
                }
            }
            
            // 如果获取配置失败，尝试获取代理提供者信息
            if let proxyInfo = try await clashClient.getProxyProvider() {
                DispatchQueue.main.async {
                    self.subscriptions = Array(proxyInfo.values)
                }
            }
        } catch {
            print("Error fetching subscription info: \(error)")
        }
    }
}

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
} 