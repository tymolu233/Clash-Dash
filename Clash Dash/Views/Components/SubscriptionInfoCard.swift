import SwiftUI

struct SubscriptionInfoCard: View {
    let subscriptions: [SubscriptionCardInfo]
    let lastUpdateTime: Date?
    let isLoading: Bool
    let onRefresh: () async -> Void
    
    @State private var currentIndex = 0
    @Environment(\.colorScheme) var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? 
            Color(.systemGray6) : 
            Color(.systemBackground)
    }
    
    private func formatTraffic(_ bytes: Double) -> String {
        if bytes >= 1024 * 1024 * 1024 {
            return String(format: "%.1f GB", bytes / (1024 * 1024 * 1024))
        } else if bytes >= 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.1f KB", bytes / 1024)
        }
    }
    
    private func formatUpdateTime(_ date: Date?) -> String {
        guard let date = date else { return "未更新" }
        let now = Date()
        let diff = now.timeIntervalSince(date)
        
        if diff < 10 {
            return "刚刚"
        } else if diff < 60 {
            return "\(Int(diff))秒前"
        } else if diff < 3600 {
            return "\(Int(diff / 60))分钟前"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))小时前"
        } else {
            return "\(Int(diff / 86400))天前"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    Text("订阅信息")
                        .font(.system(size: 14, weight: .medium))
                }
                
                Spacer()
                
                if subscriptions.count > 1 {
                    Button(action: {
                        withAnimation {
                            currentIndex = (currentIndex + 1) % subscriptions.count
                        }
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }
                
                Button(action: {
                    Task {
                        await onRefresh()
                    }
                }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
            }
            
            let subscription = subscriptions[currentIndex]
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if let name = subscription.name {
                        Text(name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if let expiryDate = subscription.expiryDate {
                        Text("到期：\(expiryDate, style: .date)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(spacing: 4) {
                    HStack {
                        Text("流量：\(formatTraffic(subscription.usedTraffic)) / \(formatTraffic(subscription.totalTraffic))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("更新：\(formatUpdateTime(lastUpdateTime))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray5))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * CGFloat(subscription.usedTraffic / subscription.totalTraffic), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(12)
        .background(cardBackgroundColor)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
} 