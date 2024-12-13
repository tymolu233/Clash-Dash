import SwiftUI

struct LogDisplayView: View {
    let logs: [String]
    let title: String
    
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
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 8)
            
            Text(title)
                .font(.headline)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(logs.reversed().enumerated()), id: \.offset) { index, log in
                            Text(log)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(logColor(log))
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .onChange(of: logs.count) { _ in
                        withAnimation {
                            proxy.scrollTo(0, anchor: .top)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
} 