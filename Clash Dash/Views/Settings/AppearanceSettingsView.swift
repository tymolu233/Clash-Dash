import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appThemeMode") private var appThemeMode = AppThemeMode.system
    @AppStorage("proxyViewStyle") private var proxyViewStyle = ProxyViewStyle.detailed
    @AppStorage("hideDisconnectedServers") private var hideDisconnectedServers = false
    
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
        }
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
} 