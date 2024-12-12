import SwiftUI

struct ConfigEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    let server: ClashServer
    let configName: String
    let isEnabled: Bool
    
    @State private var configContent: String = ""
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingSaveAlert = false
    @State private var isSaving = false
    @State private var showingRestartAlert = false
    @State private var isRestarting = false
    @State private var startupLogs: [String] = []
    
    private func logColor(_ log: String) -> Color {
        if log.contains("警告") {
            return .orange
        } else if log.contains("错误") {
            return .red
        } else if log.contains("成功") {
            return .green
        }
        return .secondary
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    YAMLTextView(
                        text: $configContent,
                        font: .monospacedSystemFont(ofSize: 14, weight: .regular)
                    )
                    .padding(.horizontal, 8)
                }
            }
            .navigationTitle(configName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        showingSaveAlert = true
                    }
                }
            }
        }
        .task {
            await loadConfigContent()
        }
        .alert("保存配置", isPresented: $showingSaveAlert) {
            Button("取消", role: .cancel) { }
            Button("保存", role: .destructive) {
                Task {
                    await saveConfig()
                }
            }
        } message: {
            Text(isEnabled ? 
                 "保存修改后的配置会重启 OpenClash 服务，这会导致当前连接中断。是否继续？" : 
                 "确定要保存修改后的配置吗？这将覆盖原有配置文件。")
        }
        .sheet(isPresented: $isRestarting) {
            LogDisplayView(
                logs: startupLogs,
                title: "正在重启 OpenClash..."
            )
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadConfigContent() async {
        do {
            configContent = try await viewModel.fetchConfigContent(server, configName: configName)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }
    
    private func saveConfig() async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            try await viewModel.saveConfigContent(server, configName: configName, content: configContent)
            
            if isEnabled {
                isRestarting = true
                startupLogs.removeAll()
                
                do {
                    let logStream = try await viewModel.restartOpenClash(server)
                    
                    for try await log in logStream {
                        await MainActor.run {
                            startupLogs.append(log)
                        }
                    }
                    
                    await MainActor.run {
                        isRestarting = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isRestarting = false
                        errorMessage = "重启 OpenClash 失败: \(error.localizedDescription)"
                        showError = true
                    }
                }
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
} 