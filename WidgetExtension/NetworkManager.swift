import Foundation
import Shared

class WidgetNetworkManager {
    static let shared = WidgetNetworkManager()
    private let sharedDataManager = SharedDataManager.shared
    private let session = URLSession(configuration: .default)
    
    private init() {}
    
    func fetchStatus(for serverAddress: String, completion: @escaping (ClashStatus?) -> Void) {
        print("[Widget] 检查服务器设置: \(serverAddress)")
        let cleanServerAddress = serverAddress.components(separatedBy: ":")[0]
        print("[Widget] 清理后的服务器地址: \(cleanServerAddress)")
        
        let secret = sharedDataManager.getSecret(for: serverAddress)
        print("[Widget] Secret状态: \(secret != nil ? "已找到" : "未找到")")
        
        let useSSL = sharedDataManager.getUseSSL(for: serverAddress)
        print("[Widget] useSSL 设置: \(useSSL)")
        
        let scheme = useSSL ? "https" : "http"
        print("[Widget] 使用的 scheme: \(scheme)")
        
        print("[Widget] Server address for secret: \(serverAddress)")
        
        // 获取连接数据
        fetchConnections(serverAddress: serverAddress, scheme: scheme, secret: secret) { connectionsData in
            if let connectionsData = connectionsData {
                // 计算内存使用量（MB）
                let memoryUsage = connectionsData.memory.map { Double($0) / 1024.0 / 1024.0 }
                
                // 获取服务器信息
                print("[Widget] 开始获取保存的服务器信息: \(serverAddress)")
                let savedStatus = self.sharedDataManager.getClashStatus(for: serverAddress)
                print("[Widget] 获取到的服务器信息:")
                print("[Widget] - 保存的地址: \(savedStatus.serverAddress)")
                print("[Widget] - 保存的名称: \(savedStatus.serverName ?? "nil")")
                
                // 创建状态
                let status = ClashStatus(
                    serverAddress: serverAddress,
                    serverName: savedStatus.serverName,
                    activeConnections: connectionsData.connections.count,
                    uploadTotal: Int64(connectionsData.uploadTotal),
                    downloadTotal: Int64(connectionsData.downloadTotal),
                    memoryUsage: memoryUsage
                )
                
                print("[Widget] 创建的新状态:")
                print("[Widget] - Server address: \(status.serverAddress)")
                print("[Widget] - Server name: \(status.serverName ?? "nil")")
                print("[Widget] - Connections: \(status.activeConnections)")
                print("[Widget] - Upload: \(status.uploadTotal)")
                print("[Widget] - Download: \(status.downloadTotal)")
                print("[Widget] - Memory: \(status.memoryUsage ?? 0) MB")
                
                completion(status)
            } else {
                print("[Widget] Failed to get connections data")
                completion(nil)
            }
        }
    }
    
    private func fetchConnections(serverAddress: String, scheme: String, secret: String?, completion: @escaping (ConnectionsData?) -> Void) {
        guard let url = URL(string: "\(scheme)://\(serverAddress)/connections") else {
            print("[Widget] Invalid URL for connections")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        if let secret = secret {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 5
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[Widget] Error fetching connections: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                print("[Widget] Invalid response for connections")
                completion(nil)
                return
            }
            
            do {
                let connectionsData = try JSONDecoder().decode(ConnectionsData.self, from: data)
                completion(connectionsData)
            } catch {
                print("[Widget] Error decoding connections data: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[Widget] Raw JSON data: \(jsonString)")
                }
                completion(nil)
            }
        }
        
        task.resume()
    }
} 
