import Foundation

final class LogManager: ObservableObject {
    static let shared = LogManager()
    @Published var logs: [LogEntry] = []
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
    }
    
    private init() {}
    
    func log(_ message: String) {
        DispatchQueue.main.async {
            self.logs.append(LogEntry(timestamp: Date(), message: message))
            
            // 保持最近的 1000 条日志
            if self.logs.count > 1000 {
                self.logs.removeFirst(self.logs.count - 1000)
            }
        }
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    func exportLogs() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return logs.map { entry in
            "[\(dateFormatter.string(from: entry.timestamp))] \(entry.message)"
        }.joined(separator: "\n")
    }
} 