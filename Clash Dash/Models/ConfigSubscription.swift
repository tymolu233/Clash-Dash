import Foundation

struct ConfigSubscription: Identifiable, Codable, Equatable {
    var id: Int  // 对应 [0], [1] 等索引
    var name: String
    var address: String
    var enabled: Bool
    var subUA: String
    var subConvert: Bool
    var keyword: String?
    var exKeyword: String?
    
    static func == (lhs: ConfigSubscription, rhs: ConfigSubscription) -> Bool {
        lhs.id == rhs.id
    }
}

extension ConfigSubscription {
    // 用于创建新订阅时的便利初始化器
    static func new(id: Int = 0) -> ConfigSubscription {
        ConfigSubscription(
            id: id,
            name: "",
            address: "",
            enabled: true,
            subUA: "Clash",
            subConvert: false
        )
    }
    
    // 用于验证订阅信息是否完整
    var isValid: Bool {
        !name.isEmpty && !address.isEmpty
    }
    
    // 用于生成 UCI 命令
    func uciCommands(forId id: Int? = nil) -> [String] {
        let index = id ?? self.id
        return [
            "uci set openclash.@config_subscribe[\(index)].name='\(name)'",
            "uci set openclash.@config_subscribe[\(index)].address='\(address)'",
            "uci set openclash.@config_subscribe[\(index)].sub_ua='\(subUA)'",
            "uci set openclash.@config_subscribe[\(index)].enabled='\(enabled ? "1" : "0")'",
            "uci set openclash.@config_subscribe[\(index)].sub_convert='\(subConvert ? "1" : "0")'",
            keyword.map { "uci set openclash.@config_subscribe[\(index)].keyword='\($0)'" },
            exKeyword.map { "uci set openclash.@config_subscribe[\(index)].ex_keyword='\($0)'" }
        ].compactMap { $0 }
    }
}