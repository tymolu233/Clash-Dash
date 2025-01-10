import Foundation
// 添加 LogManager
private let logger = LogManager.shared

struct ProxyNode: Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let alive: Bool
    let delay: Int
    let history: [ProxyHistory]
    
    // 实现 Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // 实现 Equatable
    static func == (lhs: ProxyNode, rhs: ProxyNode) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ProxyHistory: Codable, Hashable {
    let time: String
    let delay: Int
}

struct ProxyGroup: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let now: String
    let all: [String]
    let alive: Bool
    let icon: String?
    
    init(name: String, type: String, now: String, all: [String], alive: Bool = true, icon: String? = nil) {
        self.name = name
        self.type = type
        self.now = now
        self.all = all
        self.alive = alive
        self.icon = icon
    }
}

// 更新数据模型
struct ProxyProvider: Codable {
    let name: String
    let type: String
    let vehicleType: String
    let proxies: [ProxyDetail]
    let testUrl: String?
    let subscriptionInfo: SubscriptionInfo?
    let updatedAt: String?
    let hidden: Bool?
}

struct ProxyProvidersResponse: Codable {
    let providers: [String: ProxyProvider]
}

// 添加 Provider 模型
struct Provider: Identifiable, Codable, Equatable {
    var id: String { name }
    let name: String
    let type: String
    let vehicleType: String
    let updatedAt: String?
    let subscriptionInfo: SubscriptionInfo?
    let hidden: Bool?
    
    static func == (lhs: Provider, rhs: Provider) -> Bool {
        return lhs.id == rhs.id
    }
}

struct SubscriptionInfo: Codable {
    let upload: Int64
    let download: Int64
    let total: Int64
    let expire: Int64
    
    enum CodingKeys: String, CodingKey {
        case upload = "Upload"
        case download = "Download"
        case total = "Total"
        case expire = "Expire"
    }
}

class ProxyViewModel: ObservableObject {
    @Published var providers: [Provider] = []
    @Published var groups: [ProxyGroup] = []
    @Published var nodes: [ProxyNode] = []
    @Published var providerNodes: [String: [ProxyNode]] = [:]
    @Published var testingNodes: Set<String> = []
    @Published var lastUpdated = Date()
    @Published var lastDelayTestTime = Date()
    @Published var testingGroups: Set<String> = []
    @Published var savedNodeOrder: [String: [String]] = [:] // 移除 private 修饰符
    @Published var testingProviders: Set<String> = []
    
    private let server: ClashServer
    private var currentTask: Task<Void, Never>?
    private let settingsViewModel = SettingsViewModel()
    
    // 从 UserDefaults 读取设置
    private var testUrl: String {
        UserDefaults.standard.string(forKey: "speedTestURL") ?? "http://www.gstatic.com/generate_204"
    }
    
    private var testTimeout: Int {
        // 添加默认值 5000，与 GlobalSettingsView 中的默认值保持一致
        UserDefaults.standard.integer(forKey: "speedTestTimeout") == 0 
            ? 5000 
            : UserDefaults.standard.integer(forKey: "speedTestTimeout")
    }
    
    init(server: ClashServer) {
        self.server = server
        Task {
            await fetchProxies()
            settingsViewModel.fetchConfig(server: server)
        }
    }
    
