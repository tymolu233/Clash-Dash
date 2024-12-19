import SwiftUI

struct ServerRowView: View {
    let server: ClashServer
    
    private var versionDisplay: String {
        guard let version = server.version else { return "" }
        return version.count > 15 ? String(version.prefix(15)) + "..." : version
    }
    
    private var statusIcon: String {
        switch server.status {
        case .ok: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .unauthorized: return "lock.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 状态指示器
            ZStack {
                Circle()
                    .fill(server.status.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: statusIcon)
                    .foregroundColor(server.status.color)
            }
            
            // 服务器信息
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(server.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if server.isQuickLaunch {
                        Image(systemName: "bolt.circle.fill")
                            .foregroundColor(.yellow)
                            .font(.subheadline)
                    }
                }
                
                if server.status == .ok {
                    HStack(spacing: 4) {
                        // 服务器来源标签
                        Label {
                            Text(server.source == .clashController ? "Clash 控制器" : "OpenWRT")
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: server.source == .clashController ? "server.rack" : "wifi.router")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                        
                        if server.source == .clashController {
                            Text("•")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            // 版本信息
                            Label {
                                Text(versionDisplay)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "tag")
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                            .lineLimit(1)
                        }
                    }
                } else if let errorMessage = server.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(server.status.color)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(height: 80)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
} 