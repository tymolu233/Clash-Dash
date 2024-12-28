import SwiftUI

struct CompactProviderCard: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    @State private var isExpanded = false
    
    private var usageInfo: String? {
        guard let info = provider.subscriptionInfo else { return nil }
        let used = Double(info.upload + info.download)
        return "\(formatBytes(Int64(used)))/\(formatBytes(info.total))"
    }
    
    private var timeInfo: (update: String, expire: String)? {
        guard let updatedAt = provider.updatedAt,
              let info = provider.subscriptionInfo,
              info.expire > 0 else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let updateDate = formatter.date(from: updatedAt) ?? Date()
        let expireDate = Date(timeIntervalSince1970: TimeInterval(info.expire))
        
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .short
        
        return (
            update: relativeFormatter.localizedString(for: updateDate, relativeTo: Date()),
            expire: formatExpireDate(info.expire)
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 15) {
                    // 左侧图标和名称
                    HStack(spacing: 10) {
                        // 提供者图标
                        Text(String(provider.name.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 36, height: 36)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.name)
                                .font(.system(.body, design: .default))
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            if let usage = usageInfo {
                                Text(usage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
//                                    .fontWeight()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
//                    Spacer()
                    
                    // 右侧状态
                    HStack(alignment: .center, spacing: 0) {
                        // 时间信息
                        if let times = timeInfo {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("更新：\(times.update)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("到期：\(times.expire)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 110)
                        }
                        
                        // 竖条分隔符
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 3, height: 30)
                            .opacity(0.3)
                            .padding(.horizontal, 5)
                        
                        // 节点数量和箭头
                        HStack(spacing: 10) {
                            Text("\(nodes.count)")
                                .fontWeight(.medium)
                                .font(.system(size: 16, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(.tertiaryLabel))
                                .fontWeight(.bold)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                        .frame(width: 55, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(height: 64)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            
            // 展开的节点列表
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(nodes) { node in
                            ProxyNodeRow(
                                nodeName: node.name,
                                isSelected: false,
                                delay: node.delay
                            )
                            
                            if node.id != nodes.last?.id {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
            }
        }
    }
    
    // 格式化字节数
    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1 {
            return String(format: "%.1fGB", gb)
        } else if mb >= 1 {
            return String(format: "%.1fMB", mb)
        } else if kb >= 1 {
            return String(format: "%.1fKB", kb)
        } else {
            return "\(bytes)B"
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
