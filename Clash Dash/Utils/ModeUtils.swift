import Foundation

enum ModeUtils {
    static func getModeText(_ mode: String) -> String {
        switch mode {
        case "rule": return "规则模式"
        case "direct": return "直连模式"
        case "global": return "全局模式"
        default: return "切换模式"
        }
    }
    
    static func getModeIcon(_ mode: String) -> String {
        switch mode {
        case "rule": return "list.bullet"
        case "direct": return "arrow.up.right"
        case "global": return "globe"
        default: return "shuffle"
        }
    }
} 