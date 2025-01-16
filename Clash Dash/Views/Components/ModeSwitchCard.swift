import SwiftUI

struct ModeSwitchCard: View {
    let server: ClashServer
    @State private var selectedMode = "rule"
    @State private var showingModeChangeSuccess = false
    @State private var lastChangedMode = ""
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("modeSwitchCardStyle") private var cardStyle = ModeSwitchCardStyle.classic
    
    
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? 
            Color(.systemGray6).opacity(0.8) : 
            Color(.systemBackground).opacity(0.9)
    }
    
    private let modes = [
        ("rule", "规则模式", "list.bullet.rectangle"),
        ("global", "全局模式", "globe"),
        ("direct", "直连模式", "arrow.up.right")
    ]
    
    private var modernCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ForEach(modes, id: \.0) { mode in
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            selectedMode = mode.0
                            HapticManager.shared.impact(.light)
                        }
                        updateMode(mode.0)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.2)
                                .font(.system(size: 18))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(selectedMode == mode.0 ? Color.accentColor.gradient : Color.gray.gradient)
                            Text(mode.1)
                                .font(.system(size: 12))
                                .foregroundStyle(selectedMode == mode.0 ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedMode == mode.0 ? 
                                    Color.accentColor.opacity(0.1) : 
                                    Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedMode == mode.0 ? 
                                        Color.accentColor.opacity(0.2) : 
                                        Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .shadow(
                    color: colorScheme == .dark ? 
                        Color.black.opacity(0.2) : 
                        Color.black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
    
    private var classicCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(modes, id: \.0) { mode in
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            selectedMode = mode.0
                            HapticManager.shared.impact(.light)
                        }
                        updateMode(mode.0)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.2)
                                .font(.system(size: 12, weight: .medium))
                            Text(mode.1)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedMode == mode.0 ? Color.accentColor : cardBackgroundColor)
                                .shadow(color: selectedMode == mode.0 ? Color.accentColor.opacity(0.2) : Color.clear, radius: 4, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    selectedMode == mode.0 ? 
                                        Color.accentColor : 
                                        Color.gray.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                        .foregroundColor(selectedMode == mode.0 ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .shadow(
                    color: colorScheme == .dark ? 
                        Color.black.opacity(0.2) : 
                        Color.black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
    
    var body: some View {
        Group {
            switch cardStyle {
            case .classic:
                classicCardContent
            case .modern:
                modernCardContent
            }
        }
        .overlay(
            Group {
                if showingModeChangeSuccess {
                    VStack {
                        Text("已切换到\(getModeDescription(lastChangedMode))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.8))
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }
            }
        )
        .onAppear {
            Task {
                await fetchCurrentMode()
            }
        }
    }
    
    private func getModeDescription(_ mode: String) -> String {
        modes.first { $0.0 == mode }?.1 ?? mode
    }
    
    private func fetchCurrentMode() async {
        do {
            let scheme = server.clashUseSSL ? "https" : "http"
            let url = URL(string: "\(scheme)://\(server.url):\(server.port)/configs")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let mode = json["mode"] as? String {
                await MainActor.run {
                    selectedMode = mode.lowercased()
                }
            }
        } catch {
            print("Error fetching mode: \(error)")
        }
    }
    
    private func updateMode(_ mode: String) {
        Task {
            do {
                let scheme = server.clashUseSSL ? "https" : "http"
                let url = URL(string: "\(scheme)://\(server.url):\(server.port)/configs")!
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["mode": mode])
                
                let (_, response) = try await URLSession.shared.data(for: request)
                if (response as? HTTPURLResponse)?.statusCode == 204 {
                    await MainActor.run {
                        lastChangedMode = mode
                        // 保存当前模式到 UserDefaults
                        UserDefaults.standard.set(mode, forKey: "currentMode")
                        // 发送通知以刷新代理组显示
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshProxyGroups"), object: nil)
                        
                        withAnimation {
                            showingModeChangeSuccess = true
                        }
                        // 2秒后隐藏提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingModeChangeSuccess = false
                            }
                        }
                    }
                }
            } catch {
                print("Error updating mode: \(error)")
            }
        }
    }
} 