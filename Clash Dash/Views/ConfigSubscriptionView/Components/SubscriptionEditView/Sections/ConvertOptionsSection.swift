import SwiftUI

struct ConvertOptionsSection: View {
    @Binding var convertAddress: String
    @Binding var customConvertAddress: String
    @Binding var template: String
    @Binding var emoji: Bool
    @Binding var udp: Bool
    @Binding var skipCertVerify: Bool
    @Binding var sort: Bool
    @Binding var nodeType: Bool
    @Binding var ruleProvider: Bool
    @Binding var customParams: [String]
    @ObservedObject var viewModel: ConfigSubscriptionViewModel
    
    var body: some View {
        Section {
            // 转换服务选择
            Picker("转换服务", selection: $convertAddress) {
                ForEach(ConfigSubscription.convertAddressOptions, id: \.self) { address in
                    Text(address).tag(address)
                }
                Text("自定义").tag("custom")
            }
            .onChange(of: convertAddress) { newValue in
                // 确保选择的值在有效选项中
                if !ConfigSubscription.convertAddressOptions.contains(newValue) && newValue != "custom" {
                    convertAddress = ConfigSubscription.convertAddressOptions[0]
                }
            }
            
            if convertAddress == "custom" {
                TextField("自定义转换服务地址", text: $customConvertAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            
            // 转换模板选择
            Picker("转换模板", selection: $template) {
                ForEach(viewModel.templateOptions, id: \.self) { template in
                    Text(template).tag(template)
                }
            }
            .onChange(of: template) { newValue in
                // 确保选择的值在有效选项中
                if !viewModel.templateOptions.contains(newValue) {
                    template = viewModel.templateOptions[0]
                }
            }
            
            // 转换选项开关
            Toggle("添加 Emoji", isOn: $emoji)
            Toggle("UDP 支持", isOn: $udp)
            Toggle("跳过证书验证", isOn: $skipCertVerify)
            Toggle("节点排序", isOn: $sort)
            Toggle("插入节点类型", isOn: $nodeType)
            Toggle("使用规则集", isOn: $ruleProvider)
            
            // 自定义参数
            ForEach(customParams.indices, id: \.self) { index in
                HStack {
                    TextField("自定义参数", text: $customParams[index])
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                    
                    Button(action: {
                        customParams.remove(at: index)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            
            Button(action: {
                customParams.append("")
            }) {
                Label("添加自定义参数", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("转换选项")
        } footer: {
            VStack(alignment: .leading) {
                Text("自定义参数示例：rename=\\s+([2-9])[xX]@ (高倍率:$1)")
                    .font(.system(.caption, design: .monospaced))
                Text("在线订阅转换存在隐私泄露风险")
                    .foregroundColor(.red)
            }
        }
    }
} 