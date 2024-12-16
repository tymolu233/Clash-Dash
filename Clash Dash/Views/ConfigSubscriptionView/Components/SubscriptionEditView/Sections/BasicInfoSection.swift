import SwiftUI

struct BasicInfoSection: View {
    @Binding var name: String
    @Binding var address: String
    @Binding var enabled: Bool
    @Binding var subUA: String
    @Binding var subConvert: Bool
    
    @Binding var emoji: Bool
    @Binding var udp: Bool
    @Binding var skipCertVerify: Bool
    @Binding var sort: Bool
    @Binding var nodeType: Bool
    @Binding var ruleProvider: Bool
    @Binding var customParams: [String]
    
    var body: some View {
        Section {
            TextField("名称", text: $name)
            TextField("订阅地址", text: $address)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            Toggle("启用", isOn: $enabled)
            
            Picker("User-Agent", selection: $subUA) {
                ForEach(ConfigSubscription.userAgentOptions, id: \.value) { option in
                    Text(option.text).tag(option.value)
                }
            }
            .onAppear {
                subUA = subUA.replacingOccurrences(of: "'", with: "").lowercased()
            }
            .onChange(of: subUA) { newValue in
                subUA = newValue.replacingOccurrences(of: "'", with: "").lowercased()
            }
            
            Toggle("订阅转换", isOn: $subConvert)
                .onChange(of: subConvert) { newValue in
                    if !newValue {
                        emoji = false
                        udp = false
                        skipCertVerify = false
                        sort = false
                        nodeType = false
                        ruleProvider = false
                        customParams = []
                    }
                }
        } header: {
            Text("基本信息")
        }
    }
}