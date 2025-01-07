import Foundation
import SwiftUI

private let logger = LogManager.shared

struct WiFiBinding: Codable, Identifiable, Equatable {
    let id: UUID
    var ssid: String
    var serverIds: [String]
    
    init(id: UUID = UUID(), ssid: String, serverIds: [String]) {
        self.id = id
        self.ssid = ssid
        self.serverIds = serverIds
    }
    
    static func == (lhs: WiFiBinding, rhs: WiFiBinding) -> Bool {
        lhs.id == rhs.id && lhs.ssid == rhs.ssid && lhs.serverIds == rhs.serverIds
    }
}

class WiFiBindingManager: ObservableObject {
    @Published var bindings: [WiFiBinding] = []
    private let defaults = UserDefaults.standard
    private let storageKey = "wifi_bindings"
    private let enableKey = "enableWiFiBinding"
    
    var isEnabled: Bool {
        get { defaults.bool(forKey: enableKey) }
    }
    
    init() {
        print("🏁 初始化 WiFiBindingManager")
        logger.log("初始化 WiFiBindingManager")
        if isEnabled {
            loadBindings()
        } else {
            print("⚠️ Wi-Fi 绑定功能未启用，跳过加载绑定数据")
            logger.log("Wi-Fi 绑定功能未启用，跳过加载绑定数据")
        }
    }
    
    private func loadBindings() {
        if let data = defaults.data(forKey: storageKey),
           let bindings = try? JSONDecoder().decode([WiFiBinding].self, from: data) {
            self.bindings = bindings
            // print("📥 从 UserDefaults 加载绑定: \(bindings.count) 个")
            for binding in bindings {
                // print("   - SSID: \(binding.ssid), 服务器IDs: \(binding.serverIds)")
            }
        }
    }
    
    private func saveBindings() {
        if !isEnabled {
            // print("⚠️ Wi-Fi 绑定功能未启用，跳过保存绑定数据")
            return
        }
        
        if let data = try? JSONEncoder().encode(bindings) {
            defaults.set(data, forKey: storageKey)
            // print("💾 保存 Wi-Fi 绑定到 UserDefaults: \(bindings.count) 个")
            for binding in bindings {
                // print("   - SSID: \(binding.ssid), 服务器IDs: \(binding.serverIds)")
            }
        } else {
            // print("❌ 保存 Wi-Fi 绑定失败")
        }
    }
    
    func addBinding(_ binding: WiFiBinding) {
        if !isEnabled {
            // print("⚠️ Wi-Fi 绑定功能未启用，无法添加绑定")
            return
        }
        
        // print("➕ 添加新的 Wi-Fi 绑定: SSID=\(binding.ssid), 服务器IDs=\(binding.serverIds)")
        bindings.append(binding)
        saveBindings()
        objectWillChange.send()
        // print("✅ 绑定添加完成，当前总数: \(bindings.count)")
    }
    
    func updateBinding(_ binding: WiFiBinding) {
        if !isEnabled {
            // print("⚠️ Wi-Fi 绑定功能未启用，无法更新绑定")
            return
        }
        
        // print("🔄 更新 Wi-Fi 绑定: SSID=\(binding.ssid), 服务器IDs=\(binding.serverIds)")
        if let index = bindings.firstIndex(where: { $0.id == binding.id }) {
            var newBindings = bindings
            newBindings[index] = binding
            bindings = newBindings
            saveBindings()
            objectWillChange.send()
            // print("✅ 绑定更新完成，当前总数: \(bindings.count)")
            logger.log("绑定更新完成，当前总数: \(bindings.count)")
        } else {
            // print("❌ 未找到要更新的绑定: \(binding.id)")
            logger.log("未找到要更新的绑定: \(binding.id)")
        }
    }
    
    func removeBinding(_ binding: WiFiBinding) {
        if !isEnabled {
            // print("⚠️ Wi-Fi 绑定功能未启用，无法删除绑定")
            return
        }
        
        // print("🗑️ 删除 Wi-Fi 绑定: SSID=\(binding.ssid)")
        bindings.removeAll { $0.id == binding.id }
        saveBindings()
        objectWillChange.send()
        // print("✅ 绑定删除完成，当前总数: \(bindings.count)")
        logger.log("绑定删除完成，当前总数: \(bindings.count)")
    }
    
    // 添加对功能开关变化的监听
    func onEnableChange() {
        if isEnabled {
            // print("🔄 Wi-Fi 绑定功能已启用，加载绑定数据")
            logger.log("Wi-Fi 绑定功能已启用，加载绑定数据")
            loadBindings()
        } else {
            // print("🔄 Wi-Fi 绑定功能已禁用，清空绑定数据")
            logger.log("Wi-Fi 绑定功能已禁用，清空绑定数据")
            bindings.removeAll()
            objectWillChange.send()
        }
    }
}