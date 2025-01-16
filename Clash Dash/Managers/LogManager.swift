import Foundation
import SwiftUI

final class LogManager: ObservableObject {
    static let shared = LogManager()
    @Published var logs: [LogEntry] = []
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let level: LogLevel
        
        var levelInfo: (String, Color) {
            switch level {
            case .info:
                return ("信息", .blue)
            case .warning:
                return ("警告", .orange)
            case .error:
                return ("错误", .red)
            case .debug:
                return ("调试", .secondary)
            }
        }
    }
    
    enum LogLevel {
        case info
        case warning
        case error
        case debug
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .debug: return .secondary
            }
        }
    }
    
    private init() {}
    
    func log(_ message: String, level: LogLevel = .info) {
        DispatchQueue.main.async {
            self.logs.append(LogEntry(
                timestamp: Date(),
                message: message,
                level: level
            ))
            
            // 保持最近的 1000 条日志
            if self.logs.count > 1000 {
                self.logs.removeFirst(self.logs.count - 1000)
            }
        }
    }
    
    // 便捷方法
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    func warning(_ message: String) {
        log(message, level: .warning)
    }
    
    func error(_ message: String) {
        log(message, level: .error)
    }
    
    func debug(_ message: String) {
        log(message, level: .debug)
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    func exportLogs() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return logs.map { entry in
            "[\(dateFormatter.string(from: entry.timestamp))] [\(entry.levelInfo.0)] \(entry.message)"
        }.joined(separator: "\n")
    }
} 