    private func makeRequest(path: String) -> URLRequest? {
        let scheme = server.clashUseSSL ? "https" : "http"
        
        // 处理路径中的特殊字符
        let encodedPath = path.components(separatedBy: "/").map { component in
            component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? component
        }.joined(separator: "/")
        
        guard let url = URL(string: "\(scheme)://\(server.url):\(server.port)/\(encodedPath)") else {
            // print("❌ 无效的 URL，原始路径: \(path)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // print("📡 创建请求: \(url)")
        return request
    }
    
    @MainActor
    func fetchProxies() async {
        // print("🔄 开始获取代理数据...")
        do {
            // 1. 获取 proxies 数据
            guard let proxiesRequest = makeRequest(path: "proxies") else { 
                // print("❌ 创建 proxies 请求失败")
                return 
            }
            // print("📡 发送 proxies 请求...")
            let (proxiesData, _) = try await URLSession.shared.data(for: proxiesRequest)
            
            // 2. 获取 providers 数据
            guard let providersRequest = makeRequest(path: "providers/proxies") else { 
                // print("❌ 创建 providers 请求失败")
                return 
            }
            // print("📡 发送 providers 请求...")
            let (providersData, _) = try await URLSession.shared.data(for: providersRequest)
            
            var allNodes: [ProxyNode] = []
            
            // 3. 处理 proxies 数据
            if let proxiesResponse = try? JSONDecoder().decode(ProxyResponse.self, from: proxiesData) {
                // logger.log("✅ 成功解析 proxies 数据")
                let proxyNodes = proxiesResponse.proxies.map { name, proxy in
                    ProxyNode(
                        id: proxy.id ?? UUID().uuidString,
                        name: name,
                        type: proxy.type,
                        alive: proxy.alive ?? true,
                        delay: proxy.history.last?.delay ?? 0,
                        history: proxy.history
                    )
                }
                allNodes.append(contentsOf: proxyNodes)
                
                // 更新组数据
                let oldGroups = self.groups
                self.groups = proxiesResponse.proxies.compactMap { name, proxy in
                    guard proxy.all != nil else { return nil }
                    if proxy.hidden == true { return nil }
                    return ProxyGroup(
                        name: name,
                        type: proxy.type,
                        now: proxy.now ?? "",
                        all: proxy.all ?? [],
                        alive: proxy.alive ?? true,
                        icon: proxy.icon
                    )
                }
                // print("📊 代理组数量: \(self.groups.count)")
                
                // 打印组的变化
                // for group in self.groups {
                //     if let oldGroup = oldGroups.first(where: { $0.name == group.name }) {
                //         if oldGroup.now != group.now {
                //             print("📝 组 \(group.name) 的选中节点已更新: \(oldGroup.now) -> \(group.now)")
                //         }
                //     }
                // }
            } else {
                logger.log("❌ 解析 proxies 数据失败")
            }
            
            // 4. 处理 providers 数据
            if let providersResponse = try? JSONDecoder().decode(ProxyProvidersResponse.self, from: providersData) {
                // print("✅ 成功解析 providers 数据")
                // print("📦 代理提供者数量: \(providersResponse.providers.count)")
                
                // 更新 providers 属性时保持固定排序
                self.providers = providersResponse.providers.map { name, provider in
                    Provider(
                        name: name,
                        type: provider.type,
                        vehicleType: provider.vehicleType,
                        updatedAt: provider.updatedAt,
                        subscriptionInfo: provider.subscriptionInfo,
                        hidden: provider.hidden
                    )
                }
                .filter { $0.hidden != true } // 过滤掉 hidden 为 true 的提供者
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                // print("📦 更新后的提供者数量: \(self.providers.count)")
                
                // 更新 providerNodes
                for (providerName, provider) in providersResponse.providers {
                    let nodes = provider.proxies.map { proxy in
                        ProxyNode(
                            id: proxy.id ?? UUID().uuidString,
                            name: proxy.name,
                            type: proxy.type,
                            alive: proxy.alive ?? true,
                            delay: proxy.history.last?.delay ?? 0,
                            history: proxy.history
                        )
                    }
                    self.providerNodes[providerName] = nodes
                    // print("📦 提供者 \(providerName) 的节点数量: \(nodes.count)")
                }
                
                let providerNodes = providersResponse.providers.flatMap { _, provider in
                    provider.proxies.map { proxy in
                        ProxyNode(
                            id: proxy.id ?? UUID().uuidString,
                            name: proxy.name,
                            type: proxy.type,
                            alive: proxy.alive ?? true,
                            delay: proxy.history.last?.delay ?? 0,
                            history: proxy.history
                        )
                    }
                }
                allNodes.append(contentsOf: providerNodes)
            } else {
                print("❌ 解析 providers 数据失败")
                // 尝试打印原始数据以进行调试
                let jsonString = String(data: providersData, encoding: .utf8)
                    // print("📝 原始 providers 数据:")
                    // print(jsonString)
                
            }
            
            // 5. 更新节点数据
            self.nodes = allNodes
            // print("📊 总节点数量: \(allNodes.count)")
            objectWillChange.send()
            
        } catch {
            logger.log("❌ 获取代理错误: \(error)")
        }
    }
    
    func testGroupDelay(groupName: String, nodes: [ProxyNode]) async {
        for node in nodes {
            if node.name == "REJECT" || node.name == "DIRECT" {
                continue
            }
            
            let encodedGroupName = groupName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? groupName
            let path = "group/\(encodedGroupName)/delay"
            
            guard var request = makeRequest(path: path) else { continue }
            
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: true)
            components?.queryItems = [
                URLQueryItem(name: "url", value: testUrl),
                URLQueryItem(name: "timeout", value: "\(testTimeout)")
            ]
            
            guard let finalUrl = components?.url else { continue }
            request.url = finalUrl
            
            _ = await MainActor.run {
                testingNodes.insert(node.name)
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // 检查 HTTPS 响应
                if server.clashUseSSL,
                   let httpsResponse = response as? HTTPURLResponse,
                   httpsResponse.statusCode == 400 {
                    // print("SSL 连接失败，服务器可能不支持 HTTPS")
                    continue
                }
                
                if let delays = try? JSONDecoder().decode([String: Int].self, from: data) {
                    _ = await MainActor.run {
                        for (nodeName, delay) in delays {
                            updateNodeDelay(nodeName: nodeName, delay: delay)
                        }
                        testingNodes.remove(node.name)
                    }
                }
            } catch {
                _ = await MainActor.run {
                    testingNodes.remove(node.name)
                }
                handleNetworkError(error)
            }
        }
    }
    
