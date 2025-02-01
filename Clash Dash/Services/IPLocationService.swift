import Foundation

actor IPLocationService {
    static let shared = IPLocationService()
    private var cache: [String: IPLocation] = [:]
    
    private init() {}
    
    func getLocation(for ip: String) async throws -> IPLocation {
        // 检查缓存
        if let cached = cache[ip] {
            return cached
        }
        
        // 构建 URL
        guard let url = URL(string: "http://ip-api.com/json/\(ip)") else {
            throw URLError(.badURL)
        }
        
        // 发起请求
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // 解码响应
        let location = try JSONDecoder().decode(IPLocation.self, from: data)
        
        // 缓存结果
        cache[ip] = location
        
        return location
    }
    
    func clearCache() {
        cache.removeAll()
    }
} 