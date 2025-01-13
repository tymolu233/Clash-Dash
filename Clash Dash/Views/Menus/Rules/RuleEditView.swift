import SwiftUI

private let logger = LogManager.shared

struct RuleEditView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let rule: OpenClashRule?
    let onSave: (OpenClashRule) -> Void
    let server: ClashServer  // 添加服务器参数
    
    @State private var selectedType: RuleType = .domain
    @State private var target: String = ""
    @State private var action: String = ""
    @State private var comment: String = ""
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var proxyGroups: [String] = []
    @State private var isLoadingProxies = true
    @State private var noResolve = false
    
    init(title: String = "添加规则", rule: OpenClashRule? = nil, server: ClashServer, onSave: @escaping (OpenClashRule) -> Void) {
        self.title = title
        self.rule = rule
        self.server = server
        self.onSave = onSave
        
        // 如果是编辑模式，设置初始值
        if let rule = rule {
            _selectedType = State(initialValue: RuleType(rawValue: rule.type) ?? .domain)
            _target = State(initialValue: rule.target)
            _action = State(initialValue: rule.action.replacingOccurrences(of: ",no-resolve", with: ""))
            _comment = State(initialValue: rule.comment ?? "")
            _noResolve = State(initialValue: rule.action.hasSuffix(",no-resolve"))
        }
    }
    
    private var isNoResolveEnabled: Bool {
        selectedType == .ipCidr || selectedType == .ipCidr6
    }
    
    private func fetchProxyGroups() {
        isLoadingProxies = true
        let scheme = server.clashUseSSL ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(server.url):\(server.port)/proxies") else {
            proxyGroups = ["获取失败"]
            isLoadingProxies = false
            return
        }
        
        var request = URLRequest(url: url)
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                defer { isLoadingProxies = false }
                
                if let error = error {
                    logger.log("附加规则 - 获取代理列表失败: \(error)")
                    proxyGroups = ["获取失败"]
                    return
                }
                
                guard let data = data else {
                    proxyGroups = ["获取失败"]
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let proxies = json["proxies"] as? [String: Any],
                       let global = proxies["GLOBAL"] as? [String: Any],
                       let all = global["all"] as? [String] {
                        proxyGroups = all
                    } else {
                        proxyGroups = ["获取失败"]
                    }
                } catch {
                    logger.log("附加规则 - 解析代理列表失败: \(error)")
                    proxyGroups = ["获取失败"]
                }
            }
        }.resume()
    }
    
    private func save() {
        // 验证输入
        guard !target.isEmpty else {
            errorMessage = "请输入匹配内容"
            showError = true
            return
        }
        
        guard !action.isEmpty else {
            errorMessage = "请输入策略"
            showError = true
            return
        }
        
        // 创建规则
        let finalAction = noResolve && isNoResolveEnabled ? "\(action),no-resolve" : action
        let newRule = OpenClashRule(
            id: rule?.id ?? UUID(),  // 如果是编辑模式，保持原有ID
            target: target.trimmingCharacters(in: .whitespacesAndNewlines),
            type: selectedType.rawValue,
            action: finalAction.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: rule?.isEnabled ?? true,  // 如果是编辑模式，保持原有状态
            comment: comment.isEmpty ? nil : comment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        onSave(newRule)
        dismiss()
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 规则类型选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("规则类型")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Menu {
                            ForEach(RuleType.allCases, id: \.self) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: type.iconName)
                                            .foregroundColor(type.iconColor)
                                            .frame(width: 20)
                                        Text(type.rawValue)
                                            .foregroundColor(.primary)
                                        Spacer(minLength: 8)
                                        Text(type.description)
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedType.iconName)
                                    .foregroundColor(selectedType.iconColor)
                                    .frame(width: 20)
                                Text(selectedType.rawValue)
                                    .foregroundColor(.primary)
                                Spacer(minLength: 8)
                                Text(selectedType.description)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.secondary)
                                    .imageScale(.small)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // 匹配内容
                    VStack(alignment: .leading, spacing: 8) {
                        Text("匹配内容")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("请输入匹配内容", text: $target)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                        
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text(selectedType.example)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 策略选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("策略")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isLoadingProxies {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("正在加载策略列表...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                        } else {
                            Menu {
                                ForEach(proxyGroups, id: \.self) { proxy in
                                    Button {
                                        action = proxy
                                    } label: {
                                        HStack {
                                            Text(proxy)
                                            if action == proxy {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(action.isEmpty ? "请选择策略" : action)
                                        .foregroundColor(action.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.secondary)
                                        .imageScale(.small)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // no-resolve 开关
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $noResolve) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("跳过 DNS 解析")
                                    .font(.headline)
                                Text("仅支持关于目标IP的规则，域名开始匹配关于目标IP规则时，mihomo 将触发 dns 解析来检查域名的目标IP是否匹配规则，可以选择 no-resolve 选项以跳过 dns 解析")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(!isNoResolveEnabled)
                        .opacity(isNoResolveEnabled ? 1 : 0.5)
                    }
                    .padding(.horizontal)
                    
                    // 备注
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("可选", text: $comment)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.separator), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("保存")
                            .bold()
                    }
                    .disabled(target.isEmpty || action.isEmpty)
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .task {
                fetchProxyGroups()
            }
        }
    }
} 