    private func handleNetworkError(_ error: Error) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .secureConnectionFailed:
                logger.log("SSL 连接失败：服务器 SSL 证书无")
            case .serverCertificateHasBadDate:
                logger.log("SSL 错误：服务器证书已过期")
            case .serverCertificateUntrusted:
                logger.log("SSL 错误：服务器证书不受信任")
            case .serverCertificateNotYetValid:
                logger.log("SSL 错误：服务器证书尚未生效")
            case .cannotConnectToHost:
                logger.log("无法连接到服务器：\(server.clashUseSSL ? "HTTPS" : "HTTP") 连接失败")
            default:
                logger.log("网络错误：\(urlError.localizedDescription)")
            }
        } else {
            logger.log("其他错误：\(error.localizedDescription)")
        }
    }
    
    @MainActor
    func selectProxy(groupName: String, proxyName: String) async {
        logger.log("🔄 开始切换代理 - 组:\(groupName), 新节点:\(proxyName)")
        
        // 不需要在这里进行 URL 编码，因为 makeRequest 已经处理了
        guard var request = makeRequest(path: "proxies/\(groupName)") else { 
            // print("❌ 创建请求失败")
            return 
        }
        
        request.httpMethod = "PUT"
        let body = ["name": proxyName]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            logger.log("✅ 切换请求成功")
            
            if server.clashUseSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                // print("❌ SSL 连接失败")
                return
            }
            
            // 检查是否需要断开旧连接
            if UserDefaults.standard.bool(forKey: "autoDisconnectOldProxy") {
                logger.log("🔌 正在断开旧连接...")
                // 获取当前活跃的连接
                guard var connectionsRequest = makeRequest(path: "connections") else { return }
                let (data, _) = try await URLSession.shared.data(for: connectionsRequest)
                
                if let connectionsResponse = try? JSONDecoder().decode(ConnectionsResponse.self, from: data) {
                    // 遍所有活跃连接
                    for connection in connectionsResponse.connections {
                        // 如果连接的代理链包含当前切换的代理名称,则关闭该连接
                        if connection.chains.contains(proxyName) {
                            // 构建关闭连接的请求
                            guard var closeRequest = makeRequest(path: "connections/\(connection.id)") else { continue }
                            closeRequest.httpMethod = "DELETE"
                            
                            // 发送关闭请求
                            let (_, closeResponse) = try await URLSession.shared.data(for: closeRequest)
                            if let closeHttpResponse = closeResponse as? HTTPURLResponse,
                               closeHttpResponse.statusCode == 204 {
                                // print("成功关闭连接: \(connection.id)")
                            }
                        }
                    }
                }
            }
            
            // 获取实际需要测试的节点
            let nodeToTest = await getActualNode(proxyName)
            // print("🎯 获取到实际节点: \(nodeToTest)")
            
            // 如果不是 REJECT 且不是 DIRECT，则测试延迟
            if nodeToTest != "REJECT" {
                // print("⏱️ 开始测试节点延迟")
                await testNodeDelay(nodeName: nodeToTest)
            }
            
            // print("🔄 开始刷新代理数据")
            await fetchProxies()
            // print("✅ 代理切换流程完成")
            
        } catch {
            // print("❌ 切换代理时发生错误: \(error)")
            handleNetworkError(error)
        }
    }
    
    // 添加获取实际节点的方法
    private func getActualNode(_ nodeName: String, visitedGroups: Set<String> = []) async -> String {
        // 防止循环依赖
        if visitedGroups.contains(nodeName) {
            return nodeName
        }
        
        // 如果是代理组，递归获取当前选中的节点
        if let group = groups.first(where: { $0.name == nodeName }) {
            var visited = visitedGroups
            visited.insert(nodeName)
            return await getActualNode(group.now, visitedGroups: visited)
        }
        
        // 如果是实际节点或特殊节点，直接返回
        return nodeName
    }
    
    @MainActor
    func testNodeDelay(nodeName: String) async {
        // print("⏱️ 开始测试节点延迟: \(nodeName)")
        
        // 不需要在这里进行 URL 编码，因为 makeRequest 已经处理了
        guard var request = makeRequest(path: "proxies/\(nodeName)/delay") else {
            // print("❌ 创建延迟测试请求失败")
            return
        }
        
        // 添加测试参数
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "url", value: testUrl),
            URLQueryItem(name: "timeout", value: "\(testTimeout)")
        ]
        
        guard let finalUrl = components?.url else {
            // print("❌ 创建最终 URL 失败")
            return
        }
        request.url = finalUrl
        
        // 设置测试状态
        testingNodes.insert(nodeName)
        // print("🔄 节点已加入测试集合: \(nodeName)")
        objectWillChange.send()
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            // print("✅ 收到延迟测试响应")
            
            if server.clashUseSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                // print("❌ SSL 连接失败")
                testingNodes.remove(nodeName)
                objectWillChange.send()
                return
            }
            
            // 解析延迟数据
            struct DelayResponse: Codable {
                let delay: Int
            }
            
            if let delayResponse = try? JSONDecoder().decode(DelayResponse.self, from: data) {
                // print("📊 节点 \(nodeName) 的新延迟: \(delayResponse.delay)")
                // 更新节点延迟
                updateNodeDelay(nodeName: nodeName, delay: delayResponse.delay)
                testingNodes.remove(nodeName)
                self.lastDelayTestTime = Date()
                objectWillChange.send()
                // print("✅ 延迟更新完成")
            } else {
                // print("❌ 解析延迟数据失败")
                testingNodes.remove(nodeName)
                objectWillChange.send()
            }
            
        } catch {
            // print("❌ 测试节点延迟时发生错误: \(error)")
            testingNodes.remove(nodeName)
            objectWillChange.send()
            handleNetworkError(error)
        }
    }
    
    // 修改更新节点延迟的方法
    private func updateNodeDelay(nodeName: String, delay: Int) {
        // logger.log("🔄 开始更新节点延迟 - 节点:\(nodeName), 新延迟:\(delay)")
        
        if let index = nodes.firstIndex(where: { $0.name == nodeName }) {
            let oldDelay = nodes[index].delay
            let updatedNode = ProxyNode(
                id: nodes[index].id,
                name: nodeName,
                type: nodes[index].type,
                alive: true,
                delay: delay,
                history: nodes[index].history
            )
            nodes[index] = updatedNode
            logger.log("✅ 节点延迟已更新 - 原延迟:\(oldDelay), 新延迟:\(delay)")
            objectWillChange.send()
        } else {
            logger.log("⚠️ 未找到要更新的节点: \(nodeName)")
        }
    }
    
    @MainActor
    func refreshAllData() async {
        do {
            // 1. 获取理数据
            await fetchProxies()
            
            // 2. 测试所有节点延迟
            for group in groups {
                if let nodes = providerNodes[group.name] {
                    await testGroupDelay(groupName: group.name, nodes: nodes)
                }
            }
        } catch {
            print("Error refreshing all data: \(error)")
        }
    }
    
    // 修改组测速方法
    @MainActor
    func testGroupSpeed(groupName: String) async {
        // print("开始测速组: \(groupName)")
        // print("测速前节点状态:")
        if let group = groups.first(where: { $0.name == groupName }) {
            for nodeName in group.all {
                if let node = nodes.first(where: { $0.name == nodeName }) {
                    // print("节点: \(nodeName), 延迟: \(node.delay)")
                }
            }
        }
        
        // 添加到测速集合
        testingGroups.insert(groupName)
        objectWillChange.send()
        
        let encodedGroupName = groupName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? groupName
        guard var request = makeRequest(path: "group/\(encodedGroupName)/delay") else {
            // print("创建请求失败")
            return
        }
        
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "url", value: testUrl),
            URLQueryItem(name: "timeout", value: "\(testTimeout)")
        ]
        
        guard let finalUrl = components?.url else {
            print("创建最终 URL 失败")
            return
        }
        request.url = finalUrl
        
        // print("发送测速请求: \(finalUrl)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            // print("收到服务器响应: \(response)")
            
            if server.clashUseSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                print("SSL 连接失败，服务器可能不支持 HTTPS")
                testingGroups.remove(groupName)
                objectWillChange.send()
                return
            }
            
            // print("解析响应数据...")
            if let decodedData = try? JSONDecoder().decode([String: Int].self, from: data) {
                // print("\n收到测速响应:")
                for (nodeName, delay) in decodedData {
                    // print("节点: \(nodeName), 新延迟: \(delay)")
                    // 直接更新节点延迟，不需要先 fetchProxies
                    updateNodeDelay(nodeName: nodeName, delay: delay)
                }
                
                // 如果是 URL-Test 类型的组，自动切换到延迟最低的节点
                if let group = groups.first(where: { $0.name == groupName }),
                   group.type == "URLTest" {
                    // 找出延迟最低的节点
                    var lowestDelay = Int.max
                    var bestNode = ""
                    
                    for nodeName in group.all {
                        if nodeName == "DIRECT" || nodeName == "REJECT" {
                            continue
                        }
                        let delay = getNodeDelay(nodeName: nodeName)
                        if delay > 0 && delay < lowestDelay {
                            lowestDelay = delay
                            bestNode = nodeName
                        }
                    }
                    
                    // 如果找到了最佳节点，切换到该节点
                    if !bestNode.isEmpty {
                        logger.log("🔄 URL-Test 组测速完成，自动切换到最佳节点: \(bestNode) (延迟: \(lowestDelay)ms)")
                        await selectProxy(groupName: groupName, proxyName: bestNode)
                    }
                }
                
                // print("\n更新后节点状态:")
                if let group = groups.first(where: { $0.name == groupName }) {
                    for nodeName in group.all {
                        if let node = nodes.first(where: { $0.name == nodeName }) {
                            // print("节点: \(nodeName), 最终延迟: \(node.delay)")
                        }
                    }
                }
                
                // 更新最后测试时间并通知视图更新
                self.lastDelayTestTime = Date()
                objectWillChange.send()
            }
        } catch {
            // print("测速过程出错: \(error)")
            handleNetworkError(error)
        }
        
        // print("测速完成，移除测速状态")
        testingGroups.remove(groupName)
        objectWillChange.send()
    }
    
    @MainActor
    func updateProxyProvider(providerName: String) async {
        let encodedProviderName = providerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? providerName
        guard var request = makeRequest(path: "providers/proxies/\(encodedProviderName)") else { return }
        
        request.httpMethod = "PUT"

        // print("\(request.url)")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if server.clashUseSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                // print("SSL 连接失败，服务器可能不支持 HTTPS")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                // print("代理提供者 \(providerName) 更新成功")
                
                // 等待一小段时间确保服务器处理完成
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                
                // 在主线程上更新
                await MainActor.run {
                    // 更新时间戳
                    self.lastUpdated = Date()
                    
                    // 刷数据
                    Task {
                        await self.fetchProxies()
                    }
                }
            } else {
                logger.log("代理提供者 \(providerName) 更新失败")
            }
        } catch {
            handleNetworkError(error)
        }
    }
    
    // 代理提供者整体健康检查
    @MainActor
    func healthCheckProvider(providerName: String) async {
        let encodedProviderName = providerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? providerName
        guard let request = makeRequest(path: "providers/proxies/\(encodedProviderName)/healthcheck") else { return }
        
        // 添加到测试集合
        testingProviders.insert(providerName)
        objectWillChange.send()
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if server.clashUseSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                // print("SSL 连接失败，服务器可能不支持 HTTPS")
                testingProviders.remove(providerName)  // 记得移除
                return
            }
            
            // 等待一小段时间确保服务器处理完成
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            // 在主线程刷新数据
            await MainActor.run {
                Task {
                    await self.fetchProxies()
                    self.lastDelayTestTime = Date()
                    testingProviders.remove(providerName)  // 记得移除
                    objectWillChange.send()
                }
            }
            
        } catch {
            testingProviders.remove(providerName)  // 记得移除
            handleNetworkError(error)
        }
    }
    
    // 代理提供者中单个节点的健康检查
    @MainActor
    func healthCheckProviderProxy(providerName: String, proxyName: String) async {
        let encodedProviderName = providerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? providerName
        let encodedProxyName = proxyName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? proxyName
        
        guard var request = makeRequest(path: "providers/proxies/\(encodedProviderName)/\(encodedProxyName)/healthcheck") else { return }
        
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "url", value: testUrl),
            URLQueryItem(name: "timeout", value: "\(testTimeout)")
        ]
        
        guard let finalUrl = components?.url else { return }
        request.url = finalUrl

        // print("\(request.url)")
        
        // 设置测试状
        await MainActor.run {
            testingNodes.insert(proxyName)
            objectWillChange.send()
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if server.clashUseSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                // print("SSL 连接失败，服务器可能不支持 HTTPS")
                _ = await MainActor.run {
                    testingNodes.remove(proxyName)
                    objectWillChange.send()
                }
                return
            }
            
            // 解析返回的延迟数据
            struct DelayResponse: Codable {
                let delay: Int
            }
            
            if let delayResponse = try? JSONDecoder().decode(DelayResponse.self, from: data) {
                await MainActor.run {
                    // 更新节点延迟
                    updateNodeDelay(nodeName: proxyName, delay: delayResponse.delay)
                    testingNodes.remove(proxyName)
                    self.lastDelayTestTime = Date()  // 发视图更新
                    objectWillChange.send()
                    
                    // 刷新数据
                    Task {
                        await self.fetchProxies()
                    }
                }
            } else {
                // 如果析失败，确保移除节点名称
                await MainActor.run {
                    testingNodes.remove(proxyName)
                    objectWillChange.send()
                }
            }
            
        } catch {
            _ = await MainActor.run {
                testingNodes.remove(proxyName)
                objectWillChange.send()
            }
            handleNetworkError(error)
        }
    }
    
    // 修改 getSortedGroups 方法，只保留 GLOBAL 组排序逻辑
    func getSortedGroups() -> [ProxyGroup] {
        // 获取 GLOBAL 组的排序索引
        if let globalGroup = groups.first(where: { $0.name == "GLOBAL" }) {
            var sortIndex = globalGroup.all
            sortIndex.append("GLOBAL") // 将 GLOBAL 添加到末尾
            
            return groups.sorted { group1, group2 in
                let index1 = sortIndex.firstIndex(of: group1.name) ?? Int.max
                let index2 = sortIndex.firstIndex(of: group2.name) ?? Int.max
                return index1 < index2
            }
        }
        
        // 如果找不到 GLOBAL 组，用字顺序
        return groups.sorted { $0.name < $1.name }
    }
    
    // 修改节点排序方法
    func getSortedNodes(_ nodeNames: [String], in group: ProxyGroup) -> [String] {
        // 获取排序设置
        let sortOrder = UserDefaults.standard.string(forKey: "proxyGroupSortOrder") ?? "default"
        
        // 特殊节点始终排在最前面（添加 PROXY）
        let specialNodes = nodeNames.filter { node in
            ["DIRECT", "REJECT", "PROXY"].contains(node.uppercased())
        }
        let normalNodes = nodeNames.filter { node in
            !["DIRECT", "REJECT", "PROXY"].contains(node.uppercased())
        }
        
        // 检查是否需要隐藏不可用代理
        let hideUnavailable = UserDefaults.standard.bool(forKey: "hideUnavailableProxies")
        let filteredNormalNodes = hideUnavailable ? 
            normalNodes.filter { node in
                getNodeDelay(nodeName: node) > 0
            } : normalNodes
        
        // 根据排序设置对普通节点进行排序
        let sortedNormalNodes: [String]
        switch sortOrder {
        case "latencyAsc":
            sortedNormalNodes = filteredNormalNodes.sorted { node1, node2 in
                let delay1 = getNodeDelay(nodeName: node1)
                let delay2 = getNodeDelay(nodeName: node2)
                if delay1 == 0 { return false }
                if delay2 == 0 { return true }
                return delay1 < delay2
            }
        case "latencyDesc":
            sortedNormalNodes = filteredNormalNodes.sorted { node1, node2 in
                let delay1 = getNodeDelay(nodeName: node1)
                let delay2 = getNodeDelay(nodeName: node2)
                if delay1 == 0 { return false }
                if delay2 == 0 { return true }
                return delay1 > delay2
            }
        case "nameAsc":
            sortedNormalNodes = filteredNormalNodes.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        case "nameDesc":
            sortedNormalNodes = filteredNormalNodes.sorted { $0.localizedStandardCompare($1) == .orderedDescending }
        default:
            sortedNormalNodes = filteredNormalNodes
        }
        
        // 合并特殊节点和排序后的普通节点
        return specialNodes + sortedNormalNodes
    }
    
    // 添加辅助方法来获取有效延迟
    private func getEffectiveDelay(_ nodeName: String) -> Int {
        let delay = self.nodes.first(where: { $0.name == nodeName })?.delay ?? Int.max
        return delay == 0 ? Int.max : delay
    }
    
    // 添加方法来保存节点顺序
    func saveNodeOrder(for groupName: String, nodes: [String]) {
        savedNodeOrder[groupName] = nodes
    }
    
    // 添加方法来清除保存的节点顺序
    func clearSavedNodeOrder(for groupName: String) {
        savedNodeOrder.removeValue(forKey: groupName)
    }
    
    // 修改 getNodeDelay 方法
    func getNodeDelay(nodeName: String, visitedGroups: Set<String> = []) -> Int {
        // 检查是否是特殊节点（不区分大小写）
        let upperNodeName = nodeName.uppercased()
        if ["REJECT"].contains(upperNodeName) {
            return 0  // 返回 0 表示拒绝连接
        }
        
        // 防止循环依赖
        if visitedGroups.contains(nodeName) {
            return 0
        }
        
        // 如果是代理组，递归获取当前选中节点的延迟
        if let group = groups.first(where: { $0.name == nodeName }) {
            var visited = visitedGroups
            visited.insert(nodeName)
            
            // 获取当前选中的节点
            let currentNodeName = group.now
            // 递归获取实际节点的延迟，传递已访问的组列表
            return getNodeDelay(nodeName: currentNodeName, visitedGroups: visited)
        }
        
        // 如果是实际节点，返回节点延迟
        if let node = nodes.first(where: { $0.name.uppercased() == upperNodeName }) {
            return node.delay
        }
        
        return 0
    }
}

