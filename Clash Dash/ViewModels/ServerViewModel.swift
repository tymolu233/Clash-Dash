import Foundation
import SwiftUI
import NetworkExtension

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

// 添加 ListResponse 结构体
struct ListResponse: Codable {
    let id: Int?
    let result: String
    let error: String?
}

// 添加文件系统 RPC 响应的结构体
struct FSGlobResponse: Codable {
    let id: Int?
    let result: ([String], Int)  // [文件路径数组, 文件数量]
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case result
        case error
    }
    
    // 自定义解码方法来处理元组类型
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        
        // 解码 result 数组
        var resultContainer = try container.nestedUnkeyedContainer(forKey: .result)
        let fileList = try resultContainer.decode([String].self)
        let count = try resultContainer.decode(Int.self)
        result = (fileList, count)
    }
    
    // 自定义编码方法
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(error, forKey: .error)
        
        // 编码 result 元组
        var resultContainer = container.nestedUnkeyedContainer(forKey: .result)
        try resultContainer.encode(result.0)  // 文件列表
        try resultContainer.encode(result.1)  // 文件数量
    }
}

struct FSStatResponse: Codable {
    let id: Int?
    let result: FSStatResult
    let error: String?
}

struct FSStatResult: Codable {
    let type: String
    let mtime: Int
    let size: Int
    let modestr: String
}

@MainActor
class ServerViewModel: NSObject, ObservableObject, URLSessionDelegate, URLSessionTaskDelegate {
    @Published private(set) var servers: [ClashServer] = []
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var errorDetails: String?
    
    private let defaults = UserDefaults.standard
    private let logger = LogManager.shared
    private let bindingManager = WiFiBindingManager()
    private var currentWiFiSSID: String?
    
    private static let saveKey = "SavedClashServers"
    private var activeSessions: [URLSession] = []  // 保持 URLSession 的引用
    
    override init() {
        super.init()
        loadServers()
    }

    private func determineServerType(from response: VersionResponse) -> ClashServer.ServerType {
        // 检查是否是 sing-box
        if response.version.lowercased().contains("sing") {
            // logger.log("检测到后端为 sing-box 内核")
            return .singbox
        }
        
        // 如果不是 sing-box，则按原有逻辑判断
        if response.meta == true {
            // logger.log("检测到后端为 Meta 内核")
            return .meta
        }
        // logger.log("检测到后端为 Premium （原版 Clash）内核")
        return .premium
    }
    
