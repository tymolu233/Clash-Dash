import SwiftUI

struct DefaultServersView: View {
    @EnvironmentObject private var bindingManager: WiFiBindingManager
    @StateObject private var serverViewModel = ServerViewModel()
    @State private var selectedServerIds: Set<String>
    
    init() {
        _selectedServerIds = State(initialValue: Set())
    }
    
    var body: some View {
        Form {
            if serverViewModel.servers.isEmpty {
                Section {
                    Text("没有可用的控制器")
                        .foregroundColor(.secondary)
                }
            } else {
                Section {
                    ForEach(serverViewModel.servers) { server in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(server.name)
                                let displayUrl = (server.openWRTUrl ?? "").isEmpty ? server.url : server.openWRTUrl ?? ""
                                let displayPort = (server.openWRTUrl ?? "").isEmpty ? server.port : server.openWRTPort ?? ""
                                Text("\(displayUrl):\(displayPort)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedServerIds.contains(server.id.uuidString) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let serverId = server.id.uuidString
                            if selectedServerIds.contains(serverId) {
                                selectedServerIds.remove(serverId)
                            } else {
                                selectedServerIds.insert(serverId)
                            }
                            bindingManager.updateDefaultServers(selectedServerIds)
                        }
                    }
                } header: {
                    Text("选择默认显示的控制器")
                } footer: {
                    Text("当启用了 Wi-Fi 绑定功能但未连接到已绑定的 Wi-Fi 时（例如使用数据流量），将显示这些控制器")
                }
            }
        }
        .navigationTitle("默认控制器")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedServerIds = bindingManager.defaultServerIds
            Task { @MainActor in
                await serverViewModel.loadServers()
            }
        }
    }
} 