import SwiftUI

struct CompactProviderCard: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧图标和名称
            HStack(spacing: 12) {
                // 提供者图标
                Text(String(provider.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                    
                    if let info = provider.subscriptionInfo {
                        Text(formatBytes(info.total))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 右侧过期时间和箭头
            HStack(spacing: 8) {
                if let info = provider.subscriptionInfo,
                   info.expire > 0 {
                    Text(formatExpireDate(info.expire))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text("\(nodes.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
    }
    
    // 格式化字节数
    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }
    
    // 格式化过期时间
    private func formatExpireDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

#Preview {
    CompactProviderCard(
        provider: Provider(
            name: "测试提供者",
            type: "http",
            vehicleType: "http",
            updatedAt: "2024-01-01T12:00:00.000Z",
            subscriptionInfo: SubscriptionInfo(
                upload: 1024 * 1024 * 100,    // 100MB
                download: 1024 * 1024 * 500,  // 500MB
                total: 1024 * 1024 * 1024,    // 1GB
                expire: 1735689600            // 2025-01-01
            )
        ),
        nodes: [],
        viewModel: ProxyViewModel(
            server: ClashServer(
                name: "测试服务器",
                url: "localhost",
                port: "9090",
                secret: "123456"
            )
        )
    )
    .padding()
} 