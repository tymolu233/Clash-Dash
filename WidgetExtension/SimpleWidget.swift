import WidgetKit
import SwiftUI
import Shared
import Network
import ActivityKit

struct SimpleEntry: TimelineEntry {
    let date: Date
    let status: ClashStatus
}

struct Provider: TimelineProvider {
    private let networkManager = WidgetNetworkManager.shared
    private let userDefaults = UserDefaults(suiteName: "group.ym.si.clashdash")
    
    func placeholder(in context: Context) -> SimpleEntry {
        print("[Widget] Creating placeholder entry")
        let defaultServer = userDefaults?.string(forKey: "widgetDefaultServer") ?? ""
        let status = ClashStatus(
            serverAddress: defaultServer.isEmpty ? "未连接" : defaultServer,
            serverName: nil,
            activeConnections: 0,
            uploadTotal: 0,
            downloadTotal: 0,
            memoryUsage: nil
        )
        print("[Widget] Placeholder status: \(status)")
        return SimpleEntry(date: Date(), status: status)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        print("[Widget] Getting snapshot")
        let defaultServer = userDefaults?.string(forKey: "widgetDefaultServer") ?? ""
        print("[Widget] 默认服务器设置: \(defaultServer)")
        
        if !defaultServer.isEmpty {
            print("[Widget] 使用默认服务器: \(defaultServer)")
            if context.isPreview {
                completion(placeholder(in: context))
                return
            }
            
            networkManager.fetchStatus(for: defaultServer) { newStatus in
                if let status = newStatus {
                    print("[Widget] 成功获取服务器状态")
                    print("[Widget] - Server address: \(status.serverAddress)")
                    print("[Widget] - Server name: \(status.serverName ?? "nil")")
                    print("[Widget] - Connections: \(status.activeConnections)")
                    print("[Widget] - Upload: \(status.uploadTotal)")
                    print("[Widget] - Download: \(status.downloadTotal)")
                    print("[Widget] - Memory: \(status.memoryUsage ?? 0) MB")
                    completion(SimpleEntry(date: Date(), status: status))
                } else {
                    print("[Widget] 获取服务器状态失败")
                    let emptyStatus = ClashStatus(
                        serverAddress: defaultServer,
                        serverName: nil,
                        activeConnections: 0,
                        uploadTotal: 0,
                        downloadTotal: 0,
                        memoryUsage: nil
                    )
                    completion(SimpleEntry(date: Date(), status: emptyStatus))
                }
            }
        } else {
            print("[Widget] 没有设置默认服务器")
            let status = ClashStatus(
                serverAddress: "未连接",
                serverName: nil,
                activeConnections: 0,
                uploadTotal: 0,
                downloadTotal: 0,
                memoryUsage: nil
            )
            completion(SimpleEntry(date: Date(), status: status))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        print("[Widget] Getting timeline")
        let currentDate = Date()
        let defaultServer = userDefaults?.string(forKey: "widgetDefaultServer") ?? ""
        print("[Widget] 默认服务器设置: \(defaultServer)")
        
        if !defaultServer.isEmpty {
            print("[Widget] 使用默认服务器: \(defaultServer)")
            networkManager.fetchStatus(for: defaultServer) { newStatus in
                if let status = newStatus {
                    print("[Widget] Timeline: 成功获取新数据")
                    print("[Widget] - Server address: \(status.serverAddress)")
                    print("[Widget] - Server name: \(status.serverName ?? "nil")")
                    print("[Widget] - Connections: \(status.activeConnections)")
                    print("[Widget] - Upload: \(status.uploadTotal)")
                    print("[Widget] - Download: \(status.downloadTotal)")
                    print("[Widget] - Memory: \(status.memoryUsage ?? 0) MB")
                    
                    let entry = SimpleEntry(date: currentDate, status: status)
                    print("[Widget] 创建的 Entry:")
                    print("[Widget] - Entry server name: \(entry.status.serverName ?? "nil")")
                    print("[Widget] - Entry server address: \(entry.status.serverAddress)")
                    
                    let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate) ?? currentDate
                    print("[Widget] Timeline: 下次更新时间: \(nextUpdate)")
                    let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                    completion(timeline)
                } else {
                    print("[Widget] Timeline: 获取数据失败，使用空状态")
                    let emptyStatus = ClashStatus(
                        serverAddress: defaultServer,
                        serverName: nil,
                        activeConnections: 0,
                        uploadTotal: 0,
                        downloadTotal: 0,
                        memoryUsage: nil
                    )
                    let entry = SimpleEntry(date: currentDate, status: emptyStatus)
                    let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate) ?? currentDate
                    print("[Widget] Timeline: 下次更新时间: \(nextUpdate)")
                    let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                    completion(timeline)
                }
            }
        } else {
            print("[Widget] 没有设置默认服务器")
            let status = ClashStatus(
                serverAddress: "未连接",
                serverName: nil,
                activeConnections: 0,
                uploadTotal: 0,
                downloadTotal: 0,
                memoryUsage: nil
            )
            let entry = SimpleEntry(date: currentDate, status: status)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate
            print("[Widget] Timeline: 下次更新时间: \(nextUpdate)")
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

struct SimpleWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }
    
