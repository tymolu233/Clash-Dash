import Foundation

struct OpenClashConfig: Identifiable {
    let id = UUID()
    let name: String
    let state: ConfigState
    let mtime: Date
    let check: ConfigCheck
    let subscription: SubscriptionInfo?
    let fileSize: Int64
    var isSubscription: Bool = false
    
    enum ConfigState: String {
        case enabled = "Enabled"
        case disabled = "Disabled"
    }
    
    enum ConfigCheck: String {
        case normal = "YAML 语法检查通过"
        case abnormal = "YAML 语法检查不通过"
        case checkFailed = "YAML 语法检查失败"
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