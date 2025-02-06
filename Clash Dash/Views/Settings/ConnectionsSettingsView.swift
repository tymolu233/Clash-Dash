import SwiftUI

enum DefaultConnectionSortOption: String, CaseIterable, Identifiable {
    case startTime = "开始时间"
    case download = "下载流量"
    case upload = "上传流量"
    case downloadSpeed = "下载速度"
    case uploadSpeed = "上传速度"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .startTime: return "clock"
        case .download: return "arrow.down.circle"
        case .upload: return "arrow.up.circle"
        case .downloadSpeed: return "arrow.down.circle.fill"
        case .uploadSpeed: return "arrow.up.circle.fill"
        }
    }
}

struct ConnectionsSettingsView: View {
    @AppStorage("connectionRowStyle") private var connectionRowStyle = ConnectionRowStyle.classic
    @AppStorage("defaultConnectionSortOption") private var defaultSortOption = DefaultConnectionSortOption.startTime
    @AppStorage("defaultConnectionSortAscending") private var defaultSortAscending = false
    
    var body: some View {
        List {
            Section {
                Picker("连接视图样式", selection: $connectionRowStyle) {
                    ForEach(ConnectionRowStyle.allCases) { style in
                        Text(style.description)
                            .tag(style)
                    }
                }
                
                Picker("默认排序方式", selection: $defaultSortOption) {
                    ForEach(DefaultConnectionSortOption.allCases) { option in
                        Label {
                            Text(option.rawValue)
                        } icon: {
                            Image(systemName: option.icon)
                        }
                        .tag(option)
                    }
                }
                
                Toggle("默认升序排列", isOn: $defaultSortAscending)
                    .onChange(of: defaultSortAscending) { newValue in
                        // 保存新的排序方向
                        UserDefaults.standard.set(newValue, forKey: "defaultConnectionSortAscending")
                    }
                
            } header: {
                SectionHeader(title: "连接列表", systemImage: "list.bullet.rectangle")
            }
        }
        .navigationTitle("连接页面设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ConnectionsSettingsView()
    }
} 