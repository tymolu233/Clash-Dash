import SwiftUI

struct GlobalSettingsView: View {
    @AppStorage("autoDisconnectOldProxy") private var autoDisconnectOldProxy = false
    @AppStorage("hideUnavailableProxies") private var hideUnavailableProxies = false
    @AppStorage("proxyGroupSortOrder") private var proxyGroupSortOrder = ProxyGroupSortOrder.default
    @AppStorage("speedTestURL") private var speedTestURL = "https://www.gstatic.com/generate_204"
    @AppStorage("speedTestTimeout") private var speedTestTimeout = 5000
    
    var body: some View {
        Form {
            Section {
                Toggle("切换代理时自动断开旧连接", isOn: $autoDisconnectOldProxy)
                Toggle("隐藏不可用代理", isOn: $hideUnavailableProxies)
            }
            
            Section(header: Text("代理组排序")) {
                Picker("排序方式", selection: $proxyGroupSortOrder) {
                    ForEach(ProxyGroupSortOrder.allCases) { order in
                        Text(order.description).tag(order)
                    }
                }
            }
            
            Section(header: Text("测速设置")) {
                TextField("测速链接", text: $speedTestURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                Stepper("测速超时时间: \(speedTestTimeout) ms", 
                        value: $speedTestTimeout,
                        in: 1000...10000,
                        step: 500)
            }
        }
        .navigationTitle("全局配置")
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

#Preview {
    NavigationStack {
        GlobalSettingsView()
    }
} 