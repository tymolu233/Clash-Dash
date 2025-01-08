import SwiftUI

struct OpenClashRulesHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("功能说明")
                        .font(.headline)
                    Text("附加规则启用后将把自定义规则增加到配置文件")
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("使用方法")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 点击标题旁的开关来启用或关闭该功能")
                        Text("• 点击 + 号可以新增规则")
                        Text("• 左滑规则可以：")
                            .padding(.bottom, 4)
                        Group {
                            Text("  - 启用/禁用单条规则")
                            Text("  - 编辑规则")
                            Text("  - 删除规则")
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("注意事项")
                        .font(.headline)
                    Text("在此页面做出更改后可能需要重启服务才能生效")
                        .foregroundColor(.orange)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("帮助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成", action: { dismiss() })
                }
            }
        }
    }
} 