import SwiftUI
import CoreHaptics

struct GlobalSettingsView: View {
    @AppStorage("autoDisconnectOldProxy") private var autoDisconnectOldProxy = false
    @AppStorage("hideUnavailableProxies") private var hideUnavailableProxies = false
    @AppStorage("proxyGroupSortOrder") private var proxyGroupSortOrder = ProxyGroupSortOrder.default
    @AppStorage("speedTestURL") private var speedTestURL = "https://www.gstatic.com/generate_204"
    @AppStorage("speedTestTimeout") private var speedTestTimeout = 5000
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $autoDisconnectOldProxy) {
                    VStack(alignment: .leading) {
                        Text("自动断开旧连接")
                            .font(.body)
                        Text("切换代理时自动断开旧的连接")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("代理设置")
            }
            
            Section {
                Toggle(isOn: $hideUnavailableProxies) {
                    VStack(alignment: .leading) {
                        Text("隐藏不可用代理")
                            .font(.body)
                        Text("在列表中不显示无法连接的代理")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                NavigationLink {
                    List {
                        ForEach(ProxyGroupSortOrder.allCases) { order in
                            Button {
                                proxyGroupSortOrder = order
                            } label: {
                                HStack {
                                    Text(order.description)
                                    Spacer()
                                    if order == proxyGroupSortOrder {
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
                } label: {
                    HStack {
                        Text("排序方式")
                        Spacer()
                        Text(proxyGroupSortOrder.description)
                            .foregroundColor(.secondary)
                    }
                }

                Label {
                    Text("DIRECT（直连）和 REJECT（拒绝）节点会始终显示在列表中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 24)
            } header: {
                Text("排序设置")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("测速链接", text: $speedTestURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body)
                    Text("用于测试代理延迟的URL地址")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("超时时间")
                    Spacer()
                    Text("\(speedTestTimeout) ms")
                        .foregroundColor(.secondary)
                    Stepper("", value: $speedTestTimeout, in: 1000...10000, step: 500)
                        .labelsHidden()
                        .onChange(of: speedTestTimeout) { _ in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                }
                
                Text("测速请求的最大等待时间")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("测速设置")
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