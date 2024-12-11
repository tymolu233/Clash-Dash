import SwiftUI

struct OpenClashConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    let server: ClashServer
    
    @State private var configs: [OpenClashConfig] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isChanging = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if isLoading {
                        VStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { _ in
                                ConfigCardPlaceholder()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .shimmering()
                    } else if configs.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                                .frame(height: 10)
                            
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 45))
                                .foregroundColor(.secondary)
                            
                            Text("没有找到配置文件")
                                .font(.title3)
                            
                            Text("请确认配置文件目录不为空")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .transition(.opacity)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(configs) { config in
                                ConfigCard(config: config) {
                                    switchConfig(config)
                                }
                                .transition(.opacity)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                }
                .animation(.easeInOut, value: isLoading)
                .animation(.easeInOut, value: configs.isEmpty)
            }
            .navigationTitle("配置文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", action: { dismiss() })
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await loadConfigs()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .disabled(isChanging)
        .overlay {
            if isChanging {
                ProgressView()
            }
        }
        .task {
            await loadConfigs()
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadConfigs() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            configs = try await viewModel.fetchOpenClashConfigs(server)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func switchConfig(_ config: OpenClashConfig) {
        guard !isChanging else { return }
        
        isChanging = true
        Task {
            do {
                try await viewModel.switchOpenClashConfig(server, configName: config.name)
                await loadConfigs()  // 重新加载配置列表以更新状态
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isChanging = false
        }
    }
}

struct ConfigCard: View {
    let config: OpenClashConfig
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                // 标题行
                HStack {
                    Text(config.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    StateLabel(state: config.state)
                }
                
                // 更新时间
                Label {
                    Text(config.mtime, style: .date)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                }
                .font(.footnote)
                
                // 语法检查状态
                Label {
                    Text(config.check.rawValue)
                        .foregroundColor(config.check == .normal ? .green : .red)
                } icon: {
                    Image(systemName: config.check == .normal ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(config.check == .normal ? .green : .red)
                }
                .font(.footnote)
                
                // 订阅信息
                if let subscription = config.subscription {
                    Divider()
                        .padding(.vertical, 4)
                    SubscriptionInfoView(info: subscription)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
}

struct StateLabel: View {
    let state: OpenClashConfig.ConfigState
    
    var body: some View {
        Text(state.rawValue)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(state == .enabled ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
            .foregroundColor(state == .enabled ? .green : .secondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(state == .enabled ? Color.green.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 0.5)
            )
    }
}

struct SubscriptionInfoView: View {
    let info: OpenClashConfig.SubscriptionInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if info.subInfo != "No Sub Info Found" {
                // 流量信息
                HStack(spacing: 16) {
                    if let used = info.used {
                        DataLabel(title: "已用", value: used)
                    }
                    if let surplus = info.surplus {
                        DataLabel(title: "剩余", value: surplus)
                    }
                    if let total = info.total {
                        DataLabel(title: "总量", value: total)
                    }
                }
                
                // 到期信息
                HStack(spacing: 16) {
                    if let dayLeft = info.dayLeft {
                        DataLabel(title: "剩余天数", value: "\(dayLeft)天")
                    }
                    if let expire = info.expire {
                        DataLabel(title: "到期时间", value: expire)
                    }
                }
                
                // 使用百分比
                if let percent = info.percent {
                    ProgressView(value: Double(percent) ?? 0, total: 100)
                        .tint(.blue)
                }
            } else {
                Text("无订阅信息")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
    }
}

struct DataLabel: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .bold()
        }
    }
}

struct ConfigCardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行占位符
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 20)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 20)
            }
            
            // 更新时间占位符
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 16, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 16)
            }
            
            // 语法检查状态占位符
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 16, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 16)
            }
            
            // 订阅信息占位符
            Divider()
                .padding(.vertical, 4)
            
            // 流量信息占位符
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 16)
                    }
                }
            }
            
            // 进度条占位符
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 4)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
}

struct ShimmeringView: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .mask(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [.clear, .white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: -geometry.size.width + (geometry.size.width * 3 * phase))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            )
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmeringView())
    }
} 