// API 响应模型
struct ProxyResponse: Codable {
    let proxies: [String: ProxyDetail]
}

// 修改 ProxyDetail 结构体，使其更灵活
struct ProxyDetail: Codable {
    let name: String
    let type: String
    let now: String?
    let all: [String]?
    let history: [ProxyHistory]
    let icon: String?
    
    // 添加可选字段
    let alive: Bool?
    let hidden: Bool?
    let tfo: Bool?
    let udp: Bool?
    let xudp: Bool?
    let extra: [String: AnyCodable]?
    let id: String?
    
    private enum CodingKeys: String, CodingKey {
        case name, type, now, all, history
        case alive, hidden, icon, tfo, udp, xudp, extra, id
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 必需字段
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        
        // 可选字段
        now = try container.decodeIfPresent(String.self, forKey: .now)
        all = try container.decodeIfPresent([String].self, forKey: .all)
        
        // 处理 history 字段
        if let historyArray = try? container.decode([ProxyHistory].self, forKey: .history) {
            history = historyArray
        } else {
            history = []
        }
        
        // 其他可选字段
        alive = try container.decodeIfPresent(Bool.self, forKey: .alive)
        hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        tfo = try container.decodeIfPresent(Bool.self, forKey: .tfo)
        udp = try container.decodeIfPresent(Bool.self, forKey: .udp)
        xudp = try container.decodeIfPresent(Bool.self, forKey: .xudp)
        extra = try container.decodeIfPresent([String: AnyCodable].self, forKey: .extra)
        id = try container.decodeIfPresent(String.self, forKey: .id)
    }
}

