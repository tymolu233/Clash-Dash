import SwiftUI

struct CompactGroupCard: View {
    let group: ProxyGroup
    @ObservedObject var viewModel: ProxyViewModel
    @State private var showProxySelector = false
    @State private var isExpanded = false
    @AppStorage("hideUnavailableProxies") private var hideUnavailableProxies = false
    @AppStorage("proxyGroupSortOrder") private var proxyGroupSortOrder = ProxyGroupSortOrder.default
    @State private var currentNodeOrder: [String]?
    @State private var displayedNodes: [String] = []
    
    // 获取当前选中节点的延迟颜色
    private var currentNodeColor: Color {
        let delay = viewModel.getNodeDelay(nodeName: group.now)
        return DelayColor.color(for: delay)
    }
    
    // Add separate function for sorting
    private func getSortedNodes() -> [String] {
        // First separate special nodes and normal nodes
        let specialNodes = ["DIRECT", "PROXY", "REJECT"]
        let normalNodes = group.all.filter { node in
            !specialNodes.contains(node.uppercased())
        }
        let specialNodesPresent = group.all.filter { node in
            specialNodes.contains(node.uppercased())
        }
        
        // Sort normal nodes according to settings
        var sortedNormalNodes = normalNodes
        switch proxyGroupSortOrder {
        case .latencyAsc:
            sortedNormalNodes.sort { node1, node2 in
                let delay1 = viewModel.getNodeDelay(nodeName: node1)
                let delay2 = viewModel.getNodeDelay(nodeName: node2)
                if delay1 == 0 { return false }
                if delay2 == 0 { return true }
                return delay1 < delay2
            }
        case .latencyDesc:
            sortedNormalNodes.sort { node1, node2 in
                let delay1 = viewModel.getNodeDelay(nodeName: node1)
                let delay2 = viewModel.getNodeDelay(nodeName: node2)
                if delay1 == 0 { return false }
                if delay2 == 0 { return true }
                return delay1 > delay2
            }
        case .nameAsc:
            sortedNormalNodes.sort { $0 < $1 }
        case .nameDesc:
            sortedNormalNodes.sort { $0 > $1 }
        case .default:
            break
        }
        
        // Combine special nodes and sorted normal nodes
        return specialNodesPresent + sortedNormalNodes
    }
    
    private func updateDisplayedNodes() {
        var nodes = currentNodeOrder ?? getSortedNodes()
        
        if hideUnavailableProxies {
            nodes = nodes.filter { nodeName in
                if nodeName == "DIRECT" || nodeName == "REJECT" {
                    return true
                }
                return viewModel.getNodeDelay(nodeName: nodeName) != 0
            }
        }
        
        displayedNodes = nodes
    }
    
    // 添加动画时间计算函数
    private func getAnimationDuration() -> Double {
        let baseTime = 0.3  // 基础动画时间
        let nodeCount = group.all.count
        
        // 根据节点数量计算额外时间
        // 每20个节点增加0.1秒，最多增加0.4秒
        let extraTime = min(Double(nodeCount) / 20.0 * 0.1, 0.4)
        
        return baseTime + extraTime
    }
    
    // 添加辅助函数来处理名称
    private var displayInfo: (icon: String, name: String) {
        let name = group.name
        guard let firstScalar = name.unicodeScalars.first,
              firstScalar.properties.isEmoji else {
            return (String(name.prefix(1)).uppercased(), name)
        }
        
        // 如果第一个字符是 emoji，将其作为图标，并从名称中移除
        let emoji = String(name.unicodeScalars.prefix(1))
        let remainingName = name.dropFirst()
        return (emoji, String(remainingName).trimmingCharacters(in: .whitespaces))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                // 使用计算的动画时间
                withAnimation(.spring(
                    response: getAnimationDuration(),
                    dampingFraction: 0.8
                )) {
                    isExpanded.toggle()
                    if isExpanded {
                        updateDisplayedNodes()
                    } else {
                        currentNodeOrder = nil
                    }
                }
            } label: {
                HStack(spacing: 15) {
                    // 左侧图标和名称
                    HStack(spacing: 10) {
                        // 图标部分
                        Group {
                            if let iconUrl = group.icon, !iconUrl.isEmpty {
                                CachedAsyncImage(url: iconUrl)
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Text(displayInfo.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 36, height: 36)
                                    .background(currentNodeColor.opacity(0.1))
                                    .foregroundStyle(currentNodeColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayInfo.name)
                                .font(.system(.body, design: .default))
                                .fontWeight(.semibold)
                            
                            Text(group.now)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    
                    Spacer()
                    
                    // 右侧状态
                    HStack(alignment: .center, spacing: 0) {
                        Spacer()
                            .frame(width: 20)
                        
                        // 竖条分隔符
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 3, height: 30)
                            .opacity(0.3)
                            .padding(.trailing, 10)
                        
                        // 节点数量和容器
                        HStack(spacing: 10) {
                            if isExpanded {
                                SpeedTestButton(
                                    isTesting: viewModel.testingGroups.contains(group.name)
                                ) {
                                    Task {
                                        await viewModel.testGroupSpeed(groupName: group.name)
                                    }
                                }
                            } else {
                                Text("\(group.all.count)")
                                    .fontWeight(.medium)
                                    .font(.system(size: 16, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            
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
            
            // 展开的详细内容
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(displayedNodes, id: \.self) { nodeName in
                            ProxyNodeRow(
                                nodeName: nodeName,
                                isSelected: nodeName == group.now,
                                delay: viewModel.getNodeDelay(nodeName: nodeName)
                            )
                            .onTapGesture {
                                Task {
                                    if currentNodeOrder == nil {
                                        currentNodeOrder = displayedNodes
                                    }
                                    await viewModel.selectProxy(groupName: group.name, proxyName: nodeName)
                                }
                            }
                            
                            if nodeName != displayedNodes.last {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                // Add bottom shadow to match the card
                .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
            }
        }
        // Update nodes when hideUnavailableProxies changes
        .onChange(of: hideUnavailableProxies) { _ in
            if isExpanded {
                updateDisplayedNodes()
            }
        }
        // Update nodes when proxyGroupSortOrder changes
        .onChange(of: proxyGroupSortOrder) { _ in
            if isExpanded && currentNodeOrder == nil {
                updateDisplayedNodes()
            }
        }
    }
}

#Preview {
    CompactGroupCard(
        group: ProxyGroup(
            name: "测试组",
            type: "Selector",
            now: "测试节点很长的名字测试节点很长的名字",
            all: ["节点1", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2", "节点2"],
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
