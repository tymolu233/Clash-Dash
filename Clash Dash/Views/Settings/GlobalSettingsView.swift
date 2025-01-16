import SwiftUI
import CoreHaptics
import CoreLocation
import CloudKit

struct GlobalSettingsView: View {
    @AppStorage("autoDisconnectOldProxy") private var autoDisconnectOldProxy = false
    @AppStorage("hideUnavailableProxies") private var hideUnavailableProxies = false
    @AppStorage("proxyGroupSortOrder") private var proxyGroupSortOrder = ProxyGroupSortOrder.default
    @AppStorage("speedTestURL") private var speedTestURL = "https://www.gstatic.com/generate_204"
    @AppStorage("speedTestTimeout") private var speedTestTimeout = 5000
    @AppStorage("pinBuiltinProxies") private var pinBuiltinProxies = false
    @AppStorage("hideProxyProviders") private var hideProxyProviders = false
    @AppStorage("smartProxyGroupDisplay") private var smartProxyGroupDisplay = false
    @AppStorage("enableCloudSync") private var enableCloudSync = false
    @State private var showClearCacheAlert = false
    @State private var showSyncErrorAlert = false
    @State private var syncErrorMessage = ""
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
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
                    title: "置顶内置策略",
                    subtitle: "将 DIRECT 和 REJECT 等内置策略始终保持在最前面",
                    isOn: $pinBuiltinProxies
                )
                
                SettingToggleRow(
                    title: "隐藏代理提供者",
                    subtitle: "在代理页面中不显示代理提供者信息",
                    isOn: $hideProxyProviders
                )

                SettingToggleRow(
                    title: "Global 代理组显示控制",
                    subtitle: "规则/直连模式下隐藏 GLOBAL 组，全局模式下仅显示 GLOBAL 组",
                    isOn: $smartProxyGroupDisplay
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
                                HapticManager.shared.impact(.light)
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
                SettingToggleRow(
                    title: "启用 iCloud 同步",
                    subtitle: "同步服务器配置、全局设置和外观设置到 iCloud",
                    isOn: $enableCloudSync
                )
                
                if enableCloudSync {
                    HStack {
                        Text("iCloud 状态")
                        Spacer()
                        Text(cloudKitManager.iCloudStatus)
                            .foregroundStyle(.secondary)
                    }
                    
                    SettingToggleRow(
                        title: "同步全局设置",
                        subtitle: "同步代理切换、排序、测速等全局设置",
                        isOn: Binding(
                            get: { cloudKitManager.syncGlobalSettings },
                            set: { cloudKitManager.setSyncOption(globalSettings: $0) }
                        )
                    )
                    
                    SettingToggleRow(
                        title: "同步控制器列表",
                        subtitle: "同步所有控制器配置信息",
                        isOn: Binding(
                            get: { cloudKitManager.syncServers },
                            set: { cloudKitManager.setSyncOption(servers: $0) }
                        )
                    )
                    
                    SettingToggleRow(
                        title: "同步外观设置",
                        subtitle: "同步主题、卡片样式等外观设置",
                        isOn: Binding(
                            get: { cloudKitManager.syncAppearance },
                            set: { cloudKitManager.setSyncOption(appearance: $0) }
                        )
                    )
                    
                    Button {
                        Task {
                            do {
                                try await cloudKitManager.syncToCloud()
                            } catch {
                                syncErrorMessage = error.localizedDescription
                                showSyncErrorAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            Label("立即同步到 iCloud", systemImage: "arrow.clockwise.icloud")
                            Spacer()
                            if cloudKitManager.isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(cloudKitManager.isSyncing || cloudKitManager.iCloudStatus != "可用")
                    
                    Button {
                        Task {
                            do {
                                try await cloudKitManager.syncFromCloud()
                            } catch {
                                syncErrorMessage = error.localizedDescription
                                showSyncErrorAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            Label("从 iCloud 恢复", systemImage: "icloud.and.arrow.down")
                            Spacer()
                            if cloudKitManager.isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(cloudKitManager.isSyncing || cloudKitManager.iCloudStatus != "可用")
                }
            } header: {
                SectionHeader(title: "iCloud 同步", systemImage: "icloud")
            } footer: {
                if enableCloudSync {
                    Text("上次同步时间：\(cloudKitManager.lastSyncTime?.formatted() ?? "从未同步")")
                }
            }
        }
        .navigationTitle("全局配置")
        .navigationBarTitleDisplayMode(.inline)
        .alert("清除图标缓存", isPresented: $showClearCacheAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                ImageCache.shared.removeAll()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } message: {
            Text("确定要清除所有已缓存的图标吗？")
        }
        .alert("同步错误", isPresented: $showSyncErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(syncErrorMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SettingsUpdated"))) { _ in
            // 强制视图刷新
            withAnimation {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        }
    }
}

#Preview {
    NavigationStack {
        GlobalSettingsView()
    }
} 
