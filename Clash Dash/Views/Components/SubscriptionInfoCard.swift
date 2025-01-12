import SwiftUI

struct SubscriptionInfoCard: View {
    let subscriptions: [SubscriptionCardInfo]
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
                        
                        Text("更新：\(subscription.lastUpdateTime, style: .date)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: 4)
                                .opacity(0.3)
                                .foregroundColor(.gray)
                            
                            Rectangle()
                                .frame(width: geometry.size.width * CGFloat(subscription.usedTraffic / subscription.totalTraffic), height: 4)
                                .foregroundColor(.blue)
                        }
                        .cornerRadius(2)
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// 预览
#Preview {
    VStack(spacing: 16) {
        SubscriptionInfoCard(subscriptions: [
            SubscriptionCardInfo(
                name: "Premium订阅",
                expiryDate: Date().addingTimeInterval(30 * 24 * 3600),
                lastUpdateTime: Date().addingTimeInterval(-3600),
                usedTraffic: 50 * 1024 * 1024 * 1024,
                totalTraffic: 100 * 1024 * 1024 * 1024
            ),
            SubscriptionCardInfo(
                name: "Basic订阅",
                expiryDate: Date().addingTimeInterval(60 * 24 * 3600),
                lastUpdateTime: Date().addingTimeInterval(-7200),
                usedTraffic: 20 * 1024 * 1024 * 1024,
                totalTraffic: 200 * 1024 * 1024 * 1024
            )
        ])
    }
    .padding()
    .background(Color(.systemGroupedBackground))
} 