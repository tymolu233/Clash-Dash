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
    @State private var visibleRange: Range<String.Index>?
    
    // 每次显示的行数
    private let visibleLineCount = 100
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            let lines = configContent.components(separatedBy: .newlines)
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal)
                                    .padding(.vertical, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(index % 2 == 0 ? Color.clear : Color(.systemGray6))
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle(configName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: copyToClipboard) {
                            Label("复制全部", systemImage: "doc.on.doc")
                        }
                        
                        Button(action: shareConfig) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await loadConfigContent()
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
    
    private func copyToClipboard() {
        UIPasteboard.general.string = configContent
    }
    
    private func shareConfig() {
        let activityVC = UIActivityViewController(
            activityItems: [configContent],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            activityVC.popoverPresentationController?.permittedArrowDirections = []
            rootVC.present(activityVC, animated: true)
        }
    }
} 