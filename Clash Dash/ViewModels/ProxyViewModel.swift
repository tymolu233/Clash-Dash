import Foundation

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
    
    init(name: String, type: String, now: String, all: [String], alive: Bool = true) {
        self.name = name
        self.type = type
        self.now = now
        self.all = all
        self.alive = alive
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
    @Published private var savedNodeOrder: [String: [String]] = [:] // 用于存储每个组的节点顺序
    
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
        let scheme = server.useSSL ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(server.url):\(server.port)/\(path)") else {
            print("无效的 URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    @MainActor
    func fetchProxies() async {
        do {
            // 1. 获取 proxies 数据
            guard let proxiesRequest = makeRequest(path: "proxies") else { return }
            let (proxiesData, _) = try await URLSession.shared.data(for: proxiesRequest)
            
            // 2. 获取 providers 数据
            guard let providersRequest = makeRequest(path: "providers/proxies") else { return }
            let (providersData, _) = try await URLSession.shared.data(for: providersRequest)
            
            var allNodes: [ProxyNode] = []
            
            // 3. 处理 proxies 数据
            if let proxiesResponse = try? JSONDecoder().decode(ProxyResponse.self, from: proxiesData) {
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
                self.groups = proxiesResponse.proxies.compactMap { name, proxy in
                    guard proxy.all != nil else { return nil }
                    return ProxyGroup(
                        name: name,
                        type: proxy.type,
                        now: proxy.now ?? "",
                        all: proxy.all ?? []
                    )
                }
            }
            
            // 4. 处理 providers 数据
            if let providersResponse = try? JSONDecoder().decode(ProxyProvidersResponse.self, from: providersData) {
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
            }
            
            // 5. 更新节点数据
            self.nodes = allNodes
            objectWillChange.send()
            
        } catch {
            print("获取代理错误: \(error)")
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
                if server.useSSL,
                   let httpsResponse = response as? HTTPURLResponse,
                   httpsResponse.statusCode == 400 {
                    print("SSL 连接失败，服务器可能不支持 HTTPS")
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
                print("SSL 连接失败：服务器 SSL 证书无")
            case .serverCertificateHasBadDate:
                print("SSL 错误：服务器证书已过期")
            case .serverCertificateUntrusted:
                print("SSL 错误：服务器证书不受信任")
            case .serverCertificateNotYetValid:
                print("SSL 错误：服务器证书尚未生效")
            case .cannotConnectToHost:
                print("无法连接到服务器：\(server.useSSL ? "HTTPS" : "HTTP") 连接失败")
            default:
                print("网络错误：\(urlError.localizedDescription)")
            }
        } else {
            print("其他错误：\(error.localizedDescription)")
        }
    }
    
    func selectProxy(groupName: String, proxyName: String) async {
        let encodedGroupName = groupName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? groupName
        guard var request = makeRequest(path: "proxies/\(encodedGroupName)") else { return }
        
        request.httpMethod = "PUT"
        let body = ["name": proxyName]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if server.useSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                // print("SSL 连接失败，服务器可能不支持 HTTPS")
                return
            }
            
            // 检查是否需要���动断开连接
            if UserDefaults.standard.bool(forKey: "autoDisconnectOldProxy") {
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
            
            if proxyName != "REJECT" {
                await testNodeDelay(nodeName: proxyName)
            }
            await fetchProxies()
            
        } catch {
            handleNetworkError(error)
        }
    }
    
    // 修改 testNodeDelay 方法以支持 DIRECT 节点
    @MainActor
    func testNodeDelay(nodeName: String) async {
        guard var request = makeRequest(path: "proxies/\(nodeName)/delay") else { return }
        
        // 添加测试参数
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "url", value: testUrl),
            URLQueryItem(name: "timeout", value: "\(testTimeout)")
        ]
        
        guard let finalUrl = components?.url else { return }
        request.url = finalUrl
        
        // 设置测试状态
        testingNodes.insert(nodeName)
        objectWillChange.send()
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if server.useSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                // print("SSL 连接失败，服务器可能不支持 HTTPS")
                testingNodes.remove(nodeName)
                objectWillChange.send()
                return
            }
            
            // 解析延迟数据
            struct DelayResponse: Codable {
                let delay: Int
            }
            
            if let delayResponse = try? JSONDecoder().decode(DelayResponse.self, from: data) {
                // 更新节点延迟
                updateNodeDelay(nodeName: nodeName, delay: delayResponse.delay)
                testingNodes.remove(nodeName)
                self.lastDelayTestTime = Date()
                objectWillChange.send()
            } else {
                testingNodes.remove(nodeName)
                objectWillChange.send()
            }
            
        } catch {
            testingNodes.remove(nodeName)
            objectWillChange.send()
            handleNetworkError(error)
        }
    }
    
    // 辅助法：更新节点延迟
    private func updateNodeDelay(nodeName: String, delay: Int) {
        if let index = nodes.firstIndex(where: { $0.name == nodeName }) {
            let updatedNode = ProxyNode(
                id: nodes[index].id,
                name: nodeName,
                type: nodes[index].type,
                alive: true,
                delay: delay,
                history: nodes[index].history
            )
            nodes[index] = updatedNode
            // print("DEBUG: 更新节点延迟 - 名称:\(nodeName), 新延迟:\(delay)")
            objectWillChange.send()
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
            
            if server.useSSL,
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
            } else {
                print("解析响应数据��败")
            }
        } catch {
            print("测速过程出错: \(error)")
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
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if server.useSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                print("SSL 连接失败，服务器可能不支持 HTTPS")
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
                print("代理提供者 \(providerName) 更新失败")
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
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if server.useSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                print("SSL 连接失败，服务器可能不支持 HTTPS")
                return
            }
            
            // 等待一小段时间确保服务器处理完成
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            // 在主线程刷新数据
            await MainActor.run {
                Task {
                    await self.fetchProxies()
                    self.lastDelayTestTime = Date()
                    objectWillChange.send()
                }
            }
            
        } catch {
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
        
        // 设置测试状
        await MainActor.run {
            testingNodes.insert(proxyName)
            objectWillChange.send()
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if server.useSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                print("SSL 连接失败，服务器可能不支持 HTTPS")
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
                    self.lastDelayTestTime = Date()  // 触发视图更新
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
        
        // 如果找不到 GLOBAL 组，用字��顺序
        return groups.sorted { $0.name < $1.name }
    }
    
    // 修改节点排序方法
    func getSortedNodes(_ nodes: [String], in group: ProxyGroup, useCache: Bool = false) -> [String] {
        // 如果使用缓存且存在已保存的顺序，直接返回
        if useCache, let savedOrder = savedNodeOrder[group.name] {
            return savedOrder
        }
        
        let specialNodes = ["DIRECT", "REJECT", "Proxy"]
        let hideUnavailable = UserDefaults.standard.bool(forKey: "hideUnavailableProxies")
        
        var filteredNodes = nodes
        if hideUnavailable {
            filteredNodes = nodes.filter { nodeName in
                if specialNodes.contains(nodeName) {
                    return true
                }
                let delay = self.nodes.first(where: { $0.name == nodeName })?.delay ?? 0
                return delay > 0
            }
        }
        
        let sortOrder = UserDefaults.standard.string(forKey: "proxyGroupSortOrder") ?? "default"
        
        return filteredNodes.sorted { node1, node2 in
            let specialOrder = ["DIRECT", "REJECT", "Proxy"]
            if let index1 = specialOrder.firstIndex(of: node1),
               let index2 = specialOrder.firstIndex(of: node2) {
                return index1 < index2
            }
            if let index1 = specialOrder.firstIndex(of: node1) {
                return true
            }
            if let index2 = specialOrder.firstIndex(of: node2) {
                return false
            }
            
            switch sortOrder {
            case "latencyAsc":
                let delay1 = getEffectiveDelay(node1)
                let delay2 = getEffectiveDelay(node2)
                return delay1 < delay2
                
            case "latencyDesc":
                let delay1 = getEffectiveDelay(node1)
                let delay2 = getEffectiveDelay(node2)
                return delay1 > delay2
                
            case "nameAsc":
                return node1 < node2
                
            case "nameDesc":
                return node1 > node2
                
            default:
                return false
            }
        }
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
    
    // 添加可选字段
    let alive: Bool?
    let hidden: Bool?
    let icon: String?
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
