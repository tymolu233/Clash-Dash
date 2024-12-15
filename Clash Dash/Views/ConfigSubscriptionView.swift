import SwiftUI

struct ConfigSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ConfigSubscriptionViewModel
    let server: ClashServer
    
    @State private var showingAddSheet = false
    @State private var editingSubscription: ConfigSubscription?
    @State private var isUpdating = false
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    init(server: ClashServer) {
        self.server = server
        self._viewModel = StateObject(wrappedValue: ConfigSubscriptionViewModel(server: server))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if viewModel.isLoading {
                        VStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { _ in
                                SubscriptionCardPlaceholder()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .shimmering()
                    } else if viewModel.subscriptions.isEmpty {
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
                        .padding(.horizontal)
                        .transition(.opacity)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.subscriptions) { subscription in
                                SubscriptionCard(
                                    subscription: subscription,
                                    onEdit: {
                                        impactFeedback.impactOccurred()
                                        editingSubscription = subscription
                                    },
                                    onToggle: { enabled in
                                        impactFeedback.impactOccurred()
                                        Task {
                                            await viewModel.toggleSubscription(subscription, enabled: enabled)
                                        }
                                    },
                                    onUpdate: {
                                        impactFeedback.impactOccurred()
                                        Task {
                                            await viewModel.updateSubscription(subscription)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("订阅管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        impactFeedback.impactOccurred()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        impactFeedback.impactOccurred()
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task {
            await viewModel.loadSubscriptions()
        }
        .sheet(isPresented: $showingAddSheet) {
            SubscriptionEditView(
                viewModel: viewModel,
                server: server,
                onSave: { subscription in
                    Task {
                        await viewModel.addSubscription(subscription)
                    }
                }
            )
        }
        .sheet(item: $editingSubscription) { subscription in
            SubscriptionEditView(
                viewModel: viewModel,
                server: server,
                subscription: subscription,
                onSave: { updated in
                    Task {
                        await viewModel.updateSubscription(updated)
                    }
                }
            )
        }
        .overlay {
            if isUpdating {
                ProgressView()
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// 订阅卡片占位符
struct SubscriptionCardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏占位符
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 20)
                Spacer()
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 24)
            }
            
            // 地址占位符
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 16)
            
            // 过滤规则占位符
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 16, height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 16)
            }
            
            // 更新按钮占位符
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 32)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// 订阅卡片
struct SubscriptionCard: View {
    let subscription: ConfigSubscription
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void
    let onUpdate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Text(subscription.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                
                Toggle("", isOn: .constant(subscription.enabled))
                    .labelsHidden()
                    .onChange(of: subscription.enabled) { newValue in
                        onToggle(newValue)
                    }
            }
            
            // 订阅地址
            Text(subscription.address)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // 过滤规则
            if let keyword = subscription.keyword {
                HStack {
                    Label {
                        Text("包含: \(keyword)")
                    } icon: {
                        Image(systemName: "text.magnifyingglass")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if let exKeyword = subscription.exKeyword {
                HStack {
                    Label {
                        Text("排除: \(exKeyword)")
                    } icon: {
                        Image(systemName: "text.magnifyingglass")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            // 更新按钮
            Button(action: onUpdate) {
                Label("更新", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// 订阅编辑视图
struct SubscriptionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ConfigSubscriptionViewModel
    let server: ClashServer
    let subscription: ConfigSubscription?
    let onSave: (ConfigSubscription) -> Void
    
    @State private var name = ""
    @State private var address = ""
    @State private var enabled = true
    @State private var subUA = "Clash"
    @State private var subConvert = false
    @State private var keyword = ""
    @State private var exKeyword = ""
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    init(viewModel: ConfigSubscriptionViewModel, server: ClashServer, subscription: ConfigSubscription? = nil, onSave: @escaping (ConfigSubscription) -> Void) {
        self.viewModel = viewModel
        self.server = server
        self.subscription = subscription
        self.onSave = onSave
        
        // 初始化状态
        if let sub = subscription {
            _name = State(initialValue: sub.name)
            _address = State(initialValue: sub.address)
            _enabled = State(initialValue: sub.enabled)
            _subUA = State(initialValue: sub.subUA)
            _subConvert = State(initialValue: sub.subConvert)
            _keyword = State(initialValue: sub.keyword ?? "")
            _exKeyword = State(initialValue: sub.exKeyword ?? "")
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称", text: $name)
                    TextField("订阅地址", text: $address)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Toggle("启用", isOn: $enabled)
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    TextField("User-Agent", text: $subUA)
                        .textInputAutocapitalization(.never)
                    Toggle("订阅转换", isOn: $subConvert)
                } header: {
                    Text("订阅设置")
                } footer: {
                    Text("如果订阅链接返回的不是 Clash 配置，请开启订阅转换")
                }
                
                Section {
                    TextField("包含关键词", text: $keyword)
                        .textInputAutocapitalization(.never)
                    TextField("排除关键词", text: $exKeyword)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("节点过滤")
                } footer: {
                    Text("多个关键词用空格分隔")
                }
            }
            .navigationTitle(subscription == nil ? "添加订阅" : "编辑订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        impactFeedback.impactOccurred()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        impactFeedback.impactOccurred()
                        let sub = ConfigSubscription(
                            id: subscription?.id ?? 0,
                            name: name,
                            address: address,
                            enabled: enabled,
                            subUA: subUA,
                            subConvert: subConvert,
                            keyword: keyword.isEmpty ? nil : keyword,
                            exKeyword: exKeyword.isEmpty ? nil : exKeyword
                        )
                        onSave(sub)
                        dismiss()
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ConfigSubscriptionView(
        server: ClashServer(name: "测试服务器", url: "10.1.1.2", port: "9090", secret: "123456")
    )
} 