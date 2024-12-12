struct OpenWRTStatus: Codable {
    let web: Bool
    let clash: Bool
    let daip: String
    let cnPort: String
    let dase: String
    let coreType: String
    
    let dbForwardSSL: String?
    let restrictedMode: String?
    let watchdog: Bool?
    
    enum CodingKeys: String, CodingKey {
        case web
        case clash
        case daip
        case dbForwardSSL = "db_forward_ssl"
        case restrictedMode = "restricted_mode"
        case cnPort = "cn_port"
        case dase
        case watchdog
        case coreType = "core_type"
    }
} 