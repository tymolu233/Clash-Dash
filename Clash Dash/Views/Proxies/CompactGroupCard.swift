import SwiftUI

struct CompactGroupCard: View {
    let group: ProxyGroup
    @ObservedObject var viewModel: ProxyViewModel
    @State private var showProxySelector = false
    
    // 添加延迟状态视图
    @ViewBuilder
    private func DelayStatusView(nodeName: String, delay: Int) -> some View {
        HStack(spacing: 4) {
            // 统一使用闪电图标
            Image(systemName: "bolt.fill")
                .font(.system(size: 12))
                .foregroundStyle(nodeName == "REJECT" ? .red : .green)
            
            // 延迟数值容器
            HStack(spacing: 1) {
                if nodeName == "REJECT" {
                    Text("∞")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                } else {
                    Text("\(delay)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                
                // ms 单位
                Text("ms")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(nodeName == "REJECT" ? .red.opacity(0.8) : .green.opacity(0.8))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(nodeName == "REJECT" ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
        .clipShape(Capsule())
    }
    
    var body: some View {
        Button {
            if group.type != "URLTest" {
                showProxySelector = true
            }
        } label: {
            HStack(spacing: 16) {
                // 左侧图标和名称
                HStack(spacing: 12) {
                    // 图标部分
                    Group {
                        if let iconUrl = group.icon, !iconUrl.isEmpty {
                            CachedAsyncImage(url: iconUrl)
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            let firstLetter = String(group.name.prefix(1)).uppercased()
                            Text(firstLetter)
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 36, height: 36)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.system(.body, design: .default))
                            .fontWeight(.semibold)
                        
                        Text(group.now)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // 右侧状态
                HStack(alignment: .center, spacing: 8) {
                    // 延迟信息固定宽度容器
                    HStack(spacing: 8) {
                        if group.now == "REJECT" {
                            DelayStatusView(nodeName: "REJECT", delay: 0)
                        } else {
                            let delay = viewModel.getNodeDelay(nodeName: group.now)
                            if delay >= 0 {
                                DelayStatusView(nodeName: group.now, delay: delay)
                            }
                        }
                    }
                    .frame(width: 85, alignment: .trailing) // 调整宽度
                    
                    if group.type != "URLTest" {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
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
        .sheet(isPresented: $showProxySelector) {
            ProxySelectorSheet(group: group, viewModel: viewModel)
        }
        .onAppear {
            print("📱 CompactGroupCard 已加载, 组名: \(group.name), 是否有图标: \(group.icon != nil)")
        }
    }
}

#Preview {
    CompactGroupCard(
        group: ProxyGroup(
            name: "测试组",
            type: "Selector",
            now: "测试节点",
            all: ["节点1", "节点2"],
            alive: true,
            icon: nil
        ),
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