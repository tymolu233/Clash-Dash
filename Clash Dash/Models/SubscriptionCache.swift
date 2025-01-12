import Foundation

class SubscriptionCache {
    static let shared = SubscriptionCache()
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    struct CachedData: Codable {
        let subscriptions: [SubscriptionCardInfo]
        let timestamp: Date
        
        var isStale: Bool {
            // 缓存超过1小时认为过期
            return Date().timeIntervalSince(timestamp) > 3600
        }
    }
    
    private func cacheKey(for server: ClashServer) -> String {
        return "subscription_cache_\(server.id.uuidString)"
    }
    
    private func lastUpdateKey(for server: ClashServer) -> String {
        return "subscription_last_update_\(server.id.uuidString)"
    }
    
    func save(subscriptions: [SubscriptionCardInfo], for server: ClashServer) {
        let cachedData = CachedData(subscriptions: subscriptions, timestamp: Date())
        if let encoded = try? JSONEncoder().encode(cachedData) {
            defaults.set(encoded, forKey: cacheKey(for: server))
            defaults.set(Date(), forKey: lastUpdateKey(for: server))
        }
    }
    
    func load(for server: ClashServer) -> [SubscriptionCardInfo]? {
        guard let data = defaults.data(forKey: cacheKey(for: server)),
              let cachedData = try? JSONDecoder().decode(CachedData.self, from: data)
        else {
            return nil
        }
        return cachedData.subscriptions
    }
    
    func getLastUpdateTime(for server: ClashServer) -> Date? {
        return defaults.object(forKey: lastUpdateKey(for: server)) as? Date
    }
    
    func clear(for server: ClashServer) {
        defaults.removeObject(forKey: cacheKey(for: server))
        defaults.removeObject(forKey: lastUpdateKey(for: server))
    }
    
    func clearAll() {
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix("subscription_cache_") || key.hasPrefix("subscription_last_update_") {
                defaults.removeObject(forKey: key)
            }
        }
    }
} 