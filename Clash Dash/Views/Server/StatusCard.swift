import SwiftUI

// 状态卡片组件
struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var monitor: NetworkMonitor
    @AppStorage("showWaveEffect") private var showWaveEffect = true
    @AppStorage("showWaterDropEffect") private var showWaterDropEffect = true
    @AppStorage("showNumberAnimation") private var showNumberAnimation = true
    @AppStorage("showSpeedNumberAnimation") private var showSpeedNumberAnimation = false
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? 
            Color(.systemGray6) : 
            Color(.systemBackground)
    }
    
    private func extractSpeed() -> Double {
        let components = value.split(separator: " ")
        guard components.count == 2,
              let speed = Double(components[0]),
              let unit = components.last else {
            return 0
        }
        
        switch unit {
        case "MB/s":
            return speed * 1_000_000
        case "KB/s":
            return speed * 1_000
        case "B/s":
            return speed
        default:
            return 0
        }
    }
    
    // 判断是否是实时速度卡片
    private var isSpeedCard: Bool {
        return (title == "下载" || title == "上传") && !title.contains("总量")
    }
    
    // 判断是否应该使用动画效果
    private var shouldUseAnimation: Bool {
        if isSpeedCard {
            return showNumberAnimation && showSpeedNumberAnimation
        } else {
            return showNumberAnimation
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 使用条件判断决定是否使用动画数字视图
            if shouldUseAnimation {
                AnimatedNumberView(value: value, color: .primary)
                    .minimumScaleFactor(0.5)
            } else {
                Text(value)
                    .font(.title2)
                    .bold()
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            ZStack {
                cardBackgroundColor
                if showWaveEffect && isSpeedCard {
                    WaveBackground(
                        color: color,
                        speed: extractSpeed(),
                        monitor: monitor,
                        isDownload: title == "下载"
                    )
                }
                if showWaterDropEffect && title.contains("总量") {
                    WaterDropEffect(
                        color: color,
                        monitor: monitor,
                        isUpload: title.contains("上传")
                    )
                }
            }
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
} 