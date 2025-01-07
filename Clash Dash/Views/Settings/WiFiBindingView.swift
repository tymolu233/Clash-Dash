import SwiftUI
import NetworkExtension

struct WiFiBindingView: View {
    @EnvironmentObject private var bindingManager: WiFiBindingManager
    @StateObject private var serverViewModel = ServerViewModel()
    @State private var showingAddSheet = false
    @State private var currentWiFiSSID: String = ""
    
    var body: some View {
        List {
            if bindingManager.bindings.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "wifi")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("没有 Wi-Fi 绑定")
                                .font(.headline)
                            Text("点击添加按钮来创建新的 Wi-Fi 绑定")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(bindingManager.bindings) { binding in
                    NavigationLink {
                        EditWiFiBindingView(binding: binding)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "wifi")
                                    .foregroundColor(.blue)
                                Text(binding.ssid)
                                    .font(.headline)
                            }
                            
                            let boundServers = serverViewModel.servers.filter { server in
                                binding.serverIds.contains(server.id.uuidString)
                            }
                            Text("已绑定 \(boundServers.count) 个服务器")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        bindingManager.removeBinding(bindingManager.bindings[index])
                    }
                }
            }
        }
        .navigationTitle("Wi-Fi 绑定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                AddWiFiBindingView(initialSSID: currentWiFiSSID)
            }
        }
        .onAppear {
            // 获取当前 Wi-Fi SSID
            NEHotspotNetwork.fetchCurrent { network in
                if let network = network {
                    currentWiFiSSID = network.ssid
                }
            }
            
            // 加载服务器列表
            Task { @MainActor in
                await serverViewModel.loadServers()
            }
        }
    }
}

struct AddWiFiBindingView: View {
    @EnvironmentObject private var bindingManager: WiFiBindingManager
    @StateObject private var serverViewModel = ServerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var ssid: String
    @State private var selectedServerIds: Set<String> = []
    
    init(initialSSID: String = "") {
        _ssid = State(initialValue: initialSSID)
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Wi-Fi 名称", text: $ssid)
            } header: {
                Text("Wi-Fi 设置")
            }
            
            if serverViewModel.servers.isEmpty {
                Section {
                    Text("没有可用的服务器")
                        .foregroundColor(.secondary)
                }
            } else {
                Section {
                    ForEach(serverViewModel.servers) { server in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(server.name)
                                Text(server.url)
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
                        }
                    }
                } header: {
                    Text("选择服务器")
                }
            }
        }
        .navigationTitle("添加 Wi-Fi 绑定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let binding = WiFiBinding(
                        ssid: ssid,
                        serverIds: Array(selectedServerIds)
                    )
                    bindingManager.addBinding(binding)
                    dismiss()
                }
                .disabled(ssid.isEmpty || selectedServerIds.isEmpty)
            }
        }
        .onAppear {
            // 加载完整的服务器列表
            Task { @MainActor in
                await serverViewModel.loadServers()
            }
        }
    }
}

struct EditWiFiBindingView: View {
    @EnvironmentObject private var bindingManager: WiFiBindingManager
    let binding: WiFiBinding
    @StateObject private var serverViewModel = ServerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var ssid: String
    @State private var selectedServerIds: Set<String>
    
    init(binding: WiFiBinding) {
        self.binding = binding
        _ssid = State(initialValue: binding.ssid)
        _selectedServerIds = State(initialValue: Set(binding.serverIds))
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Wi-Fi 名称", text: $ssid)
            } header: {
                Text("Wi-Fi 设置")
            }
            
            if serverViewModel.servers.isEmpty {
                Section {
                    Text("没有可用的服务器")
                        .foregroundColor(.secondary)
                }
            } else {
                Section {
                    ForEach(serverViewModel.servers) { server in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(server.name)
                                Text(server.url)
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
                        }
                    }
                } header: {
                    Text("选择服务器")
                }
            }
        }
        .navigationTitle("编辑 Wi-Fi 绑定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let updatedBinding = WiFiBinding(
                        id: binding.id,
                        ssid: ssid,
                        serverIds: Array(selectedServerIds)
                    )
                    bindingManager.updateBinding(updatedBinding)
                    dismiss()
                }
                .disabled(ssid.isEmpty || selectedServerIds.isEmpty)
            }
        }
        .onAppear {
            Task { @MainActor in
                await serverViewModel.loadServers()
            }
        }
    }
}