import SwiftUI

struct SubscriptionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ConfigSubscriptionViewModel
    let subscription: ConfigSubscription?
    let onSave: (ConfigSubscription) -> Void
    @State private var isTemplateLoaded = false
    @State private var showingDeleteAlert = false
    
    // 基本信息
    @State private var name = ""
    @State private var address = ""
    @State private var enabled = true
    @State private var subUA = "clash"
    @State private var subConvert = false
    @State private var remoteFirst = true
    
    // 过滤相关
    @State private var keywords: [String] = [""]
    @State private var exKeywords: [String] = [""]
    
    // 转换相关
    @State private var convertAddress = "https://api.dler.io/sub"
    @State private var template = "默认（附带用于Clash的AdGuard DNS）"
    @State private var emoji = false
    @State private var udp = false
    @State private var skipCertVerify = false
    @State private var sort = false
    @State private var nodeType = false
    @State private var ruleProvider = false
    @State private var isCustomConvertAddress = false
    @State private var customConvertAddress = ""
    @State private var customTemplateUrl = ""
    
    init(viewModel: ConfigSubscriptionViewModel, subscription: ConfigSubscription? = nil, onSave: @escaping (ConfigSubscription) -> Void) {
        self.viewModel = viewModel
        self.subscription = subscription
        self.onSave = onSave
        
        // 初始化状态
        if let sub = subscription {
            _name = State(initialValue: sub.name)
            _address = State(initialValue: sub.address)
            _enabled = State(initialValue: sub.enabled)
            _subUA = State(initialValue: sub.subUA.lowercased())
            _subConvert = State(initialValue: sub.subConvert)
            _remoteFirst = State(initialValue: sub.remoteFirst ?? true)
            
            // 使用 ViewModel 解析关键词
            let parsedKeywords = viewModel.parseQuotedValues(sub.keyword)
            _keywords = State(initialValue: parsedKeywords.isEmpty ? [] : parsedKeywords)
            
            let parsedExKeywords = viewModel.parseQuotedValues(sub.exKeyword)
            _exKeywords = State(initialValue: parsedExKeywords.isEmpty ? [] : parsedExKeywords)
            
            // 订阅转换相关设置
            if let addr = sub.convertAddress {
                if ConfigSubscription.convertAddressOptions.contains(addr) {
                    _convertAddress = State(initialValue: addr)
                } else {
                    _convertAddress = State(initialValue: "custom")
                    _customConvertAddress = State(initialValue: addr)
                }
            } else {
                _convertAddress = State(initialValue: ConfigSubscription.convertAddressOptions[0])
            }
            _template = State(initialValue: sub.template ?? "")
            _emoji = State(initialValue: sub.subConvert ? sub.emoji ?? false : false)
            _udp = State(initialValue: sub.subConvert ? sub.udp ?? false : false)
            _skipCertVerify = State(initialValue: sub.subConvert ? sub.skipCertVerify ?? false : false)
            _sort = State(initialValue: sub.subConvert ? sub.sort ?? false : false)
            _nodeType = State(initialValue: sub.subConvert ? sub.nodeType ?? false : false)
            _ruleProvider = State(initialValue: sub.subConvert ? sub.ruleProvider ?? false : false)
            _customTemplateUrl = State(initialValue: sub.customTemplateUrl ?? "")
            
            // 检查是否使用自定义转换地址
            if let addr = sub.convertAddress,
               !ConfigSubscription.convertAddressOptions.contains(addr) {
                _isCustomConvertAddress = State(initialValue: true)
                _customConvertAddress = State(initialValue: addr)
            }
        } else {
            // 新建订阅时的默认值
            _name = State(initialValue: "")
            _address = State(initialValue: "")
            _enabled = State(initialValue: true)
            _subUA = State(initialValue: "clash")
            _subConvert = State(initialValue: false)
            _remoteFirst = State(initialValue: true)
            _keywords = State(initialValue: [])
            _exKeywords = State(initialValue: [])
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                BasicInfoSection(
                    server: viewModel.currentServer,
                    name: $name,
                    address: $address,
                    enabled: $enabled,
                    subUA: $subUA,
                    subConvert: $subConvert,
                    emoji: $emoji,
                    udp: $udp,
                    skipCertVerify: $skipCertVerify,
                    sort: $sort,
                    nodeType: $nodeType,
                    ruleProvider: $ruleProvider,
                    remoteFirst: $remoteFirst
                )
                
                if viewModel.currentServer.luciPackage != .mihomoTProxy {
                    FilterSection(
                        keywords: $keywords,
                        exKeywords: $exKeywords
                    )
                    
                    if subConvert {
                        ConvertOptionsSection(
                            convertAddress: $convertAddress,
                            customConvertAddress: $customConvertAddress,
                            template: $template,
                            customTemplateUrl: $customTemplateUrl,
                            emoji: $emoji,
                            udp: $udp,
                            skipCertVerify: $skipCertVerify,
                            sort: $sort,
                            nodeType: $nodeType,
                            ruleProvider: $ruleProvider,
                            viewModel: viewModel
                        )
                    }
                }
                
                // 删除订阅按钮
                if subscription != nil {  // 只在编辑模式显示
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除订阅")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(subscription == nil ? "添加订阅" : "编辑订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveSubscription() }
                        .disabled(name.isEmpty || address.isEmpty)
                }
            }
            .task {
                await viewModel.loadTemplateOptions()
                if template.isEmpty {
                    template = viewModel.templateOptions.first ?? ""
                }
                isTemplateLoaded = true
            }
            .alert("删除订阅", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let sub = subscription {
                        Task {
                            await viewModel.deleteSubscription(sub)
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("确定要删除这个订阅吗？此操作无法撤销。")
            }
        }
    }
    
    private func saveSubscription() {
        let filteredKeywords = keywords.filter { !$0.isEmpty }
        let filteredExKeywords = exKeywords.filter { !$0.isEmpty }
        
        // 处理转换地址
        let finalConvertAddress = convertAddress == "custom" ? customConvertAddress : convertAddress
        
        let sub = ConfigSubscription(
            id: subscription?.id ?? 0,
            name: name,
            address: address,
            enabled: enabled,
            subUA: subUA,
            subConvert: subConvert,
            convertAddress: subConvert ? finalConvertAddress : nil,
            template: subConvert ? template : nil,
            customTemplateUrl: customTemplateUrl,
            emoji: subConvert ? emoji : nil,
            udp: subConvert ? udp : nil,
            skipCertVerify: subConvert ? skipCertVerify : nil,
            sort: subConvert ? sort : nil,
            nodeType: subConvert ? nodeType : nil,
            ruleProvider: subConvert ? ruleProvider : nil,
            keyword: filteredKeywords.isEmpty ? nil : viewModel.formatQuotedValues(filteredKeywords),
            exKeyword: filteredExKeywords.isEmpty ? nil : viewModel.formatQuotedValues(filteredExKeywords),
            remoteFirst: remoteFirst
            
        )
        onSave(sub)
        dismiss()
    }
} 
