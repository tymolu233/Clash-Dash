import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appThemeMode") private var appThemeMode = AppThemeMode.system
    @AppStorage("proxyViewStyle") private var proxyViewStyle = ProxyViewStyle.detailed
    @AppStorage("hideDisconnectedServers") private var hideDisconnectedServers = false
    @AppStorage("enableWiFiBinding") private var enableWiFiBinding = false
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject private var bindingManager: WiFiBindingManager
    
    var body: some View {
        Form {
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
                
                Toggle("隐藏无法连接的控制器", isOn: $hideDisconnectedServers)
            } header: {
                SectionHeader(title: "外观设置", systemImage: "paintbrush")
            }

            Section {
                
                Toggle("隐藏无法连接的控制器", isOn: $hideDisconnectedServers)
            } header: {
                SectionHeader(title: "超时隐藏", systemImage: "eye.slash")
            }
            
            Section {
                SettingToggleRow(
                    title: "根据 Wi-Fi 显示控制器列表",
                    subtitle: "根据当前连接的 Wi-Fi 网络自动显示对应的控制器",
                    isOn: Binding(
                        get: { enableWiFiBinding },
                        set: { newValue in
                            if newValue {
                                if locationManager.authorizationStatus == .denied {
                                    locationManager.showLocationDeniedAlert = true
                                    return
                                }
                                locationManager.requestWhenInUseAuthorization()
                            }
                            enableWiFiBinding = newValue
                            bindingManager.onEnableChange()
                        }
                    )
                )
                
                if enableWiFiBinding {
                    NavigationLink {
                        WiFiBindingView()
                    } label: {
                        SettingRow(
                            title: "Wi-Fi 绑定设置",
                            value: ""
                        )
                    }
                    
                    NavigationLink {
                        DefaultServersView()
                    } label: {
                        SettingRow(
                            title: "默认显示控制器",
                            value: ""
                        )
                    }
                }
            } header: {
                SectionHeader(title: "Wi-Fi 绑定", systemImage: "wifi")
            }
        }
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
        .alert("需要位置权限", isPresented: $locationManager.showLocationDeniedAlert) {
            Button("取消", role: .cancel) { }
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("需要位置权限才能获取 Wi-Fi 信息。请在设置中开启位置权限。")
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
            .environmentObject(WiFiBindingManager())
    }
} 
