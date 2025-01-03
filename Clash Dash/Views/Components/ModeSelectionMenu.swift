import SwiftUI

struct ModeSelectionMenu: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    let server: ClashServer
    var onModeChange: (String) -> Void
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        Menu {
            Button {
                impactFeedback.impactOccurred()
                settingsViewModel.updateConfig("mode", value: "rule", server: server) { 
                    settingsViewModel.mode = "rule"
                    onModeChange("rule")
                }
            } label: {
                Label("规则模式", systemImage: settingsViewModel.mode == "rule" ? "checkmark" : "circle")
            }
            
            Button {
                impactFeedback.impactOccurred()
                settingsViewModel.updateConfig("mode", value: "direct", server: server) { 
                    settingsViewModel.mode = "direct"
                    onModeChange("direct")
                }
            } label: {
                Label("直连模式", systemImage: settingsViewModel.mode == "direct" ? "checkmark" : "circle")
            }
            
            Button {
                impactFeedback.impactOccurred()
                settingsViewModel.updateConfig("mode", value: "global", server: server) { 
                    settingsViewModel.mode = "global"
                    onModeChange("global")
                }
            } label: {
                Label("全局模式", systemImage: settingsViewModel.mode == "global" ? "checkmark" : "circle")
            }
        } label: {
            Label(ModeUtils.getModeText(settingsViewModel.mode), 
                  systemImage: ModeUtils.getModeIcon(settingsViewModel.mode))
        }
        .onAppear {
            settingsViewModel.getCurrentMode(server: server) { currentMode in
                settingsViewModel.mode = currentMode
            }
        }
    }
} 