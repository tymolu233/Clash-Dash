import SwiftUI

struct SubscriptionEmptyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 10)
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 45))
                .foregroundColor(.secondary)
            
            Text("没有订阅配置")
                .font(.title3)
            
            Text("点击添加按钮来添加新的订阅")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
} 