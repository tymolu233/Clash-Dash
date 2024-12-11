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
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if configs.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                            .frame(height: 20)
                        
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("没有找到配置文件")
                            .font(.title2)
                        
                        Text("请确认配置文件目录不为空")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(configs) { config in
                                ConfigCard(config: config) {
                                    switchConfig(config)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("配置文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
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
        .navigationViewStyle(.stack)
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
            VStack(alignment: .leading, spacing: 12) {
                // 标题行
                HStack {
                    Text(config.name)
                        .font(.headline)
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
                .font(.subheadline)
                
                // 语法检查状态
                Label {
                    Text(config.check.rawValue)
                        .foregroundColor(config.check == .normal ? .green : .red)
                } icon: {
                    Image(systemName: config.check == .normal ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(config.check == .normal ? .green : .red)
                }
                .font(.subheadline)
                
                // 订阅信息
                if let subscription = config.subscription {
                    Divider()
                    SubscriptionInfoView(info: subscription)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct StateLabel: View {
    let state: OpenClashConfig.ConfigState
    
    var body: some View {
        Text(state.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(state == .enabled ? Color.green.opacity(0.2) : Color.secondary.opacity(0.2))
            .foregroundColor(state == .enabled ? .green : .secondary)
            .cornerRadius(8)
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