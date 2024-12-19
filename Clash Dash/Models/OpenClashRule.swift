import Foundation

struct OpenClashRule: Identifiable, Equatable {
    let id = UUID()
    let target: String      // 例如: checkipv6.dyndns.org
    let type: String        // 例如: DOMAIN-SUFFIX
    let action: String      // 例如: DIRECT
    let isEnabled: Bool     // 是否启用
    
    init(from ruleString: String) {
        // 移除前导空格
        let trimmedString = ruleString.trimmingCharacters(in: .whitespaces)
        
        // 检查是否被禁用（以##开头）
        self.isEnabled = !trimmedString.hasPrefix("##")
        
        // 清理字符串，移除"- "和"##- "
        let cleanString = trimmedString
            .replacingOccurrences(of: "##- ", with: "")
            .replacingOccurrences(of: "- ", with: "")
        
        // 分割字符串
        let components = cleanString.components(separatedBy: ",")
        if components.count >= 3 {
            self.type = components[0].trimmingCharacters(in: .whitespaces)
            self.target = components[1].trimmingCharacters(in: .whitespaces)
            self.action = components[2].trimmingCharacters(in: .whitespaces)
        } else {
            self.type = ""
            self.target = ""
            self.action = ""
        }
    }
} 