    private func makeURLSession(for server: ClashServer) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        
        if server.openWRTUseSSL {
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
        let scheme = server.openWRTUseSSL ? "https" : "http"
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
            // print(acceptMessage)
            // logger.log(acceptMessage)
            
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
                        logger.log("更新：\(updatedServer.name ?? server.url) 状态为 OK")
                    } else {
                        updateServerStatus(server, status: .error, message: "无效的响应格式")
                        logger.log("服务器地址：\(server.url):\(server.port) ：无效的响应格式")
                    }
                }
            case 401:
                updateServerStatus(server, status: .unauthorized, message: "认证失败，请检查密钥")
                logger.log("服务器地址：\(server.url):\(server.port) ：认证失败，请检查密钥")
            case 404:
                updateServerStatus(server, status: .error, message: "API 路径不存在")
                logger.log("服务器地址：\(server.url):\(server.port) ：API 路径不存在")
            case 500...599:
                updateServerStatus(server, status: .error, message: "服务器错误: \(httpResponse.statusCode)")
                logger.log("服务器地址：\(server.url):\(server.port) ：服务器错误: \(httpResponse.statusCode)")
            default:
                updateServerStatus(server, status: .error, message: "未知响应: \(httpResponse.statusCode)")
                logger.log("服务器地址：\(server.url):\(server.port) ：未知响应: \(httpResponse.statusCode)")
            }
        } catch let urlError as URLError {
            print("🚫 URLError: \(urlError.localizedDescription)")
            logger.log("服务器地址：\(server.url):\(server.port) ：URLError: \(urlError.localizedDescription)")
            switch urlError.code {
            case .timedOut:
                updateServerStatus(server, status: .error, message: "请求超时，请检查输入的 OpenWRT 地址与端口能否访问")
            case .cancelled:
                updateServerStatus(server, status: .error, message: "请求被取消")
            case .secureConnectionFailed:
                updateServerStatus(server, status: .error, message: "SSL/TLS 连接失败")
            case .serverCertificateUntrusted:
                updateServerStatus(server, status: .error, message: "证书不信任")
            case .cannotConnectToHost:
                updateServerStatus(server, status: .error, message: "无法连接到服务器")
            case .notConnectedToInternet:
                updateServerStatus(server, status: .error, message: "网络未连接")
            default:
                updateServerStatus(server, status: .error, message: "网络错误")
            }
        } catch {
            print("❌ 未知错误: \(error)")
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
    
    @MainActor
    func loadServers() {
        // 先尝试从新的存储位置加载
        if let data = defaults.data(forKey: "servers"),
           let servers = try? JSONDecoder().decode([ClashServer].self, from: data) {
            handleLoadedServers(servers)
        } else {
            // 如果新的存储位置没有数据，尝试从旧的存储位置加载
            if let data = defaults.data(forKey: Self.saveKey),
               let servers = try? JSONDecoder().decode([ClashServer].self, from: data) {
                // 迁移数据到新的存储位置
                if let encodedData = try? JSONEncoder().encode(servers) {
                    defaults.set(encodedData, forKey: "servers")
                }
                handleLoadedServers(servers)
            }
        }
    }
    
    private func handleLoadedServers(_ servers: [ClashServer]) {
        // 直接设置服务器列表，不进行过滤
        self.servers = servers
    }
    
    private func filterServersByWiFi(_ servers: [ClashServer], ssid: String) -> [ClashServer] {
        // 查找当前 Wi-Fi 的绑定
        let bindings = bindingManager.bindings.filter { $0.ssid == ssid }
        
        // 如果没有找到绑定，返回所有服务器
        guard !bindings.isEmpty else {
            return servers
        }
        
        // 获取所有绑定的服务器 ID
        let boundServerIds = Set(bindings.flatMap { $0.serverIds })
        
        // 过滤服务器列表
        return servers.filter { server in
            boundServerIds.contains(server.id.uuidString)
        }
    }
    
    private func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            defaults.set(encoded, forKey: "servers")
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
    
    // 添加上移服务器的方法
    func moveServerUp(_ server: ClashServer) {
        guard let currentIndex = servers.firstIndex(where: { $0.id == server.id }),
              currentIndex > 0 else { return }
        
        servers.swapAt(currentIndex, currentIndex - 1)
        saveServers()
    }
    
    // 添加下移服务器的方法
    func moveServerDown(_ server: ClashServer) {
        guard let currentIndex = servers.firstIndex(where: { $0.id == server.id }),
              currentIndex < servers.count - 1 else { return }
        
        servers.swapAt(currentIndex, currentIndex + 1)
        saveServers()
    }
    
    // 验证 OpenWRT 服务器
    func validateOpenWRTServer(_ server: ClashServer, username: String, password: String) async throws -> Bool {
        let scheme = server.openWRTUseSSL ? "https" : "http"
        guard let openWRTUrl = server.openWRTUrl else {
            throw NetworkError.invalidURL
        }
        let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
        print("第一步：开始验证 OpenwrT 服务器: \(baseURL)")
        logger.log("开始验证 OpenwrT 服务器: \(baseURL)")
        
        // 1. 使用 JSON-RPC 登录
        guard let loginURL = URL(string: "\(baseURL)/cgi-bin/luci/rpc/auth") else {
            print("❌ 登录 URL 无效")
            logger.log("❌ 登录 URL 无效")
            throw NetworkError.invalidURL
        }
        
        // 创建一个新的 URLSession 配置
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10  // 设置超时时间为 10 秒
        config.timeoutIntervalForResource = 10  // 设置资源超时时间为 10 秒
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
            
            
            let (loginData, loginResponse) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
                let task = session.dataTask(with: loginRequest) { data, response, error in
                    if let error = error as? URLError, error.code == .timedOut {
                        continuation.resume(throwing: NetworkError.timeout(message: "请求超时，请检查输入的 OpenWRT 地址与端口能否访问"))
                    } else if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data, let response = response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: URLError(.unknown))
                    }
                }
                task.resume()
            }
            
            guard let httpResponse = loginResponse as? HTTPURLResponse else {
                print("❌ 无效的响应类型")
                logger.log("❌ 无效的响应类型")
                throw NetworkError.invalidResponse(message: "无效的响应类型")
            }
            
            print("📥 登录响应状态码: \(httpResponse.statusCode)")
            if let responseStr = String(data: loginData, encoding: .utf8) {
                print("📥 JSON-RPC 登录响应: \(responseStr)")
                logger.log("📥 JSON-RPC 登录响应: \(responseStr)")
            }
            
            switch httpResponse.statusCode {
            case 200:
                // 解析 JSON-RPC 响应
                let authResponse: OpenWRTAuthResponse
                do {
                    authResponse = try JSONDecoder().decode(OpenWRTAuthResponse.self, from: loginData)
                } catch {
                    print("❌ JSON-RPC 响应解析失败")
                    logger.log("❌ JSON-RPC 响应解析失败")
                    throw NetworkError.invalidResponse(message: "验证 OpenWRT 信息失败，请确认输入的信息是否正确")
                }
                
                guard let token = authResponse.result, !token.isEmpty else {
                    if authResponse.result == nil && authResponse.error == nil {
                        print("❌ 认证响应异常: result 和 error 都为 nil")
                        if let responseStr = String(data: loginData, encoding: .utf8) {
                            print("📥 原始响应内容: \(responseStr)")
                            logger.log("📥 原始响应内容: \(responseStr)")
                            throw NetworkError.unauthorized(message: "认证失败: 请检查用户名或密码是否正确") 
                        } else {
                            logger.log("❌ 认证响应异常: result 和 error 都为 nil")
                            throw NetworkError.unauthorized(message: "认证失败: 响应内容为空")
                        }
                    }
                    if let error = authResponse.error {
                        print("❌ JSON-RPC 错误: \(error)")
                        logger.log("❌ JSON-RPC 错误: \(error)")
                        throw NetworkError.invalidResponse(message: "JSON-RPC 获取错误，请确认 OpenWRT 信息是否正确")
                    }
                    print("❌ 无效的响应结果")
                    logger.log("❌ 无效的响应结果")
                    throw NetworkError.invalidResponse(message: "无效的响应结果")
                }
                
                print("🔑 获取认证令牌: \(token)")
                logger.log("🔑 获取到认证令牌: \(token)")
                
                // 根据不同的 LuCI 软件包类型调用不同的 API
                switch server.luciPackage {
                case .openClash:
                    // 检查 OpenClash 进程状态
                    guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
                        throw NetworkError.invalidURL
                    }
                    var statusRequest = URLRequest(url: url)
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
                    
                    if statusResponse.result.contains("stopped") {
                        throw NetworkError.unauthorized(message: "OpenClash 未在运行，请先启用 OpenClash 再添加")
                    }
                    
                    // OpenClash 正在运行，返回 true
                    return true
                    
                case .mihomoTProxy:
                    // 检查 MihomoTProxy 进程状态
                    guard let url = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
                        throw NetworkError.invalidURL
                    }
                    var statusRequest = URLRequest(url: url)
                    statusRequest.httpMethod = "POST"
                    statusRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    statusRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
                    
                    let statusCommand: [String: Any] = [
                        "method": "exec",
                        "params": ["pidof mihomo >/dev/null && echo 'running' || echo 'stopped'"]
                    ]
                    statusRequest.httpBody = try JSONSerialization.data(withJSONObject: statusCommand)
                    
                    let (statusData, _) = try await session.data(for: statusRequest)
                    let statusResponse = try JSONDecoder().decode(ClashStatusResponse.self, from: statusData)
                    
                    if statusResponse.result.contains("stopped") {
                        throw NetworkError.unauthorized(message: "MihomoTProxy 未在运行，请先启用 MihomoTProxy 再添加")
                    }
                    
                    // MihomoTProxy 正在运行，返回 true
                    return true
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

                    并重启 uhttpd
                    """)
                
            default:
                print("❌ 登录失败：状态码 \(httpResponse.statusCode)")
                throw NetworkError.serverError(httpResponse.statusCode)
            }
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw NetworkError.timeout(message: "请求超时，请检查输入的 OpenWRT 地址与端口能否访问")
            }
            throw urlError
        }
    }
    
    // 添加获取 Clash 配置的方法
//    func fetchClashConfig(_ server: ClashServer) async throws -> ClashConfig {
//        guard let username = server.openWRTUsername,
//              let password = server.openWRTPassword else {
//            throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
//        }
//        
//        let scheme = server.openWRTUseSSL ? "https" : "http"
//        guard let openWRTUrl = server.openWRTUrl else {
//            throw NetworkError.invalidURL
//        }
//        let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
//        guard let url = URL(string: "\(baseURL)/cgi-bin/luci/admin/services/openclash/config") else {
//            throw NetworkError.invalidURL
//        }
//        
//        var request = URLRequest(url: url)
//        
//        // 添加基本认证
//        let authString = "\(username):\(password)"
//        if let authData = authString.data(using: .utf8) {
//            let base64Auth = authData.base64EncodedString()
//            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
//        }
//        
//        let session = makeURLSession(for: server)
//        
//        do {
//            let (data, response) = try await session.data(for: request)
//            
//            guard let httpResponse = response as? HTTPURLResponse else {
//                throw NetworkError.invalidResponse(message: "无效的响应类型")
//            }
//            
//            switch httpResponse.statusCode {
//            case 200:
//                return try JSONDecoder().decode(ClashConfig.self, from: data)
//            case 401:
//                throw NetworkError.unauthorized(message: "认证失败: 服务器返回 401 未授权")
//            default:
//                throw NetworkError.serverError(httpResponse.statusCode)
//            }
//        } catch {
//            throw ClashServer.handleNetworkError(error)
//        }
//    }
    
//    nonisolated func urlSession(
//        _ session: URLSession,
//        task: URLSessionTask,
//        willPerformHTTPRedirection response: HTTPURLResponse,
//        newRequest request: URLRequest,
//        completionHandler: @escaping (URLRequest?) -> Void
//    ) {
//        print("🔄 收到重定向请求")
//        print("从: \(task.originalRequest?.url?.absoluteString ?? "unknown")")
//        print("到: \(request.url?.absoluteString ?? "unknown")")
//        print("状态码: \(response.statusCode)")
//        completionHandler(nil)  // 不跟随重定向
//    }
    
    func fetchOpenClashConfigs(_ server: ClashServer) async throws -> [OpenClashConfig] {
        let scheme = server.openWRTUseSSL ? "https" : "http"
        guard let openWRTUrl = server.openWRTUrl else {
            throw NetworkError.invalidURL
        }
        let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
        
        print("🔍 开始获取配置列表: \(baseURL)")
        logger.log("🔍 开始获取配置列表: \(baseURL)")
        
        // 1. 获取认证 token
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            print("❌ 未找到认证信息")
            logger.log("❌ 未找到认证信息")
            throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
        }
        
        // print("🔑 获取认证令牌...")
        // logger.log("🔑 获取认证令牌...")
        let token = try await getAuthToken(server, username: username, password: password)
        // print("✅ 获取令牌成功: \(token)")
        // logger.log("✅ 获取令牌成功: \(token)")
        
        let session = makeURLSession(for: server)
        
        // 2. 获取配置文件列表
        guard let fsURL = URL(string: "\(baseURL)/cgi-bin/luci/rpc/fs?auth=\(token)") else {
            throw NetworkError.invalidURL
        }
        
        var fsRequest = URLRequest(url: fsURL)
        fsRequest.httpMethod = "POST"
        fsRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        fsRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
        
        let fsCommand: [String: Any] = [
            "method": "glob",
            "params": ["/etc/openclash/config/*"]
        ]
        fsRequest.httpBody = try JSONSerialization.data(withJSONObject: fsCommand)
        
        print("📤 获取文件列表...")
        logger.log("📤 获取文件列表...")
        let (fsData, _) = try await session.data(for: fsRequest)
        
        // 解析 glob 响应
        let fsResponse = try JSONDecoder().decode(FSGlobResponse.self, from: fsData)
        let (fileList, fileCount) = fsResponse.result
        
        print("📝 找到 \(fileCount) 个配置文件")
        logger.log("📝 找到 \(fileCount) 个配置文件")
        
        // 3. 获取当前启用的配置
        guard let sysURL = URL(string: "\(baseURL)/cgi-bin/luci/rpc/sys?auth=\(token)") else {
            throw NetworkError.invalidURL
        }
        var sysRequest = URLRequest(url: sysURL)
        sysRequest.httpMethod = "POST"
        sysRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        sysRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
        
        let sysCommand: [String: Any] = [
            "method": "exec",
            "params": ["uci get openclash.config.config_path"]
        ]
        sysRequest.httpBody = try JSONSerialization.data(withJSONObject: sysCommand)
        
        let (sysData, _) = try await session.data(for: sysRequest)
        let sysResult = try JSONDecoder().decode(ListResponse.self, from: sysData)
        let currentConfig = sysResult.result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).components(separatedBy: "/").last ?? ""
        
        print("📝 当前启用的配置: \(currentConfig)")
        logger.log("📝 当前启用的配置: \(currentConfig)")
        
        // 4. 处理每个配置文件
        var configs: [OpenClashConfig] = []
        for filePath in fileList {
            let fileName = filePath.components(separatedBy: "/").last ?? ""
            guard fileName.hasSuffix(".yaml") || fileName.hasSuffix(".yml") else { continue }
            
            print("📄 处理配置文件: \(fileName)")
            logger.log("📄 处理配置文件: \(fileName)")
            
            // 获取文件元数据
            var statRequest = URLRequest(url: fsURL)
            statRequest.httpMethod = "POST"
            statRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            statRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
            
            let statCommand: [String: Any] = [
                "method": "stat",
                "params": [filePath]
            ]
            statRequest.httpBody = try JSONSerialization.data(withJSONObject: statCommand)
            
            let (statData, _) = try await session.data(for: statRequest)
            let statResponse = try JSONDecoder().decode(FSStatResponse.self, from: statData)

            logger.log("配置文件元数据: \(statResponse.result)")
            
            // 检查配置文件语法
            print("🔍 检查配置文件语法: \(fileName)")
            logger.log("🔍 检查配置文件语法: \(fileName)")
            var checkRequest = URLRequest(url: sysURL)
            checkRequest.httpMethod = "POST"
            checkRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            checkRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
            
            let checkCommand: [String: Any] = [
                "method": "exec",
                "params": ["ruby -ryaml -rYAML -I \"/usr/share/openclash\" -E UTF-8 -e \"puts YAML.load_file('\(filePath)')\" 2>/dev/null"]
            ]
            checkRequest.httpBody = try JSONSerialization.data(withJSONObject: checkCommand)
            
            let (checkData, _) = try await session.data(for: checkRequest)
            let checkResult = try JSONDecoder().decode(ListResponse.self, from: checkData)
            let check: OpenClashConfig.ConfigCheck = checkResult.result != "false\n" && !checkResult.result.isEmpty ? .normal : .abnormal
            
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
            // logger.log("订阅信息: \(subData)")
            let subscription = try? JSONDecoder().decode(OpenClashConfig.SubscriptionInfo.self, from: subData)
            guard let subscription = subscription else {
                print("❌ 订阅信息解码失败")
                logger.log("❌ 未获取到订阅信息")
                continue
            }
            logger.log("订阅信息解码: \(subscription)")
            // 创建配置对象
            let config = OpenClashConfig(
                name: fileName,
                state: fileName == currentConfig ? .enabled : .disabled,
                mtime: Date(timeIntervalSince1970: TimeInterval(statResponse.result.mtime)),
                check: check,
                subscription: subscription,
                fileSize: Int64(statResponse.result.size)
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
        let scheme = server.openWRTUseSSL ? "https" : "http"
        guard let openWRTUrl = server.openWRTUrl else { 
            throw NetworkError.invalidURL
        }
        let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
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
        let scheme = server.openWRTUseSSL ? "https" : "http"
        guard let openWRTUrl = server.openWRTUrl else {
            throw NetworkError.invalidURL
        }
        let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
        
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
        let scheme = server.openWRTUseSSL ? "https" : "http"
        guard let openWRTUrl = server.openWRTUrl else {
            throw NetworkError.invalidURL
        }
        let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
        
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
        let scheme = server.openWRTUseSSL ? "https" : "http"
        guard let openWRTUrl = server.openWRTUrl else {
            throw NetworkError.invalidURL
        }
        let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
        
        print("开始保存配置文件: \(configName)")
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
        
        // if let responseStr = String(data: data, encoding: .utf8) {
        //     print("📥 写入响应内容: \(responseStr)")
        // }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ 写入失败")
            logger.log("❌ 写入失败")
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        // 验证文件是否成功写入
        print("🔍 验证文件写入...")
        logger.log("🔍 验证文件写入...")
        
        // 使用 fs.stat 验证文件
        guard let fsURL = URL(string: "\(baseURL)/cgi-bin/luci/rpc/fs?auth=\(token)") else {
            throw NetworkError.invalidURL
        }
        
        var statRequest = URLRequest(url: fsURL)
        statRequest.httpMethod = "POST"
        statRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        statRequest.setValue("sysauth=\(token); sysauth_http=\(token)", forHTTPHeaderField: "Cookie")
        
        let statCommand: [String: Any] = [
            "method": "stat",
            "params": [filePath]
        ]
        statRequest.httpBody = try JSONSerialization.data(withJSONObject: statCommand)
        
        let (statData, _) = try await session.data(for: statRequest)
        let statResponse = try JSONDecoder().decode(FSStatResponse.self, from: statData)
        
        // 检查文件修改时间
        let fileDate = Date(timeIntervalSince1970: TimeInterval(statResponse.result.mtime))
        let timeDiff = Date().timeIntervalSince(fileDate)
        
        print("⏱ 文件修改时间差: \(timeDiff)秒")
        logger.log("⏱ 文件修改时间差: \(timeDiff)秒")
        
        if timeDiff < 0 || timeDiff > 5 {
            print("❌ 文件时间验证失败")
            logger.log("❌ 文件时间验证失败")
            throw NetworkError.invalidResponse(message: "文件时间验证失败")
        }
        
        print("✅ 配置文件保存成功")
        logger.log("✅ 配置文件保存成功")
    }
    
    func restartOpenClash(_ server: ClashServer) async throws -> AsyncThrowingStream<String, Error> {
        let scheme = server.openWRTUseSSL ? "https" : "http"
        guard let openWRTUrl = server.openWRTUrl else {
            throw NetworkError.invalidURL
        }
        let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
        
        print("开始重启 OpenClash")

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
        let scheme = server.openWRTUseSSL ? "https" : "http"
        guard let openWRTUrl = server.openWRTUrl else {
            throw NetworkError.invalidURL
        }
        let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
        
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
        let scheme = server.openWRTUseSSL ? "https" : "http"
        guard let openWRTUrl = server.openWRTUrl else {
            throw NetworkError.invalidURL
        }
        let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
        
        print("🗑 开始删除配置文件: \(configName)")
        logger.log("开始删除配置文件: \(configName)")
        
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
        rm -f \"/etc/openclash/backup/\(configName)\" && \
        rm -f \"/etc/openclash/history/\(configName)\" && \
        rm -f \"/etc/openclash/history/\(configName).db\" && \
        rm -f \"/etc/openclash/\(configName)\" && \
        rm -f \"/etc/openclash/config/\(configName)\"
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
