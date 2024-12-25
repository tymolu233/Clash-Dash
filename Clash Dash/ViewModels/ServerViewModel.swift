import Foundation
import SwiftUI

// 添加 LogManager
private let logger = LogManager.shared

// 将 VersionResponse 移到类外面
struct VersionResponse: Codable {
    let meta: Bool?
    let premium: Bool?
    let version: String
}

// 添加一个结构体来表示启动状态
public struct StartLogResponse: Codable {
    let startlog: String
}

struct ClashStatusResponse: Codable {
    let id: Int?
    let result: String
    let error: String?
}

@MainActor
class ServerViewModel: NSObject, ObservableObject, URLSessionDelegate, URLSessionTaskDelegate {
    @Published var servers: [ClashServer] = []
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var errorDetails: String?
    
    private static let saveKey = "SavedClashServers"
    private var activeSessions: [URLSession] = []  // 保持 URLSession 的引用
    
    override init() {
        super.init()
        loadServers()
    }

    private func determineServerType(from response: VersionResponse) -> ClashServer.ServerType {
        // 检查是否是 sing-box
        if response.version.lowercased().contains("sing-box") {
            return .singbox
        }
        
        // 如果不是 sing-box，则按原有逻辑判断
        if response.premium == true {
            return .premium
        } else if response.meta == true {
            return .meta
        }
        return .unknown
    }
    