// 添加 AnyCodable 类型来处理任意类型的值
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// 添加 ProviderResponse 结构体
struct ProviderResponse: Codable {
    let type: String
    let vehicleType: String
    let proxies: [ProxyInfo]?
    let testUrl: String?
    let subscriptionInfo: SubscriptionInfo?
    let updatedAt: String?
}

// 添加 Extra 结构体定义
struct Extra: Codable {
    let alpn: [String]?
    let tls: Bool?
    let skip_cert_verify: Bool?
    let servername: String?
}

struct ProxyInfo: Codable {
    let name: String
    let type: String
    let alive: Bool
    let history: [ProxyHistory]
    let extra: Extra?
    let id: String?
    let tfo: Bool?
    let xudp: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case name, type, alive, history, extra, id, tfo, xudp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        alive = try container.decode(Bool.self, forKey: .alive)
        history = try container.decode([ProxyHistory].self, forKey: .history)
        
        // Meta 服务器特有的字段设为选
        extra = try container.decodeIfPresent(Extra.self, forKey: .extra)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        tfo = try container.decodeIfPresent(Bool.self, forKey: .tfo)
        xudp = try container.decodeIfPresent(Bool.self, forKey: .xudp)
    }
    
    // 添加编码方法
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(alive, forKey: .alive)
        try container.encode(history, forKey: .history)
        try container.encodeIfPresent(extra, forKey: .extra)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(tfo, forKey: .tfo)
        try container.encodeIfPresent(xudp, forKey: .xudp)
    }
} 
