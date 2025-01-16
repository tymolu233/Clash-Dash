import SwiftUI
import Darwin

// 波浪背景组件
struct WaveBackground: View {
    let color: Color
    let speed: Double
    @ObservedObject var monitor: NetworkMonitor
    let isDownload: Bool
    @State private var phase: CGFloat = 0
    @State private var displayLink: Timer?
    @State private var currentSpeed: CGFloat = 0.01 // 当前实际移动速度
    private let waveWidth: CGFloat = 4 * .pi
    private let fixedAmplitude: CGFloat = 0.2 // 固定的波浪振幅
    private let accelerationFactor: CGFloat = 0.01 // 加速因子
    private let decelerationFactor: CGFloat = 0.01    // 减速因子
    
    var body: some View {
        Canvas { context, size in
            let baseHeight = size.height * 0.7
            
            // 绘制波浪
            var path = Path()
            path.move(to: CGPoint(x: size.width, y: size.height))
            
            let points = 200
            for i in 0...points {
                let x = size.width - (CGFloat(i) / CGFloat(points)) * size.width
                
                // 计算波形，使用固定振幅
                let normalizedX = (CGFloat(i) / CGFloat(points)) * waveWidth
                let wavePhase = normalizedX - phase
                let baseWave = Darwin.sin(wavePhase)
                let waveHeight = baseWave * size.height * 0.4 * fixedAmplitude
                
                let y = baseHeight + waveHeight
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
            
            context.fill(path, with: .color(color.opacity(0.3)))
        }
        .onAppear {
            // 创建动画定时器
            displayLink = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
                // 计算目标速度
                let targetSpeed = calculateTargetSpeed()
                
                // 平滑加速或减速
                if currentSpeed < targetSpeed {
                    // 加速
                    currentSpeed += (targetSpeed - currentSpeed) * accelerationFactor
                } else if currentSpeed > targetSpeed {
                    // 减速
                    currentSpeed -= (currentSpeed - targetSpeed) * decelerationFactor
                }
                
                // 更新相位
                phase += currentSpeed
                if phase >= waveWidth {
                    phase = 0
                }
            }
        }
        .onDisappear {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
    
    private func calculateTargetSpeed() -> CGFloat {
        let currentSpeed = isDownload ? monitor.downloadSpeed : monitor.uploadSpeed
        let components = currentSpeed.split(separator: " ")
        guard components.count == 2,
              let value = Double(components[0]) else {
            return 0.01
        }
        
        let bytesPerSecond: Double
        switch components[1] {
        case "MB/s":
            bytesPerSecond = value * 1_000_000
        case "KB/s":
            bytesPerSecond = value * 1_000
        case "B/s":
            bytesPerSecond = value
        default:
            bytesPerSecond = 0
        }
        
        let baseSpeed = 2_000_000.0 // 2MB/s作为基准速度
        let speedRatio = bytesPerSecond / baseSpeed
        
        // 使用线性映射来控制移动速度
        let minSpeed: CGFloat = 0.01
        let maxSpeed: CGFloat = 0.1
        
        // 使用对数函数使速度变化更加平滑
        let normalizedSpeed = CGFloat(log(speedRatio + 1) / log(2))
        return minSpeed + (maxSpeed - minSpeed) * min(normalizedSpeed, 1.0)
    }
} 