    private func makeURLSession(for server: ClashServer) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        
        if server.useSSL {
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            if #available(iOS 15.0, *) {
                config.tlsMinimumSupportedProtocolVersion = .TLSv12
            } else {
                config.tlsMinimumSupportedProtocolVersion = .TLSv12
            }
            config.tlsMaximumSupportedProtocolVersion = .TLSv13
        }
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        activeSessions.append(session)  // 保存 session 引用
        return session
    }
    
    private func makeRequest(for server: ClashServer, path: String) -> URLRequest? {
        let scheme = server.useSSL ? "https" : "http"
        var urlComponents = URLComponents()
        
        urlComponents.scheme = scheme
        urlComponents.host = server.url
        urlComponents.port = Int(server.port)
        urlComponents.path = path
        
        guard let url = urlComponents.url else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let messages = [
            "🔐 收到证书验证请求",
            "认证方法: \(challenge.protectionSpace.authenticationMethod)",
            "主机: \(challenge.protectionSpace.host)",
            "端口: \(challenge.protectionSpace.port)",
            "协议: \(challenge.protectionSpace.protocol.map { $0 } ?? "unknown")"
        ]
        
        messages.forEach { message in
            print(message)
            Task { @MainActor in
                logger.log(message)
            }
        }
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let acceptMessage = "✅ 无条件接受服务器证书"
            print(acceptMessage)
            logger.log(acceptMessage)
            
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                let errorMessage = "⚠️ 无法获取服务器证书"
                print(errorMessage)
                logger.log(errorMessage)
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            let defaultMessage = "❌ 默认处理证书验证"
            print(defaultMessage)
            logger.log(defaultMessage)
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    @MainActor
    func checkAllServersStatus() async {
        for server in servers {
            await checkServerStatus(server)
        }
    }
    
    @MainActor
    private func checkServerStatus(_ server: ClashServer) async {
        guard var request = makeRequest(for: server, path: "/version") else {
            updateServerStatus(server, status: .error, message: "无效的请求")
            return
        }

        request.timeoutInterval = 2 // 设置请求超时时间为2秒
        
        do {
            let session = makeURLSession(for: server)
            
            let (data, response) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data, let response = response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: URLError(.unknown))
                    }
                }
                task.resume()
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                updateServerStatus(server, status: .error, message: "无效的响应")
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let versionResponse = try JSONDecoder().decode(VersionResponse.self, from: data)
                    var updatedServer = server
                    updatedServer.status = .ok
                    updatedServer.version = versionResponse.version
                    updatedServer.serverType = determineServerType(from: versionResponse)
                    updatedServer.errorMessage = nil
                    updateServer(updatedServer)
                } catch {
                    if let versionDict = try? JSONDecoder().decode([String: String].self, from: data),
                       let version = versionDict["version"] {
                        var updatedServer = server
                        updatedServer.status = .ok
                        updatedServer.version = version
                        updatedServer.errorMessage = nil
                        updateServer(updatedServer)
                    } else {
                        updateServerStatus(server, status: .error, message: "无效的响应格式")
                    }
                }
            case 401:
                updateServerStatus(server, status: .unauthorized, message: "认证失败，请检查密钥")
                throw NetworkError.unauthorized(message: "认证失败: 服务器返回 401 未授权")
            case 404:
                updateServerStatus(server, status: .error, message: "API 路径不存在")
            case 500...599:
                updateServerStatus(server, status: .error, message: "服务器错误: \(httpResponse.statusCode)")
            default:
                updateServerStatus(server, status: .error, message: "未知响应: \(httpResponse.statusCode)")
            }
        } catch let urlError as URLError {
            print("🚫 URLError: \(urlError.localizedDescription)")
            
            switch urlError.code {
            case .cancelled:
                updateServerStatus(server, status: .error, message: "请求被取消")
            case .secureConnectionFailed:
                updateServerStatus(server, status: .error, message: "SSL/TLS 连接失败")
            case .serverCertificateUntrusted:
                updateServerStatus(server, status: .error, message: "证书不信任")
            case .timedOut:
                updateServerStatus(server, status: .error, message: "连接超时")
            case .cannotConnectToHost:
                updateServerStatus(server, status: .error, message: "无法连接到服务器")
            case .notConnectedToInternet:
                updateServerStatus(server, status: .error, message: "网络未连接")
            default:
                updateServerStatus(server, status: .error, message: "网络错误")
            }
        } catch {
            print("❌ 未知错��: \(error)")
            updateServerStatus(server, status: .error, message: "未知错误")
        }
    }
    
    private func updateServerStatus(_ server: ClashServer, status: ServerStatus, message: String? = nil) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            var updatedServer = server
            updatedServer.status = status
            updatedServer.errorMessage = message
            servers[index] = updatedServer
            saveServers()
        }
    }
    
    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let decoded = try? JSONDecoder().decode([ClashServer].self, from: data) {
            servers = decoded
        }
    }
    
    private func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
    }
    
    func addServer(_ server: ClashServer) {
        servers.append(server)
        saveServers()
        Task {
            await checkServerStatus(server)
        }
    }
    
    func updateServer(_ server: ClashServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            saveServers()
            // Task {
            //     await checkServerStatus(server)
            // }
        }
    }
    
    func deleteServer(_ server: ClashServer) {
        servers.removeAll { $0.id == server.id }
        saveServers()
    }
    
    func setQuickLaunch(_ server: ClashServer) {
        // 如果当前服务器已经是快速启动，则取消
        if server.isQuickLaunch {
            if let index = servers.firstIndex(where: { $0.id == server.id }) {
                servers[index].isQuickLaunch = false
            }
        } else {
            // 否则，先将所有服务器的 isQuickLaunch 设为 false
            for index in servers.indices {
                servers[index].isQuickLaunch = false
            }
            
            // 然后设置选中的服务器为快速启动
            if let index = servers.firstIndex(where: { $0.id == server.id }) {
                servers[index].isQuickLaunch = true
            }
        }
        
        // 保存更改
        saveServers()
    }
    
    // 修改验证方法
    func validateOpenWRTServer(_ server: ClashServer, username: String, password: String) async throws -> OpenWRTStatus {
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        print("🔍 开始验证 OpenWRT 服务器: \(baseURL)")
        logger.log("🔍 开始验证 OpenWRT 服务器: \(baseURL)")
        
        // 1. 使用 JSON-RPC 登录
        guard let loginURL = URL(string: "\(baseURL)/cgi-bin/luci/rpc/auth") else {
            print("❌ 登录 URL 无效")
            logger.log("❌ 登录 URL 无效")
            throw NetworkError.invalidURL
        }
        
        // 创建一个新的 URLSession 配置
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        activeSessions.append(session)
        
        do {
            // 创建 JSON-RPC 登录请求
            var loginRequest = URLRequest(url: loginURL)
            loginRequest.httpMethod = "POST"
            loginRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // 构建 JSON-RPC 请求体
            let requestBody: [String: Any] = [
                "id": 1,
                "method": "login",
                "params": [username, password]
            ]
            
            loginRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            print("📤 发送 JSON-RPC 登录请求")
            logger.log("📤 发送 JSON-RPC 登录请求")
            let (loginData, loginResponse) = try await session.data(for: loginRequest)
            
            guard let httpResponse = loginResponse as? HTTPURLResponse else {
                print("❌ 无效的响应类型")
                logger.log("❌ 无效的响应类型")
                throw NetworkError.invalidResponse
            }
            
            print("📥 登录响应状态码: \(httpResponse.statusCode)")
            if let responseStr = String(data: loginData, encoding: .utf8) {
                print("📥 JSON-RPC 登录响应: \(responseStr)")
                logger.log("📥 JSON-RPC 登录响应: \(responseStr)")
            }
            
            switch httpResponse.statusCode {
            case 200:
                // 解析 JSON-RPC 响应
                let authResponse = try JSONDecoder().decode(OpenWRTAuthResponse.self, from: loginData)
                print("📥 解析后的 JSON-RPC 响应: id=\(authResponse.id), result=\(authResponse.result ?? "nil"), error=\(authResponse.error ?? "nil")")
                logger.log("📥 解析后的 JSON-RPC 响应: id=\(authResponse.id), result=\(authResponse.result ?? "nil"), error=\(authResponse.error ?? "nil")")
                
                guard let token = authResponse.result, !token.isEmpty else {
                    if authResponse.result == nil && authResponse.error == nil {
                        print("❌ 认证响应异常: result 和 error 都为 nil")
                        if let responseStr = String(data: loginData, encoding: .utf8) {
                            print("📥 原始响应内容: \(responseStr)")
                            logger.log("📥 原始响应内容: \(responseStr)")
                            throw NetworkError.unauthorized(message: "认证失败: \(responseStr)") 
                        } else {
                            logger.log("❌ 认证响应异常: result 和 error 都为 nil")
                            throw NetworkError.unauthorized(message: "认证失败: 响应内容为空")
                        }
                    }
                    if let error = authResponse.error {
                        print("❌ JSON-RPC 错误: \(error)")
                        logger.log("❌ JSON-RPC 错误: \(error)")
                        throw NetworkError.unauthorized(message: "认证失败: \(error)")
                    }
                    print("❌ 无效的响应结果")
                    logger.log("❌ 无效的响应结果")
                    throw NetworkError.invalidResponse
                }
                
                print("🔑 获取���认证令牌: \(token)")
                logger.log("🔑 获取到认证令牌: \(token)")
                // 2. 使用认证令牌获取 OpenClash 状态
                let timestamp = Int(Date().timeIntervalSince1970 * 1000)
                guard let statusURL = URL(string: "\(baseURL)/cgi-bin/luci/admin/services/openclash/status?\(timestamp)") else {
                    print("❌ 状态 URL 无效")
                    throw NetworkError.invalidURL
                }
                
                print("📤 发送状态请求: \(statusURL)")
                logger.log("📤 发送状态请求: \(statusURL)")
                var statusRequest = URLRequest(url: statusURL)
                statusRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
                
                let (statusData, statusResponse) = try await session.data(for: statusRequest)
                
                guard let statusHttpResponse = statusResponse as? HTTPURLResponse else {
                    print("❌ 无效的状态响应类型")
                    throw NetworkError.invalidResponse
                }
                
                let message = "📥 状态响应状态码: \(statusHttpResponse.statusCode)"
                print(message)
                logger.log(message)
                
                if let responseStr = String(data: statusData, encoding: .utf8) {
                    print("📥 OpenClash 状态响应: \(responseStr)")
                    // logger.log("📥 OpenClash 状态响应: \(responseStr)")
                }
                
                
                switch statusHttpResponse.statusCode {
                case 200:
                    print("✅ 获取状态成功，开始解析")
                    print("📥 原始响应容：")
                    if let jsonString = String(data: statusData, encoding: .utf8) {
                        print("""
                        {
                            解析到的 JSON 内容：
                            \(jsonString.replacingOccurrences(of: ",", with: ",\n    "))
                        }
                        """)
                    }
                    
                    do {
                        let status = try JSONDecoder().decode(OpenWRTStatus.self, from: statusData)
                        print("✅ 解析成功: \(status)")
                        return status
                    } catch {
                        print("❌ 解析错误: \(error)")
                        if let decodingError = error as? DecodingError {
                            switch decodingError {
                            case .keyNotFound(let key, _):
                                print("缺少必需的字段: \(key)")
                            case .typeMismatch(let type, let context):
                                print("类型不匹配: 期望 \(type) 路径: \(context.codingPath)")
                            case .valueNotFound(let type, let context):
                                print("值为空: 期望 \(type) 在路径: \(context.codingPath)")
                            default:
                                print("其他解码错误: \(decodingError)")
                            }
                        }
                        throw NetworkError.invalidResponse
                    }
                case 403:
                    print("🔒 使用 OpenClash API 获取状态失败，尝试使用 exec 命令获取")
                    logger.log("🔒 使用 OpenClash API 获取状态失败，尝试使用 exec 命令获取")
                    
                    // 构建 exec 命令获取状态
                    let statusCommand = """
                    echo "clash: $( pidof clash > /dev/null && echo "true" || echo "false" )"; \
                    echo "watchdog: $( ps | grep openclash_watchdog.sh | grep -v grep > /dev/null && echo "true" || echo "false" )"; \
                    echo "daip: $( daip=$( uci -q get network.lan.ipaddr |awk -F '/' '{print $1}' 2>/dev/null ); \
                        if [ -z "$daip" ]; then \
                            daip=$( ip address show $(uci -q -p /tmp/state get network.lan.ifname || uci -q -p /tmp/state get network.lan.device) | grep -w 'inet' | grep -Eo 'inet [0-9\\.]+' | awk '{print $2}' ); \
                        fi; \
                        if [ -z "$daip" ]; then \
                            daip=$( ip addr show | grep -w 'inet' | grep 'global' | grep 'brd' | grep -Eo 'inet [0-9\\.]+' | awk '{print $2}' | head -n 1 ); \
                        fi; \
                        echo "$daip" )"; \
                    echo "dase: $( uci -q get openclash.config.dashboard_password )"; \
                    echo "db_foward_port: $( uci -q get openclash.config.dashboard_forward_port )"; \
                    echo "db_foward_domain: $( uci -q get openclash.config.dashboard_forward_domain )"; \
                    echo "db_forward_ssl: $( uci -q get openclash.config.dashboard_forward_ssl )"; \
                    echo "web: $( pidof clash > /dev/null && echo "true" || echo "false" )"; \
                    echo "cn_port: $( uci -q get openclash.config.cn_port )"; \
                    echo "core_type: $( uci -q get openclash.config.core_type || echo "Meta" )"
                    """
                    
                    guard let execURL = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
                        throw NetworkError.invalidURL
                    }
                    
                    var execRequest = URLRequest(url: execURL)
                    execRequest.httpMethod = "POST"
                    execRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    execRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
                    
                    let execBody: [String: Any] = [
                        "method": "exec",
                        "params": [statusCommand]
                    ]
                    execRequest.httpBody = try JSONSerialization.data(withJSONObject: execBody)
                    
                    let (execData, execResponse) = try await session.data(for: execRequest)
                    
                    guard let execHttpResponse = execResponse as? HTTPURLResponse,
                          execHttpResponse.statusCode == 200 else {
                        throw NetworkError.serverError((execResponse as? HTTPURLResponse)?.statusCode ?? 500)
                    }
                    
                    // 解析 exec 命令返回的结果
                    struct ExecResponse: Codable {
                        let result: String
                        let error: String?
                    }
                    
                    let execResult = try JSONDecoder().decode(ExecResponse.self, from: execData)
                    
                    // 将命令输出转换为字典
                    var statusDict: [String: Any] = [:]
                    let lines = execResult.result.components(separatedBy: "\n")
                    for line in lines {
                        let parts = line.components(separatedBy: ": ")
                        if parts.count == 2 {
                            let key = parts[0].trimmingCharacters(in: .whitespaces)
                            let value = parts[1].trimmingCharacters(in: .whitespaces)
                            // 修改这里的逻辑，使用 if-else 来处理不同类型
                            if value == "true" || value == "false" {
                                statusDict[key] = value == "true"
                            } else {
                                statusDict[key] = value
                            }
                        }
                    }
                    
                    // 检查必要字段是否存在
                    guard let daip = statusDict["daip"] as? String,
                          let dase = statusDict["dase"] as? String,
                          let cnPort = statusDict["cn_port"] as? String else {
                        print("❌ 缺少必要的状态信息")
                        logger.log("❌ 缺少必要的状态信息")
                        logger.log("statusDict: \(statusDict)")
                        throw NetworkError.invalidResponse
                    }
                    
                    // 转换为 JSON 数据
                    let jsonData = try JSONSerialization.data(withJSONObject: [
                        "web": statusDict["web"] as? Bool ?? false,
                        "clash": statusDict["clash"] as? Bool ?? false,
                        "daip": daip,
                        "cn_port": cnPort,
                        "dase": dase,
                        "core_type": statusDict["core_type"] as? String ?? "Meta",
                        "db_forward_ssl": statusDict["db_forward_ssl"] as? String,
                        "restricted_mode": statusDict["restricted_mode"] as? String,
                        "watchdog": statusDict["watchdog"] as? Bool ?? false
                    ])
                    
                    // 解析为 OpenWRTStatus
                    let status = try JSONDecoder().decode(OpenWRTStatus.self, from: jsonData)
                    print("✅ 使用 exec 命令成功获取状态")
                    logger.log("✅ 使用 exec 命令成功获取状态")
                    logger.log("status: \(status)")
                    return status
                default:
                    print("❌ 状态请求失败: \(statusHttpResponse.statusCode)")
                    throw NetworkError.serverError(statusHttpResponse.statusCode)
                }
                
            case 404:
                print("❌ OpenWRT 缺少必要的依赖")
                logger.log("❌ OpenWRT 缺少必要的依赖")
                throw NetworkError.missingDependencies("""
                    OpenWRT 路由器缺少必要的依赖
                    
                    请确保已经安装以下软件包：
                    1. luci-mod-rpc
                    2. luci-lib-ipkg
                    3. luci-compat
                    
                    可以通过以下命令安装：
                    opkg update
                    opkg install luci-mod-rpc luci-lib-ipkg luci-compat

                    并重启 uhttpd：
                    /etc/init.d/uhttpd restart
                    """)
                
            default:
                print("❌ 登录失败：状态码 \(httpResponse.statusCode)")
                throw NetworkError.serverError(httpResponse.statusCode)
            }
        } catch {
            print("❌ 请求错误: \(error)")
            throw ClashServer.handleNetworkError(error)
        }
    }
    
    // 添加获取 Clash 配置的方法
    func fetchClashConfig(_ server: ClashServer) async throws -> ClashConfig {
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
        }
        
        let scheme = server.useSSL ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(server.url):\(server.port)/cgi-bin/luci/admin/services/openclash/config") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        
        // 添加基本认证
        let authString = "\(username):\(password)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }
        
        let session = makeURLSession(for: server)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                return try JSONDecoder().decode(ClashConfig.self, from: data)
            case 401:
                throw NetworkError.unauthorized(message: "认证失败: 服务器返回 401 未授权")
            default:
                throw NetworkError.serverError(httpResponse.statusCode)
            }
        } catch {
            throw ClashServer.handleNetworkError(error)
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        print("🔄 收到重定向请求")
        print("从: \(task.originalRequest?.url?.absoluteString ?? "unknown")")
        print("到: \(request.url?.absoluteString ?? "unknown")")
        print("状态码: \(response.statusCode)")
        completionHandler(nil)  // 不跟随重定向
    }
    
    func fetchOpenClashConfigs(_ server: ClashServer) async throws -> [OpenClashConfig] {
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        let message = "🔍 开始获取配置列表: \(baseURL)"
        print(message)
        logger.log(message)
        
        // 1. 获取或重用 token
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            print("❌ 未找到认证信息")
            logger.log("❌ 未找到认证信息")
            throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
        }
        
        print("🔑 获取认证令牌...") 
        logger.log("🔑 获取认证令牌...")
        let token = try await getAuthToken(server, username: username, password: password)
        print("✅ 获取令牌成功: \(token)")
        logger.log("✅ 获取令牌成功: \(token)")
        
        // 创建 session
        let session = makeURLSession(for: server)
        
        // 3. 获取配置文件列表
        guard let listURL = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
            print("❌ 无效的列表 URL")
            throw NetworkError.invalidURL
        }
        
        print("📤 发送获取文件列表请求...")
        var listRequest = URLRequest(url: listURL)
        listRequest.httpMethod = "POST"
        listRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let listCommand: [String: Any] = [
            "method": "exec",
            "params": ["ls -la --full-time /etc/openclash/config/"]
        ]
        listRequest.httpBody = try JSONSerialization.data(withJSONObject: listCommand)
        
        let (listData, listResponse) = try await session.data(for: listRequest)
        
        if let httpResponse = listResponse as? HTTPURLResponse {
            print("📥 文件列表响应状态码: \(httpResponse.statusCode)")
        }
        
        if let responseStr = String(data: listData, encoding: .utf8) {
            print("📥 文件列表响应: \(responseStr)")
        }
        
        struct ListResponse: Codable {
            let id: Int?
            let result: String
            let error: String?
        }
        
        let listResult = try JSONDecoder().decode(ListResponse.self, from: listData)
        let fileList = listResult.result
        
        print("📝 文件列表内容:\n\(fileList)")
        
        // 4. 获取当前启用的配置
        print("📤 获取当前启用的配置...")
        logger.log("📤 获取当前启用的配置...")
        var currentRequest = URLRequest(url: listURL)
        currentRequest.httpMethod = "POST"
        currentRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let currentCommand: [String: Any] = [
            "method": "exec",
            "params": ["uci get openclash.config.config_path"]
        ]
        currentRequest.httpBody = try JSONSerialization.data(withJSONObject: currentCommand)
        
        let (currentData, currentResponse) = try await session.data(for: currentRequest)
        
        if let httpResponse = currentResponse as? HTTPURLResponse {
            print("📥 当前配置响应状态码: \(httpResponse.statusCode)")
            logger.log("📥 当前配置响应状态码: \(httpResponse.statusCode)")
        }
        
        if let responseStr = String(data: currentData, encoding: .utf8) {
            print("📥 当前配置响应: \(responseStr)")
            logger.log("📥 当前配置响应: \(responseStr)")
        }
        
        let currentResult = try JSONDecoder().decode(ListResponse.self, from: currentData)
        let currentConfig = currentResult.result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).components(separatedBy: "/").last ?? ""
        print("📝 当前用的配置: \(currentConfig)")
        logger.log("📝 当前用的配置: \(currentConfig)")
        // 5. 解析文件列表
        var configs: [OpenClashConfig] = []
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current  // 使用当前时区
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"  // 修改日期匹配 --full-time 输出
        
        let lines = fileList.components(separatedBy: CharacterSet.newlines)
        print("🔍 开始解析 \(lines.count) 行文件列表")
        
        for line in lines {
            let components = line.split(separator: " ").filter { !$0.isEmpty }
            guard components.count >= 9,
                  let fileName = components.last?.description,
                  fileName.hasSuffix(".yaml") || fileName.hasSuffix(".yml"),
                  let fileSize = Int64(components[4]) else {  // 获取文件大小
                continue
            }
            
            print("📄 处理配置文件: \(fileName), 大小: \(fileSize) 字节")
            
            // 解析日期
            let dateString = "\(components[5]) \(components[6]) \(components[7])"  // 2024-12-09 21:34:04 +0800
            let date = dateFormatter.date(from: dateString) ?? Date()
            
            // 检查配置文件语法
            print("🔍 检查配置文件语法: \(fileName)")
            logger.log("🔍 检查配置文件语法: \(fileName)")
            var checkRequest = URLRequest(url: listURL)
            checkRequest.httpMethod = "POST"
            checkRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let checkCommand: [String: Any] = [
                "method": "exec",
                "params": ["ruby -ryaml -rYAML -I \"/usr/share/openclash\" -E UTF-8 -e \"puts YAML.load_file('/etc/openclash/config/\(fileName)')\" 2>/dev/null"]
            ]
            checkRequest.httpBody = try JSONSerialization.data(withJSONObject: checkCommand)
            
            let (checkData, _) = try await session.data(for: checkRequest)
            // if let responseStr = String(data: checkData, encoding: .utf8) {
            //     print("📥 配置语法检查响应: \(responseStr)")
            // }
            
            let checkResult = try JSONDecoder().decode(ListResponse.self, from: checkData)
            let check: OpenClashConfig.ConfigCheck = checkResult.result != "false\n" && !checkResult.result.isEmpty ? .normal : .abnormal
            
            print("📝 配置语法检查结果: \(check)")
            logger.log("📝 配置语法检查结果: \(check)") 
            // 获取订阅信息
            print("获取订阅信息: \(fileName)")
            logger.log("获取订阅信息: \(fileName)")
            let subFileName = fileName.replacingOccurrences(of: ".yaml", with: "").replacingOccurrences(of: ".yml", with: "")
            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            guard let subURL = URL(string: "\(baseURL)/cgi-bin/luci/admin/services/openclash/sub_info_get?\(timestamp)&filename=\(subFileName)") else {
                continue
            }
            
            var subRequest = URLRequest(url: subURL)
            subRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
            
            let (subData, _) = try await session.data(for: subRequest)
            let subscription = try? JSONDecoder().decode(OpenClashConfig.SubscriptionInfo.self, from: subData)
            
            // 创建配置对象
            let config = OpenClashConfig(
                name: fileName,
                state: fileName == currentConfig ? .enabled : .disabled,
                mtime: date,
                check: check,
                subscription: subscription,
                fileSize: fileSize
            )
            
            configs.append(config)
            print("✅ 成功添加配置: \(fileName)")
            logger.log("✅ 成功添加配置: \(fileName)")
        }
        
        print("✅ 完成配置列表获取，共 \(configs.count) 个配置")
        logger.log("✅ 完成配置列表获取，共 \(configs.count) 个配置")
        return configs
    }
    
    func switchOpenClashConfig(_ server: ClashServer, configName: String) async throws -> AsyncStream<String> {
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        print("🔄 开始切换配置: \(configName)")
        logger.log("🔄 开始切换配置: \(configName)")
        // 获取认证 token
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
        }
        
        let token = try await getAuthToken(server, username: username, password: password)
        
        // 1. 发送切换配置请求
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        guard let switchURL = URL(string: "\(baseURL)/cgi-bin/luci/admin/services/openclash/switch_config?\(timestamp)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: switchURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
        request.httpBody = "config_name=\(configName)".data(using: .utf8)
        
        let session = makeURLSession(for: server)
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        // 2. 使用 restartOpenClash 来重启服务并监控状态
        let restartStream = try await restartOpenClash(server)
        
        // 3. 使用 AsyncThrowingStream 转换为 AsyncStream
        return AsyncStream { continuation in
            Task {
                do {
                    for try await message in restartStream {
                        continuation.yield(message)
                    }
                    continuation.finish()
                } catch {
                    continuation.yield("❌ 发生错误: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
    
    // 将 getAuthToken 改为 public
    public func getAuthToken(_ server: ClashServer, username: String, password: String) async throws -> String {
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        
        guard let loginURL = URL(string: "\(baseURL)/cgi-bin/luci/rpc/auth") else {
            throw NetworkError.invalidURL
        }
        
        var loginRequest = URLRequest(url: loginURL)
        loginRequest.httpMethod = "POST"
        loginRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "id": 1,
            "method": "login",
            "params": [username, password]
        ]
        
        loginRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let session = makeURLSession(for: server)
        let (data, _) = try await session.data(for: loginRequest)
        let authResponse = try JSONDecoder().decode(OpenWRTAuthResponse.self, from: data)
        
        guard let token = authResponse.result, !token.isEmpty else {
            if let error = authResponse.error {
                throw NetworkError.unauthorized(message: "认证失败: \(error)")
            }
            throw NetworkError.unauthorized(message: "认证失败: 服务器没有返回有效的认证令牌")
        }
        
        return token
    }
    
    func fetchConfigContent(_ server: ClashServer, configName: String) async throws -> String {
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        
        // 获取认证 token
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
        }
        
        let token = try await getAuthToken(server, username: username, password: password)
        
        // 构建请求
        guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
        
        let command: [String: Any] = [
            "method": "exec",
            "params": ["cat /etc/openclash/config/\(configName)"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: command)
        
        let session = makeURLSession(for: server)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        struct ConfigResponse: Codable {
            let id: Int?
            let result: String
            let error: String?
        }
        
        let configResponse = try JSONDecoder().decode(ConfigResponse.self, from: data)
        return configResponse.result
    }
    
    func saveConfigContent(_ server: ClashServer, configName: String, content: String) async throws {
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        
        print("📝 开始保存配置文件: \(configName)")
        logger.log("📝 开始保存配置文件: \(configName)")
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            print("❌ 未找到认证信息")
            logger.log("❌ 未找到认证信息")
            throw NetworkError.unauthorized(message: "未找到认证信息")
        }
        
        print("🔑 获取认证令牌...")
        logger.log("🔑 获取认证令牌...")
        let token = try await getAuthToken(server, username: username, password: password)
        print("✅ 获取令牌成功: \(token)")
        logger.log("✅ 获取令牌成功: \(token)")
        
        // 构建请求
        guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
            print("❌ 无效的 URL")
            throw NetworkError.invalidURL
        }
        
        // 转义内容中的特殊字符
        let escapedContent = content.replacingOccurrences(of: "'", with: "'\\''")
        
        // 构建写入命令,使用 echo 直接写入
        let filePath = "/etc/openclash/config/\(configName)"
        let cmd = "echo '\(escapedContent)' > \(filePath) 2>&1 && echo '写入成功' || echo '写入失败'"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST" 
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
        
        let command: [String: Any] = [
            "method": "exec",
            "params": [cmd]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: command)
        
        let session = makeURLSession(for: server)
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📥 写入响应状态码: \(httpResponse.statusCode)")
            logger.log("📥 写入响应状态码: \(httpResponse.statusCode)")
        }
        
        if let responseStr = String(data: data, encoding: .utf8) {
            print("📥 写入响应内容: \(responseStr)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ 写入失败")
            logger.log("❌ 写入失败")
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        // 验证文件是否成功写入
        print("🔍 验证文件写入...")
        logger.log("🔍 验证文件写入...")
        let verifyCommand: [String: Any] = [
            "method": "exec",
            "params": ["ls -l --full-time \(filePath)"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: verifyCommand)
        let (verifyData, _) = try await session.data(for: request)
        
        if let verifyStr = String(data: verifyData, encoding: .utf8) {
            print("📥 验证响应内容: \(verifyStr)")
        }
        
        struct VerifyResponse: Codable {
            let result: String
        }
        
        let verifyResult = try JSONDecoder().decode(VerifyResponse.self, from: verifyData)
        let fileInfo = verifyResult.result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if fileInfo.isEmpty {
            print("❌ 文件验证失败：未找到文件")
            logger.log("❌ 文件验证失败：未找到文件")
            throw NetworkError.invalidResponse
        }
        
        // 检查文件修改时间
        let components = fileInfo.split(separator: " ")
        if components.count >= 8 {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateString = "\(components[5]) \(components[6])"
            
            if let fileDate = dateFormatter.date(from: dateString) {
                let timeDiff = Date().timeIntervalSince(fileDate)
                print("⏱ 文件修改时间差: \(timeDiff)秒")
                logger.log("⏱ 文件修改时间差: \(timeDiff)秒")
                if timeDiff < 0 || timeDiff > 5 {
                    print("❌ 文件时间验证失败")
                    logger.log("❌ 文件时间验证失败")
                    throw NetworkError.invalidResponse
                }
            }
        }
        
        print("✅ 配置文件保存成功")
        logger.log("✅ 配置文件保存成功")
    }
    
    func restartOpenClash(_ server: ClashServer) async throws -> AsyncThrowingStream<String, Error> {
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        
        print("🔄 开始重启 OpenClash")

        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            print("❌ 未找到认证信息")
            throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
        }
        
        print("🔑 获取认证令牌...")
        let token = try await getAuthToken(server, username: username, password: password)
        print("✅ 获取令牌成功: \(token)")
        
        guard let restartURL = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
            throw NetworkError.invalidURL
        }
        
        var restartRequest = URLRequest(url: restartURL)
        restartRequest.httpMethod = "POST"
        restartRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        restartRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
        
        let restartCommand: [String: Any] = [
            "method": "exec",
            "params": ["/etc/init.d/openclash restart >/dev/null 2>&1 &"]
        ]
        restartRequest.httpBody = try JSONSerialization.data(withJSONObject: restartCommand)
        
        let session = makeURLSession(for: server)
        let (_, restartResponse) = try await session.data(for: restartRequest)
        
        guard (restartResponse as? HTTPURLResponse)?.statusCode == 200 else {
            throw NetworkError.serverError((restartResponse as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        print("✅ 重启命令已发送")
        logger.log("✅ 重启命令已发送")
        
        // 返回一个异步流来监控启动日志和服务状态
        return AsyncThrowingStream { continuation in
            Task {
                var isRunning = false
                var hasWaitedAfterRunning = false
                var seenLogs = Set<String>()
                var waitStartTime: Date? = nil
                
                while !isRunning || !hasWaitedAfterRunning {
                    do {
                        // 获取启动日志
                        let random = Int.random(in: 1...1000000000)
                        guard let logURL = URL(string: "\(baseURL)/cgi-bin/luci/admin/services/openclash/startlog?\(random)") else {
                            throw NetworkError.invalidURL
                        }
                        
                        var logRequest = URLRequest(url: logURL)
                        logRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
                        
                        let (logData, _) = try await session.data(for: logRequest)
                        let logResponse = try JSONDecoder().decode(StartLogResponse.self, from: logData)
                        
                        // 处理日志
                        if !logResponse.startlog.isEmpty {
                            let logs = logResponse.startlog
                                .components(separatedBy: "\n")
                                .filter { !$0.isEmpty && $0 != "\n" }
                            
                            for log in logs {
                                let trimmedLog = log.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmedLog.isEmpty && !seenLogs.contains(trimmedLog) {
                                    seenLogs.insert(trimmedLog)
                                    continuation.yield(trimmedLog)
                                    
                                    // 检查日志是否包含成功标记
                                    if trimmedLog.contains("启动成功") {
                                        continuation.yield("✅ OpenClash 服务已完全就绪")
                                        continuation.finish()
                                        return
                                    }
                                }
                            }
                        }
                        
                        // 检查服务状态
                        var statusRequest = URLRequest(url: restartURL)
                        statusRequest.httpMethod = "POST"
                        statusRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        statusRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
                        
                        let statusCommand: [String: Any] = [
                            "method": "exec",
                            "params": ["pidof clash >/dev/null && echo 'running' || echo 'stopped'"]
                        ]
                        statusRequest.httpBody = try JSONSerialization.data(withJSONObject: statusCommand)
                        
                        let (statusData, _) = try await session.data(for: statusRequest)
                        let statusResponse = try JSONDecoder().decode(ClashStatusResponse.self, from: statusData)
                        
                        if statusResponse.result.contains("running") {
                            if !isRunning {
                                isRunning = true
                                waitStartTime = Date()
                            }
                            
                            // 检查是否已经等待足够时间
                            if let startTime = waitStartTime {
                                let elapsedTime = Date().timeIntervalSince(startTime)
                                if elapsedTime >= 20 {  // 等待20秒确保服务完全启动
                                    hasWaitedAfterRunning = true
                                    continuation.yield("✅ OpenClash 服务已就绪")
                                    continuation.finish()
                                    break
                                }
                            }
                        }
                        
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒延迟
                        
                    } catch {
                        continuation.yield("❌ 发生错误: \(error.localizedDescription)")
                        continuation.finish()
                        break
                    }
                }
            }
        }
    }
    
    private func getOpenClashStatus(_ server: ClashServer) async throws -> ClashStatusResponse {
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
        }
        
        let token = try await getAuthToken(server, username: username, password: password)
        
        guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
        
        let command: [String: Any] = [
            "method": "exec",
            "params": ["/etc/init.d/openclash status"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: command)
        
        let session = makeURLSession(for: server)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        return try JSONDecoder().decode(ClashStatusResponse.self, from: data)
    }
    
    func deleteOpenClashConfig(_ server: ClashServer, configName: String) async throws {
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        
        print("🗑 开始删除配置文件: \(configName)")
        logger.log("🗑 开始删除配置文件: \(configName)")
        
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            print("❌ 未找到认证信息")
            logger.log("❌ 未找到认证信息")
            throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
        }
        
        print("🔑 获取认证令牌...")
        logger.log("🔑 获取认证令牌...")
        let token = try await getAuthToken(server, username: username, password: password)
        print("✅ 获取令牌成功: \(token)")
        logger.log("✅ 获取令牌成功: \(token)")
        
        guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
            print("❌ 无效的 URL")
            throw NetworkError.invalidURL
        }
        
        let deleteCommand = """
        rm -f /tmp/Proxy_Group && \
        rm -f /etc/openclash/backup/\(configName) && \
        rm -f /etc/openclash/history/\(configName) && \
        rm -f /etc/openclash/history/\(configName).db && \
        rm -f /etc/openclash/\(configName) && \
        rm -f /etc/openclash/config/\(configName)
        """
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
        
        let command: [String: Any] = [
            "method": "exec",
            "params": [deleteCommand]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: command)
        
        let session = makeURLSession(for: server)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ 删除失败")
            logger.log("❌ 删除失败")
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        print("✅ 配置文件删除成功")
        logger.log("✅ 配置文件删除成功")
    }
} 