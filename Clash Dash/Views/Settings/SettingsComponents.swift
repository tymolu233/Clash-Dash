import SwiftUI
import CoreLocation

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
                    HapticManager.shared.impact(.light)
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
    case multiColumn = "multiColumn"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .detailed: return "详细"
        case .compact: return "简洁"
        case .multiColumn: return "多列"
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

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var showLocationDeniedAlert = false
    private var isRequestingAuthorization = false
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }
    
    func requestWhenInUseAuthorization() {
        isRequestingAuthorization = true
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if manager.authorizationStatus == .denied {
            showLocationDeniedAlert = true
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isRequestingAuthorization else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("位置权限已授权")
                self?.manager.startUpdatingLocation()
            case .denied:
                print("位置权限被拒绝")
                self?.showLocationDeniedAlert = true
            case .restricted:
                print("位置权限受限")
            case .notDetermined:
                print("位置权限未确定")
            @unknown default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        manager.stopUpdatingLocation()
        isRequestingAuthorization = false
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置更新失败: \(error.localizedDescription)")
        isRequestingAuthorization = false
    }
} 