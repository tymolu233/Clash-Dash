import SwiftUI
import CoreHaptics

struct GlobalSettingsView: View {
    @AppStorage("autoDisconnectOldProxy") private var autoDisconnectOldProxy = false
    @AppStorage("hideUnavailableProxies") private var hideUnavailableProxies = false
    @AppStorage("proxyGroupSortOrder") private var proxyGroupSortOrder = ProxyGroupSortOrder.default
    @AppStorage("proxyViewStyle") private var proxyViewStyle = ProxyViewStyle.detailed
    @AppStorage("speedTestURL") private var speedTestURL = "https://www.gstatic.com/generate_204"
    @AppStorage("speedTestTimeout") private var speedTestTimeout = 5000
    @AppStorage("appThemeMode") private var appThemeMode = AppThemeMode.system
    @State private var showClearCacheAlert = false

    
    var body: some View {
        Form {
            Section {
                SettingToggleRow(
                    title: "自动断开旧连接",
                    subtitle: "切换代理时自动断开旧的连接",
                    isOn: $autoDisconnectOldProxy
                )
            } header: {
                SectionHeader(title: "切换代理设置", systemImage: "network")
            }
            
            Section {
                SettingToggleRow(
                    title: "隐藏不可用代理",
                    subtitle: "在代理组的代理节点列表中不显示无法连接的代理",
                    isOn: $hideUnavailableProxies
                )
                
                NavigationLink {
                    ProxyGroupSortOrderView(selection: $proxyGroupSortOrder)
                } label: {
                    SettingRow(
                        title: "排序方式",
                        value: proxyGroupSortOrder.description
                    )
                }
                
                SettingToggleRow(
                    title: "隐藏代理提供者",
                    subtitle: "在代理页面中不显示代理提供者信息",
                    isOn: .init(
                        get: { UserDefaults.standard.bool(forKey: "hideProxyProviders") },
                        set: { UserDefaults.standard.set($0, forKey: "hideProxyProviders") }
                    )
                )
            } header: {
                SectionHeader(title: "代理组排序设置", systemImage: "arrow.up.arrow.down")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundColor(.secondary)
                        TextField("测速链接", text: $speedTestURL)
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Text("用于测试代理延迟的URL地址")
                        .caption()
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("超时时间")
                        Spacer()
                        Text("\(speedTestTimeout) ms")
                            .monospacedDigit()
                        Stepper("", value: $speedTestTimeout, in: 1000...10000, step: 500)
                            .labelsHidden()
                            .frame(width: 100)
                            .onChange(of: speedTestTimeout) { _ in
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                    }
                    
                    Text("测速请求的最大等待时间")
                        .caption()
                }
            } header: {
                SectionHeader(title: "测速设置", systemImage: "speedometer")
            }

             Section {
                Button {
                    showClearCacheAlert = true
                } label: {
                    HStack {
                        Label("清除图标缓存", systemImage: "photo")
                        Spacer()
                        Text("已缓存 \(ImageCache.shared.count) 张图标")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                SectionHeader(title: "缓存管理", systemImage: "internaldrive")
            }

            Section {
                Picker("代理视图样式", selection: $proxyViewStyle) {
                    ForEach(ProxyViewStyle.allCases) { style in
                        Text(style.description)
                            .tag(style)
                    }
                }
                
                Picker("主题模式", selection: $appThemeMode) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.description)
                            .tag(mode)
                    }
                }
            } header: {
                SectionHeader(title: "外观", systemImage: "paintbrush")
            }
        }
        .navigationTitle("全局配置")
        .navigationBarTitleDisplayMode(.inline)
        .alert("清除图标缓存", isPresented: $showClearCacheAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                ImageCache.shared.removeAll()
                // 添加触觉反馈
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } message: {
            Text("确定要清除所有已缓存的图标吗？")
        }
    }
}

// 辅助视图组件
struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(subtitle)
                    .caption()
            }
        }
    }
}

struct SettingRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundColor(.secondary)
            .textCase(nil)
    }
}

// 扩展便捷修饰符
extension View {
    func caption() -> some View {
        self.font(.caption)
            .foregroundColor(.secondary)
    }
}

// 单独的排序设置视图
struct ProxyGroupSortOrderView: View {
    @Binding var selection: ProxyGroupSortOrder
    
    var body: some View {
        List {
            ForEach(ProxyGroupSortOrder.allCases) { order in
                Button {
                    selection = order
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack {
                        Text(order.description)
                        Spacer()
                        if order == selection {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("排序方式")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum ProxyGroupSortOrder: String, CaseIterable, Identifiable {
    case `default` = "default"
    case latencyAsc = "latencyAsc"
    case latencyDesc = "latencyDesc"
    case nameAsc = "nameAsc"
    case nameDesc = "nameDesc"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .default: return "原 config 文件中的排序"
        case .latencyAsc: return "按延迟从小到大"
        case .latencyDesc: return "按延迟从大到小"
        case .nameAsc: return "按名称字母排序 (A-Z)"
        case .nameDesc: return "按名称字母排序 (Z-A)"
        }
    }
}

struct SettingsInfoRow: View {
    let icon: String
    let text: String
    var message: String? = nil
    
    var body: some View {
        Label {
            HStack {
                Text(text)
                    .foregroundColor(.secondary)
                if let message = message {
                    Text(message)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        } icon: {
            Image(systemName: icon)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// 添加代理视图样式枚举
enum ProxyViewStyle: String, CaseIterable, Identifiable {
    case detailed = "detailed"
    case compact = "compact"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .detailed: return "详细"
        case .compact: return "简洁"
        }
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

#Preview {
    NavigationStack {
        GlobalSettingsView()
    }
} 
