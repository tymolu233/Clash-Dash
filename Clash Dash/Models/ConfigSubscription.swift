import Foundation

struct ConfigSubscription: Identifiable, Codable, Equatable {
    var id: Int
    var name: String
    var address: String
    var enabled: Bool
    var subUA: String
    var subConvert: Bool
    var convertAddress: String?
    var template: String?
    var emoji: Bool?
    var udp: Bool?
    var skipCertVerify: Bool?
    var sort: Bool?
    var nodeType: Bool?
    var ruleProvider: Bool?
    var keyword: String?
    var exKeyword: String?
    var customParams: [String]?
    
    // 转换模板选项
    static let templateOptions = [
        "默认（附带用于Clash的AdGuard DNS）",
        "无Urltest",
        "带Urltest",
        "ConnersHua 神机规则 Pro",
        "lhie1 洞主规则（使用 Clash 分组规则）",
        "lhie1 洞主规则完整版",
        "ACL4SSR 规则标准版",
        "ACL4SSR 规则 Mini",
        "ACL4SSR 规则 Mini NoAuto",
        "ACL4SSR 规则 Online",
        "ACL4SSR 规则 Online Mini",
        "ACL4SSR 规则 Online Full"
    ]
    
    // 转换服务地址选项
    static let convertAddressOptions = [
        "https://api.dler.io/sub",
        "https://v.id9.cc/sub",
        "https://sub.id9.cc/sub",
        "https://api.wcc.best/sub"
    ]
    
    // 修改 userAgentOptions 的值，使用小写作为 tag
    static let userAgentOptions: [(text: String, value: String)] = [
        ("Clash", "clash"),
        ("Clash Meta", "clash.meta")
    ]
    
    init(id: Int = 0,
         name: String = "",
         address: String = "",
         enabled: Bool = true,
         subUA: String = "clash",
         subConvert: Bool = false,
         convertAddress: String? = nil,
         template: String? = nil,
         emoji: Bool? = nil,
         udp: Bool? = nil,
         skipCertVerify: Bool? = nil,
         sort: Bool? = nil,
         nodeType: Bool? = nil,
         ruleProvider: Bool? = nil,
         keyword: String? = nil,
         exKeyword: String? = nil,
         customParams: [String]? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.enabled = enabled
        self.subUA = subUA.replacingOccurrences(of: "'", with: "").lowercased()
        self.subConvert = subConvert
        self.convertAddress = convertAddress
        self.template = template
        self.emoji = emoji
        self.udp = udp
        self.skipCertVerify = skipCertVerify
        self.sort = sort
        self.nodeType = nodeType
        self.ruleProvider = ruleProvider
        self.keyword = keyword
        self.exKeyword = exKeyword
        self.customParams = customParams
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
            subUA: "clash",
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
        var commands = [
            "uci set openclash.@config_subscribe[\(index)].name='\(name)'",
            "uci set openclash.@config_subscribe[\(index)].address='\(address)'",
            "uci set openclash.@config_subscribe[\(index)].sub_ua='\(subUA)'",
            "uci set openclash.@config_subscribe[\(index)].enabled='\(enabled ? "1" : "0")'",
            "uci set openclash.@config_subscribe[\(index)].sub_convert='\(subConvert ? "1" : "0")'"
        ]
        
        // 添加可选参数的命令
        if subConvert {
            if let convertAddress = convertAddress {
                commands.append("uci set openclash.@config_subscribe[\(index)].convert_address='\(convertAddress)'")
            }
            if let template = template {
                commands.append("uci set openclash.@config_subscribe[\(index)].template='\(template)'")
            }
            if let emoji = emoji {
                commands.append("uci set openclash.@config_subscribe[\(index)].emoji='\(emoji ? "true" : "false")'")
            }
            if let udp = udp {
                commands.append("uci set openclash.@config_subscribe[\(index)].udp='\(udp ? "true" : "false")'")
            }
            if let skipCertVerify = skipCertVerify {
                commands.append("uci set openclash.@config_subscribe[\(index)].skip_cert_verify='\(skipCertVerify ? "true" : "false")'")
            }
            if let sort = sort {
                commands.append("uci set openclash.@config_subscribe[\(index)].sort='\(sort ? "true" : "false")'")
            }
            if let nodeType = nodeType {
                commands.append("uci set openclash.@config_subscribe[\(index)].node_type='\(nodeType ? "true" : "false")'")
            }
            if let ruleProvider = ruleProvider {
                commands.append("uci set openclash.@config_subscribe[\(index)].rule_provider='\(ruleProvider ? "true" : "false")'")
            }
        }
        
        // 处理关键词
        if let keyword = keyword, !keyword.isEmpty {
            commands.append("uci delete openclash.@config_subscribe[\(index)].keyword")
            let keywords = keyword.split(separator: " ")
                .map { String($0) }
                .filter { !$0.isEmpty }
            for kw in keywords {
                commands.append("uci add_list openclash.@config_subscribe[\(index)].keyword=\(kw)")
            }
        }
        
        // 处理排除关键词
        if let exKeyword = exKeyword, !exKeyword.isEmpty {
            commands.append("uci delete openclash.@config_subscribe[\(index)].ex_keyword")
            let exKeywords = exKeyword.split(separator: " ")
                .map { String($0) }
                .filter { !$0.isEmpty }
            for kw in exKeywords {
                commands.append("uci add_list openclash.@config_subscribe[\(index)].ex_keyword=\(kw)")
            }
        }
        
        // 处理自定义参数
        if let customParams = customParams, !customParams.isEmpty {
            commands.append("uci delete openclash.@config_subscribe[\(index)].custom_params")
            commands.append(contentsOf: customParams.map {
                "uci add_list openclash.@config_subscribe[\(index)].custom_params='\($0)'"
            })
        }

        print("🔍 生成的 UCI 命令: \(commands)")
        
        return commands
    }
}