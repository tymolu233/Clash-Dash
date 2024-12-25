struct OpenWRTStatus: Codable {
    let clash: Bool
    let web: Bool
    let daip: String
    let dase: String
    let cnPort: String
    let coreType: String
    let dbForwardPort: String?
    let dbForwardDomain: String?
    let dbForwardSsl: String?
    let watchdog: Bool
    
    enum CodingKeys: String, CodingKey {
        case clash, web, daip, dase
        case cnPort = "cn_port"
        case coreType = "core_type"
        case dbForwardPort = "db_foward_port"
        case dbForwardDomain = "db_foward_domain"
        case dbForwardSsl = "db_forward_ssl"
        case watchdog
    }
} 