    // 小尺寸 Widget
    @ViewBuilder
    private var smallWidget: some View {
        let content = VStack(alignment: .leading, spacing: 0) {
            // 顶部：控制器信息
            HStack(spacing: 4) {
                Image(systemName: "network")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text(entry.status.serverName ?? entry.status.serverAddress)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                if #available(iOSApplicationExtension 17.0, *) {
                    Button(intent: RefreshIntent()) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .symbolEffect(.bounce, value: entry.date)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
            
            Spacer()
            
            // 流量信息
            VStack(alignment: .leading, spacing: 6) {
                // 下载
                VStack(alignment: .leading, spacing: 2) {
                    Text("下载")
                        .font(.system(.caption2))
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.body)
                            .foregroundColor(.blue)
                        Text(formatBytes(entry.status.downloadTotal))
                            .font(.system(.callout, design: .rounded))
                            .bold()
                            .lineLimit(1)
                    }
                }
                
                // 上传
                VStack(alignment: .leading, spacing: 2) {
                    Text("上传")
                        .font(.system(.caption2))
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.body)
                            .foregroundColor(.green)
                        Text(formatBytes(entry.status.uploadTotal))
                            .font(.system(.callout, design: .rounded))
                            .bold()
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // 底部状态信息
            HStack(spacing: 8) {
                // 连接状态
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("\(entry.status.activeConnections)")
                        .font(.system(.caption, design: .rounded))
                        .bold()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                
                if let memory = entry.status.memoryUsage {
                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("\(Int(memory))MB")
                            .font(.system(.caption, design: .rounded))
                            .bold()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                    .lineLimit(1)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        
        if #available(iOSApplicationExtension 17.0, *) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .containerBackground(for: .widget) {
                    ContainerRelativeShape()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(uiColor: .systemBackground),
                                    Color(uiColor: .systemBackground).opacity(0.95),
                                    Color.blue.opacity(0.1),
                                    Color.green.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(uiColor: .systemBackground),
                            Color(uiColor: .systemBackground).opacity(0.95),
                            Color.blue.opacity(0.1),
                            Color.green.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // 中尺寸 Widget
    @ViewBuilder
    private var mediumWidget: some View {
        let content = VStack(spacing: 8) {
            // 顶部信息栏
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(entry.status.serverName ?? entry.status.serverAddress)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if #available(iOSApplicationExtension 17.0, *) {
                    Button(intent: RefreshIntent()) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .symbolEffect(.bounce, value: entry.date)
                    }
                    .buttonStyle(.plain)
                    
                    Text("更新时间: \(entry.date, style: .time)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("更新时间: \(entry.date, style: .time)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            // 主要内容
            HStack(spacing: 0) {
                // 左侧：状态信息
                VStack(alignment: .leading, spacing: 12) {
                    // 连接状态
                    VStack(alignment: .leading, spacing: 4) {
                        Text("活动连接")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            // 
                            Image(systemName: "waveform.path.ecg")
                            .font(.caption2)
                            .foregroundColor(.green)
                            Text("\(entry.status.activeConnections)")
                                .font(.system(.title2, design: .rounded))
                                .bold()
                        }
                    }
                    
                    if let memory = entry.status.memoryUsage {
                        // 内存使用
                        VStack(alignment: .leading, spacing: 4) {
                            Text("内存使用")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                            HStack(spacing: 6) {
                                Image(systemName: "memorychip")
                                    .font(.body)
                                    .foregroundColor(.blue)
                                Text(String(format: "%.1f MB", memory))
                                    .font(.system(.body, design: .rounded))
                                    .bold()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                
                // 右侧：流量信息
                VStack(spacing: 16) {
                    // 下载
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Spacer()
                            Text("下载")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                        HStack(spacing: 8) {
                            Text(formatBytes(entry.status.downloadTotal))
                                .font(.system(.callout, design: .rounded))
                                .bold()
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // 上传
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Spacer()
                            Text("上传")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                        HStack(spacing: 8) {
                            Text(formatBytes(entry.status.uploadTotal))
                                .font(.system(.callout, design: .rounded))
                                .bold()
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 6)
        }
        
        if #available(iOSApplicationExtension 17.0, *) {
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .containerBackground(for: .widget) {
                    ContainerRelativeShape()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(uiColor: .systemBackground),
                                    Color(uiColor: .systemBackground).opacity(0.95),
                                    Color.blue.opacity(0.1),
                                    Color.green.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        } else {
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(uiColor: .systemBackground),
                            Color(uiColor: .systemBackground).opacity(0.95),
                            Color.blue.opacity(0.1),
                            Color.green.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}

struct SimpleWidget: Widget {
    let kind: String = "SimpleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SimpleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Clash Dash Widget")
        .description("显示 Clash Dash 控制器的状态")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct SimpleWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 小尺寸预览
            SimpleWidgetEntryView(entry: SimpleEntry(
                date: Date(),
                status: ClashStatus(
                    serverAddress: "127.0.0.1:7890",
                    serverName: "本地控制器",
                    activeConnections: 42,
                    uploadTotal: Int64(1024 * 1024 * 150),
                    downloadTotal: Int64(1024 * 1024 * 500),
                    memoryUsage: 256.5
                )
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            // 中尺寸预览
            SimpleWidgetEntryView(entry: SimpleEntry(
                date: Date(),
                status: ClashStatus(
                    serverAddress: "127.0.0.1:7890",
                    serverName: "本地控制器",
                    activeConnections: 42,
                    uploadTotal: Int64(1024 * 1024 * 150),
                    downloadTotal: Int64(1024 * 1024 * 500),
                    memoryUsage: 256.5
                )
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}

// MARK: - Live Activity 视图
@available(iOS 16.1, *)
struct ClashSpeedLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClashSpeedAttributes.self) { context in
            // 锁屏/灵动岛视图
            LiveActivityView(context: context)
        } dynamicIsland: { context in
            // 灵动岛视图
            DynamicIsland {
                // 扩展视图
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text(context.state.uploadSpeed)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .onAppear {
                        print("🎬 DynamicIsland.leading 出现")
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    HStack {
                        Text(context.state.downloadSpeed)
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .onAppear {
                        print("🎬 DynamicIsland.trailing 出现")
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.serverName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .onAppear {
                            print("🎬 DynamicIsland.center 出现")
                        }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("\(context.state.activeConnections)", systemImage: "network")
                            .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onAppear {
                        print("🎬 DynamicIsland.bottom 出现")
                    }
                }
            } compactLeading: {
                // 紧凑前导视图
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                    Text(context.state.uploadSpeed)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                .onAppear {
                    print("🎬 DynamicIsland.compactLeading 出现")
                }
            } compactTrailing: {
                // 紧凑尾随视图
                HStack {
                    Text(context.state.downloadSpeed)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                }
                .onAppear {
                    print("🎬 DynamicIsland.compactTrailing 出现")
                }
            } minimal: {
                // 最小视图
                Image(systemName: "network")
                    .foregroundColor(.blue)
                    .onAppear {
                        print("🎬 DynamicIsland.minimal 出现")
                    }
            }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("网络速度")
        .description("在灵动岛显示实时网络速度")
    }
}

@available(iOS 16.1, *)
struct LiveActivityView: View {
    let context: ActivityViewContext<ClashSpeedAttributes>
    
    var body: some View {
        VStack {
            Text(context.attributes.serverName)
                .font(.headline)
                .padding(.top, 8)
                .onAppear {
                    print("🎬 LiveActivityView 出现")
                    print("📱 服务器: \(context.attributes.serverName)")
                    print("📊 上传: \(context.state.uploadSpeed)")
                    print("📊 下载: \(context.state.downloadSpeed)")
                    print("📊 连接: \(context.state.activeConnections)")
                }
            
            HStack(spacing: 20) {
                VStack {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text(context.state.uploadSpeed)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(.bottom, 4)
                    
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Text(context.state.downloadSpeed)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack {
                    Text("连接数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(context.state.activeConnections)")
                        .font(.system(size: 20, weight: .bold))
                }
            }
            .padding()
        }
        .activityBackgroundTint(Color.black.opacity(0.2))
        .activitySystemActionForegroundColor(Color.black)
    }
} 

