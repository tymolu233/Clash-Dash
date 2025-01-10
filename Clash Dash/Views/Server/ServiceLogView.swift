import SwiftUI

struct ServiceLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel
    
    enum LogLevel: Equatable {
        case info
        case warning
        case error
        case debug
    }
    
    static func == (lhs: ServiceLogEntry, rhs: ServiceLogEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.timestamp == rhs.timestamp &&
        lhs.message == rhs.message &&
        lhs.level == rhs.level
    }
}

struct ServiceLogView: View {
    let server: ClashServer
    @StateObject private var viewModel: ServiceLogViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showingClearConfirm = false
    @State private var selectedLogType: ServiceLogType = .plugin
    
    init(server: ClashServer) {
        self.server = server
        _viewModel = StateObject(wrappedValue: ServiceLogViewModel(server: server))
    }
    
    var filteredLogs: [ServiceLogEntry] {
        if searchText.isEmpty {
            return viewModel.logs
        }
        return viewModel.logs.filter { log in
            // 搜索日志内容
            if log.message.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            // 搜索日志级别
            let levelText = levelTextForSearch(log.level)
            return levelText.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func levelTextForSearch(_ level: ServiceLogEntry.LogLevel) -> String {
        switch level {
        case .info:
            return "信息"
        case .warning:
            return "警告"
        case .error:
            return "错误"
        case .debug:
            return "调试"
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // 日志类型选择器
                Picker("日志类型", selection: $selectedLogType) {
                    ForEach(ServiceLogType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
                
                List {
                    ForEach(filteredLogs) { entry in
                        ServiceLogEntryView(entry: entry, selectedLogType: selectedLogType)
                            .id(entry.id)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.visible)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await withCheckedContinuation { continuation in
                        viewModel.fetchLogs(type: selectedLogType)
                        continuation.resume()
                    }
                }
                .overlay {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if let error = viewModel.error {
                        EmptyStateView(
                            title: "加载失败",
                            systemImage: "exclamationmark.triangle",
                            description: error.localizedDescription
                        )
                    } else if viewModel.logs.isEmpty {
                        EmptyStateView(
                            title: "暂无日志",
                            systemImage: "doc.text",
                            description: selectedLogType == .plugin ? "插件运行日志将在此显示" : "内核运行日志将在此显示"
                        )
                    } else if !viewModel.logs.isEmpty && filteredLogs.isEmpty {
                        EmptyStateView(
                            title: "未找到结果",
                            systemImage: "magnifyingglass",
                            description: "尝试搜索日志内容或日志级别（信息/警告/错误/调试）"
                        )
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索日志内容或级别")
            .onChange(of: selectedLogType) { _ in
                viewModel.fetchLogs(type: selectedLogType)
            }
            .onChange(of: viewModel.logs) { _ in
                withAnimation {
                    if let lastId = viewModel.logs.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("运行日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Text("关闭")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.fetchLogs(type: selectedLogType)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showingClearConfirm = true
                    } label: {
                        Label("清空日志", systemImage: "trash")
                    }
                    
                    Button {
                        shareLog()
                    } label: {
                        Label("导出日志", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .alert("确认清空", isPresented: $showingClearConfirm) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                Task {
                    do {
                        try await viewModel.clearLogs()
                    } catch {
                        // TODO: 显示错误提示
                    }
                }
            }
        } message: {
            if server.luciPackage == .openClash {
                Text("确定要清空所有日志吗？此操作将同时清空插件日志和内核日志，且无法撤销。")
            } else {
                Text("确定要清空\(selectedLogType == .plugin ? "插件" : "内核")日志吗？此操作无法撤销。")
            }
        }
        .task {
            viewModel.fetchLogs(type: selectedLogType)
        }
    }
    
    private func shareLog() {
        let logText = viewModel.logs.map { "[\($0.timestamp)] \($0.message)" }.joined(separator: "\n")
        
        // 创建一个临时文件来保存日志
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "service_logs_\(Date().timeIntervalSince1970).txt"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try logText.write(to: fileURL, atomically: true, encoding: .utf8)
            
            let av = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            // 使用 UIApplication.shared.keyWindow 来获取当前窗口
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                
                // 在主线程中执行
                DispatchQueue.main.async {
                    // 获取最顶层的视图控制器
                    if var topController = window.rootViewController {
                        while let presentedViewController = topController.presentedViewController {
                            topController = presentedViewController
                        }
                        
                        // 设置 iPad 上的 popover 位置
                        if let popover = av.popoverPresentationController {
                            popover.sourceView = window
                            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                            popover.permittedArrowDirections = []
                        }
                        
                        // 展示分享界面
                        topController.present(av, animated: true) {
                            // 分享完成后删除临时文件
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                    }
                }
            }
        } catch {
            print("Error saving log file: \(error)")
        }
    }
}

struct ServiceLogEntryView: View {
    let entry: ServiceLogEntry
    @Environment(\.colorScheme) var colorScheme
    let selectedLogType: ServiceLogType
    
    private var timeString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        return dateFormatter.string(from: entry.timestamp)
    }
    
    private var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: entry.timestamp)
    }
    
    private var levelInfo: (String, Color) {
        switch entry.level {
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
    
    private func parseAddresses(_ message: String) -> (source: String?, destination: String?) {
        // 匹配 [UDP] 或 [TCP] 后面的地址格式
        let pattern = #"\[(UDP|TCP)\]\s+([^:]+):\d+\s*-->\s*([^:]+)(?::\d+)?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) else {
            return (nil, nil)
        }
        
        let sourceRange = Range(match.range(at: 2), in: message)
        let destRange = Range(match.range(at: 3), in: message)
        
        let source = sourceRange.map { String(message[$0]) }
        let destination = destRange.map { String(message[$0]) }
        
        return (source, destination)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 日志消息
            Text(entry.message)
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // 时间和级别指示器
            HStack(alignment: .center, spacing: 4) {
                Text(levelInfo.0)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(levelInfo.1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(levelInfo.1.opacity(0.1))
                    .cornerRadius(4)
                
                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("·")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(dateString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Menu {
                    Button {
                        UIPasteboard.general.string = entry.message
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        let timeString = dateFormatter.string(from: entry.timestamp)
                        UIPasteboard.general.string = "[\(timeString)] \(entry.message)"
                    } label: {
                        Label("复制（含时间）", systemImage: "document.badge.clock")
                    }
                    
                    if selectedLogType == .kernel {
                        let addresses = parseAddresses(entry.message)
                        if let sourceAddr = addresses.source {
                            Button {
                                UIPasteboard.general.string = sourceAddr
                            } label: {
                                Label("复制起始地址", systemImage: "arrow.up.forward")
                            }
                        }
                        
                        if let destAddr = addresses.destination {
                            Button {
                                UIPasteboard.general.string = destAddr
                            } label: {
                                Label("复制目标地址", systemImage: "arrow.down.forward")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .contextMenu {
            Button {
                UIPasteboard.general.string = entry.message
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            
            Button {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let timeString = dateFormatter.string(from: entry.timestamp)
                UIPasteboard.general.string = "[\(timeString)] \(entry.message)"
            } label: {
                Label("复制（含时间）", systemImage: "document.badge.clock")
            }
            
            if selectedLogType == .kernel {
                let addresses = parseAddresses(entry.message)
                if let sourceAddr = addresses.source {
                    Button {
                        UIPasteboard.general.string = sourceAddr
                    } label: {
                        Label("复制起始地址", systemImage: "arrow.up.forward")
                    }
                }
                
                if let destAddr = addresses.destination {
                    Button {
                        UIPasteboard.general.string = destAddr
                    } label: {
                        Label("复制目标地址", systemImage: "arrow.down.forward")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ServiceLogView(server: ClashServer(name: "测试服务器", url: "10.1.1.2", port: "9090", secret: "123456"))
    }
} 