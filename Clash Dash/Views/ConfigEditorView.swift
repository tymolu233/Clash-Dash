import SwiftUI

struct ConfigEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    let server: ClashServer
    let configName: String
    
    @State private var configContent: String = ""
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingSaveAlert = false
    @State private var isSaving = false
    
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
            Text("确定要保存修改后的配置吗？这将覆盖原有配置文件。")
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
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
} 