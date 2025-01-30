import Foundation

struct OpenClashRule: Identifiable, Equatable {
    let id: UUID
    let target: String      // 例如: checkipv6.dyndns.org
    let type: String        // 例如: DOMAIN-SUFFIX
    let action: String      // 例如: DIRECT
    var isEnabled: Bool     // 是否启用
    let comment: String?    // 备注
    let lineNumber: Int?    // 行号，用于错误定位
    let error: ParsingError?  // 解析错误信息
    let rawContent: String    // 原始内容
    
    // 定义解析错误类型
    enum ParsingError: LocalizedError, Equatable {
        case invalidFormat
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "规则格式错误"
            }
        }
        
        // 实现 Equatable
        static func == (lhs: ParsingError, rhs: ParsingError) -> Bool {
            switch (lhs, rhs) {
            case (.invalidFormat, .invalidFormat):
                return true
            }
        }
    }
    
    // 实现 Equatable
    static func == (lhs: OpenClashRule, rhs: OpenClashRule) -> Bool {
        return lhs.id == rhs.id &&
               lhs.target == rhs.target &&
               lhs.type == rhs.type &&
               lhs.action == rhs.action &&
               lhs.isEnabled == rhs.isEnabled &&
               lhs.comment == rhs.comment &&
               lhs.lineNumber == rhs.lineNumber &&
               lhs.error == rhs.error &&
               lhs.rawContent == rhs.rawContent
    }
    
    init(from ruleString: String, lineNumber: Int? = nil) throws {
        self.id = UUID()
        self.lineNumber = lineNumber
        self.rawContent = ruleString
        
        // 移除前导空格
        let trimmedString = ruleString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查是否被禁用（以##开头）
        self.isEnabled = !trimmedString.hasPrefix("##")
        
        // 清理字符串，移除"- "和"##- "
        let cleanString = trimmedString
            .replacingOccurrences(of: "##- ", with: "")
            .replacingOccurrences(of: "- ", with: "")
        
        // 分割字符串，获取规则和注释
        let components = cleanString.components(separatedBy: "#")
        let ruleContent = components[0].trimmingCharacters(in: .whitespaces)
        
        // 处理规则内容
        let ruleParts = ruleContent.components(separatedBy: ",")
        if ruleParts.count < 3 {
            self.type = ruleParts.first ?? ""
            self.target = ""
            self.action = ""
            self.error = ParsingError.invalidFormat
            self.comment = components.count > 1 ? components[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            return
        }
        
        // 获取规则类型、目标和动作
        self.type = ruleParts[0].trimmingCharacters(in: .whitespaces)
        self.target = ruleParts[1].trimmingCharacters(in: .whitespaces)
        
        // 获取动作（包括可能的 no-resolve）
        var action = ruleParts[2].trimmingCharacters(in: .whitespaces)
        if ruleParts.count > 3 && ruleParts[3].trimmingCharacters(in: .whitespaces) == "no-resolve" {
            action += ",no-resolve"
        }
        self.action = action
        self.error = nil
        
        // 提取注释
        if components.count > 1 {
            self.comment = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            self.comment = nil
        }
    }
    
    // 添加一个用于创建修改后副本的方法
    func toggled() -> OpenClashRule {
        OpenClashRule(
            id: self.id,
            target: target,
            type: type,
            action: action,
            isEnabled: !isEnabled,
            comment: comment,
            lineNumber: lineNumber,
            error: error,
            rawContent: rawContent
        )
    }
    
    // 添加一个完整的初始化方法
    init(id: UUID = UUID(), target: String, type: String, action: String, isEnabled: Bool, comment: String? = nil, lineNumber: Int? = nil, error: ParsingError? = nil, rawContent: String = "") {
        self.id = id
        self.target = target
        self.type = type
        self.action = action
        self.isEnabled = isEnabled
        self.comment = comment
        self.lineNumber = lineNumber
        self.error = error
        self.rawContent = rawContent
    }
} 