import SwiftUI

struct FilterSection: View {
    @Binding var keywords: [String]
    @Binding var exKeywords: [String]
    
    var body: some View {
        Section {
            // 包含关键词
            if !keywords.isEmpty {
                ForEach(keywords.indices, id: \.self) { index in
                    HStack {
                        TextField("包含关键词", text: $keywords[index])
                            .textInputAutocapitalization(.never)
                        
                        Button(action: {
                            keywords.remove(at: index)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Button(action: {
                keywords.append("")
            }) {
                Label("添加筛选节点关键词", systemImage: "plus.circle.fill")
            }
            
            // 排除关键词
            if !exKeywords.isEmpty {
                ForEach(exKeywords.indices, id: \.self) { index in
                    HStack {
                        TextField("排除关键词", text: $exKeywords[index])
                            .textInputAutocapitalization(.never)
                        
                        Button(action: {
                            exKeywords.remove(at: index)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Button(action: {
                exKeywords.append("")
            }) {
                Label("添加排除节点关键词", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("节点过滤")
        }
    }
} 