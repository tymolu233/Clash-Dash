import SwiftUI

struct CompactGroupCard: View {
    let group: ProxyGroup
    @ObservedObject var viewModel: ProxyViewModel
    @State private var showProxySelector = false
    @State private var isExpanded = false
    @AppStorage("hideUnavailableProxies") private var hideUnavailableProxies = false
    @AppStorage("proxyGroupSortOrder") private var proxyGroupSortOrder = ProxyGroupSortOrder.default
    @State private var currentNodeOrder: [String]?
    
    // 获取当前选中节点的延迟颜色
    private var currentNodeColor: Color {
        let delay = viewModel.getNodeDelay(nodeName: group.now)
        return DelayColor.color(for: delay)
    }
    
    // Modify filteredAndSortedNodes to use currentNodeOrder
    private var filteredAndSortedNodes: [String] {
        // Use current order or get sorted nodes
        let nodes = currentNodeOrder ?? getSortedNodes()
        
        // Only apply filtering
        if hideUnavailableProxies {
            return nodes.filter { nodeName in
                if nodeName == "DIRECT" || nodeName == "REJECT" {
                    return true
                }
                return viewModel.getNodeDelay(nodeName: nodeName) != 0
            }
        }
        
        return nodes
    }
    
    // Add separate function for sorting
    private func getSortedNodes() -> [String] {
        var nodes = group.all
        
        switch proxyGroupSortOrder {
        case .latencyAsc:
            nodes.sort { node1, node2 in
                let delay1 = viewModel.getNodeDelay(nodeName: node1)
                let delay2 = viewModel.getNodeDelay(nodeName: node2)
                if delay1 == 0 { return false }
                if delay2 == 0 { return true }
                return delay1 < delay2
            }
        case .latencyDesc:
            nodes.sort { node1, node2 in
                let delay1 = viewModel.getNodeDelay(nodeName: node1)
                let delay2 = viewModel.getNodeDelay(nodeName: node2)
                if delay1 == 0 { return false }
                if delay2 == 0 { return true }
                return delay1 > delay2
            }
        case .nameAsc:
            nodes.sort { $0 < $1 }
        case .nameDesc:
            nodes.sort { $0 > $1 }
        case .default:
            break
        }
        
        return nodes
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                    // Reset currentNodeOrder when closing the list
                    if !isExpanded {
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
                                let firstLetter = String(group.name.prefix(1)).uppercased()
                                Text(firstLetter)
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 36, height: 36)
                                    .background(currentNodeColor.opacity(0.1))
                                    .foregroundStyle(currentNodeColor)
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
                                // 展开时显示闪电图标，点击测速
                                Button {
                                    Task {
                                        await viewModel.testGroupSpeed(groupName: group.name)
                                    }
                                } label: {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(viewModel.testingGroups.contains(group.name) ? .gray : .yellow)
                                }
                                .disabled(viewModel.testingGroups.contains(group.name))
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
                        ForEach(filteredAndSortedNodes, id: \.self) { nodeName in
                            ProxyNodeRow(
                                nodeName: nodeName,
                                isSelected: nodeName == group.now,
                                delay: viewModel.getNodeDelay(nodeName: nodeName)
                            )
                            .onTapGesture {
                                Task {
                                    // Save current order before switching if not already saved
                                    if currentNodeOrder == nil {
                                        currentNodeOrder = filteredAndSortedNodes
                                    }
                                    await viewModel.selectProxy(groupName: group.name, proxyName: nodeName)
                                }
                            }
                            
                            if nodeName != filteredAndSortedNodes.last {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
    }
}


// 代理节点行视图
struct ProxyNodeRow: View {
    let nodeName: String
    let isSelected: Bool
    let delay: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // 选中标记（占位）
            Image(systemName: "checkmark")
                .foregroundColor(isSelected ? .green : .clear)
                .font(.system(size: 14, weight: .bold))
            
            // 节点名称
            Text(nodeName)
                .font(.system(.body))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // 延迟信息
            if delay > 0 {
                Text("\(delay)")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(DelayColor.color(for: delay))
                
                Text("ms")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(DelayColor.color(for: delay).opacity(0.8))
            } else if delay == 0 {
                Image(systemName: "xmark")
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
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
