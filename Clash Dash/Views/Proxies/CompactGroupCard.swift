import SwiftUI

struct CompactGroupCard: View {
    let group: ProxyGroup
    @ObservedObject var viewModel: ProxyViewModel
    @State private var showProxySelector = false
    
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
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onAppear {
                                    print("📱 使用URL图标: \(iconUrl)")
                                }
                        } else {
                            let firstLetter = String(group.name.prefix(1)).uppercased()
                            Text(firstLetter)
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onAppear {
                                    print("📱 使用文字图标: \(firstLetter), 组名: \(group.name)")
                                }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.medium)
                        
                        Text(group.now)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // 右侧状态
                HStack(spacing: 8) {
                    let delay = viewModel.getNodeDelay(nodeName: group.now)
                    if delay > 0 {
                        Text("\(delay) ms")
                            .font(.caption)
                            .foregroundStyle(DelayColor.color(for: delay))
                    }
                    
                    if group.type != "URLTest" {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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