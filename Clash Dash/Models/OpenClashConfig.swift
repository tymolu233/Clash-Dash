import Foundation

struct OpenClashConfig: Identifiable {
    let id = UUID()
    let name: String
    let state: ConfigState
    let mtime: Date
    let check: ConfigCheck
    let subscription: SubscriptionInfo?
    
    enum ConfigState: String {
        case enabled = "Enabled"
        case disabled = "Disabled"
    }
    
    enum ConfigCheck: String {
        case normal = "配置检查通过"
        case abnormal = "配置检查不通过"
        case checkFailed = "检查失败"
    }
    
    struct SubscriptionInfo: Codable {
        let surplus: String?
        let total: String?
        let dayLeft: Int?
        let httpCode: String?
        let used: String?
        let expire: String?
        let subInfo: String
        let percent: String?
        
        enum CodingKeys: String, CodingKey {
            case surplus, total, used, expire, percent
            case dayLeft = "day_left"
            case httpCode = "http_code"
            case subInfo = "sub_info"
        }
    }
} 