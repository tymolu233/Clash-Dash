import SwiftUI

enum RuleType: String, CaseIterable {
    case domain = "DOMAIN"
    case domainSuffix = "DOMAIN-SUFFIX"
    case domainKeyword = "DOMAIN-KEYWORD"
    case domainRegex = "DOMAIN-REGEX"
    case geosite = "GEOSITE"
    
    case ipCidr = "IP-CIDR"
    case ipCidr6 = "IP-CIDR6"
    case ipSuffix = "IP-SUFFIX"
    case ipAsn = "IP-ASN"
    case geoip = "GEOIP"
    
    case srcGeoip = "SRC-GEOIP"
    case srcIpAsn = "SRC-IP-ASN"
    case srcIpCidr = "SRC-IP-CIDR"
    case srcIpSuffix = "SRC-IP-SUFFIX"
    
    case dstPort = "DST-PORT"
    case srcPort = "SRC-PORT"
    
    case inPort = "IN-PORT"
    case inType = "IN-TYPE"
    case inUser = "IN-USER"
    case inName = "IN-NAME"
    
    case processPath = "PROCESS-PATH"
    case processPathRegex = "PROCESS-PATH-REGEX"
    case processName = "PROCESS-NAME"
    case processNameRegex = "PROCESS-NAME-REGEX"
    case uid = "UID"
    
    case network = "NETWORK"
    case dscp = "DSCP"
    
    case ruleSet = "RULE-SET"
    case and = "AND"
    case or = "OR"
    case not = "NOT"
    case subRule = "SUB-RULE"
    
    var description: String {
        switch self {
        case .domain: return "精确匹配域名"
        case .domainSuffix: return "匹配域名后缀"
        case .domainKeyword: return "匹配域名关键字"
        case .domainRegex: return "正则匹配域名"
        case .geosite: return "匹配预定义域名列表"
        
        case .ipCidr: return "匹配 IPv4 CIDR"
        case .ipCidr6: return "匹配 IPv6 CIDR"
        case .ipSuffix: return "匹配 IP 后缀"
        case .ipAsn: return "匹配 IP ASN"
        case .geoip: return "匹配 GeoIP 数据"
        
        case .srcGeoip: return "匹配源 GeoIP"
        case .srcIpAsn: return "匹配源 IP ASN"
        case .srcIpCidr: return "匹配源 IP CIDR"
        case .srcIpSuffix: return "匹配源 IP 后缀"
        
        case .dstPort: return "匹配目标端口"
        case .srcPort: return "匹配源端口"
        
        case .inPort: return "匹配入站端口"
        case .inType: return "匹配入站类型"
        case .inUser: return "匹配入站用户"
        case .inName: return "匹配入站名称"
        
        case .processPath: return "匹配进程路径"
        case .processPathRegex: return "正则匹配进程路径"
        case .processName: return "匹配进程名称"
        case .processNameRegex: return "正则匹配进程名称"
        case .uid: return "匹配用户 ID"
        
        case .network: return "匹配网络类型"
        case .dscp: return "匹配 DSCP 值"
        
        case .ruleSet: return "使用规则集"
        case .and: return "逻辑与"
        case .or: return "逻辑或"
        case .not: return "逻辑非"
        case .subRule: return "子规则"
        }
    }
    
    var iconName: String {
        switch self {
        case .domain, .domainSuffix: return "globe"
        case .domainKeyword, .domainRegex: return "magnifyingglass"
        case .geosite: return "map"
        
        case .ipCidr, .ipCidr6, .ipSuffix: return "network"
        case .ipAsn: return "number.circle"
        case .geoip: return "globe.americas"
        
        case .srcGeoip: return "location.circle"
        case .srcIpAsn, .srcIpCidr, .srcIpSuffix: return "arrow.up.forward"
        
        case .dstPort: return "arrow.down.forward"
        case .srcPort: return "arrow.up"
        
        case .inPort: return "arrow.down.to.line"
        case .inType: return "switch.2"
        case .inUser: return "person"
        case .inName: return "tag"
        
        case .processPath, .processPathRegex: return "folder"
        case .processName, .processNameRegex: return "terminal"
        case .uid: return "person.crop.circle"
        
        case .network: return "network"
        case .dscp: return "slider.horizontal.3"
        
        case .ruleSet: return "list.bullet"
        case .and: return "plus.circle"
        case .or: return "circle.grid.cross"
        case .not: return "exclamationmark.circle"
        case .subRule: return "arrow.triangle.branch"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .domain, .domainSuffix, .domainKeyword, .domainRegex:
            return .purple
        case .geosite, .geoip, .srcGeoip:
            return .green
        case .ipCidr, .ipCidr6, .ipSuffix, .ipAsn:
            return .blue
        case .srcIpAsn, .srcIpCidr, .srcIpSuffix:
            return .orange
        case .dstPort, .srcPort:
            return .red
        case .inPort, .inType, .inUser, .inName:
            return .cyan
        case .processPath, .processPathRegex, .processName, .processNameRegex:
            return .indigo
        case .uid:
            return .mint
        case .network, .dscp:
            return .teal
        case .ruleSet:
            return .brown
        case .and, .or, .not, .subRule:
            return .gray
        }
    }
    
    var example: String {
        switch self {
        case .domain: return "示例：ad.com"
        case .domainSuffix: return "示例：google.com"
        case .domainKeyword: return "示例：google"
        case .domainRegex: return "示例：^abc.*com"
        case .geosite: return "示例：youtube"
        
        case .ipCidr: return "示例：127.0.0.0/8"
        case .ipCidr6: return "示例：2620:0:2d0:200::7/32"
        case .ipSuffix: return "示例：8.8.8.8/24"
        case .ipAsn: return "示例：13335"
        case .geoip: return "示例：CN"
        
        case .srcGeoip: return "示例：cn"
        case .srcIpAsn: return "示例：9808"
        case .srcIpCidr: return "示例：192.168.1.201/32"
        case .srcIpSuffix: return "示例：192.168.1.201/8"
        
        case .dstPort: return "示例：80"
        case .srcPort: return "示例：7777"
        
        case .inPort: return "示例：7890"
        case .inType: return "示例：SOCKS/HTTP"
        case .inUser: return "示例：mihomo"
        case .inName: return "示例：ss"
        
        case .processPath: return "示例：/usr/bin/wget"
        case .processPathRegex: return "示例：.*bin/wget"
        case .processName: return "示例：curl"
        case .processNameRegex: return "示例：(?i)Telegram"
        case .uid: return "示例：1001"
        
        case .network: return "示例：udp"
        case .dscp: return "示例：4"
        
        case .ruleSet: return "示例：providername"
        case .and: return "示例：((DOMAIN,baidu.com),(NETWORK,UDP))"
        case .or: return "示例：((NETWORK,UDP),(DOMAIN,baidu.com))"
        case .not: return "示例：((DOMAIN,baidu.com))"
        case .subRule: return "示例：(NETWORK,tcp)"
        }
    }
} 