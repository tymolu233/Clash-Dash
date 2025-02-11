import SwiftUI

// 水滴效果组件
struct WaterDrop: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    var speed: Double
    var scale: CGFloat
    var isGrowing: Bool
    var widthParameter: CGFloat  // a parameter
    var heightParameter: CGFloat // b parameter
    var accumulatedData: Int  // 累积的数据量
    var shouldFall: Bool  // 是否应该下落
    var acceleration: Double = 0  // 添加加速度属性
}

struct TeardropShape: Shape {
    let widthParameter: CGFloat  // a parameter
    let heightParameter: CGFloat // b parameter
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let centerX = rect.midX
        let centerY = rect.midY
        
        // 使用 1000 个点来绘制曲线
        let points = 1000
        let scale = min(width, height) / 5.2  // 缩放因子，基于 y 轴范围 (-5.2, 0.2)
        
        // 计算第一个点
        let firstT = 0.0
        let firstX = widthParameter * (1 - sin(firstT)) * cos(firstT)
        let firstY = heightParameter * (sin(firstT) - 1)
        let scaledFirstX = centerX + firstX * scale
        let scaledFirstY = centerY - firstY * scale  // 翻转 Y 坐标
        
        path.move(to: CGPoint(x: scaledFirstX, y: scaledFirstY))
        
        // 使用参数方程绘制曲线
        for i in 1...points {
            let t = Double(i) * 2 * .pi / Double(points)
            
            // Piriform of Longchamps 方程
            let x = widthParameter * (1 - sin(t)) * cos(t)
            let y = heightParameter * (sin(t) - 1)
            
            // 缩放和平移坐标以适应视图，注意 y 坐标取反
            let scaledX = centerX + x * scale
            let scaledY = centerY - y * scale  // 翻转 Y 坐标
            
            path.addLine(to: CGPoint(x: scaledX, y: scaledY))
        }
        
        path.closeSubpath()
        return path
    }
}

struct WaterSplash: Identifiable {
    let id = UUID()
    var position: CGPoint
    var width: CGFloat
    var height: CGFloat
    var opacity: Double
    var createdAt: Date
    var delayStart: Date  // 添加延迟开始时间
}

struct WaterDropEffect: View {
    let color: Color
    @ObservedObject var monitor: NetworkMonitor
    let isUpload: Bool  // 是否是上传总量
    @State private var drops: [WaterDrop] = []
    @State private var timer: Timer?
    @State private var lastValue: Int = 0  // 使用原始数据
    @State private var timeWindowStart: Date = Date()  // 时间窗口开始时间
    @State private var currentDifference: Int = 0  // 当前时间窗口内的累积差值
    @State private var dropGenerationProgress: CGFloat = 0  // 水滴生成进度
    @State private var splashes: [WaterSplash] = []
    private let splashDuration: TimeInterval = 0.8  // 水花效果持续时间
    
    private let timeWindowDuration: TimeInterval = 2.0  // 2秒时间窗口
    private let dropGenerationDuration: TimeInterval = 2.0  // 水滴生成时间
    private let minDropSize: CGFloat = 2  // 最小水滴大小
    private let maxDropSize: CGFloat = 20  // 最大水滴大小
    private let maxDataThreshold: Int = 10 * 1024 * 1024  // 10MB 阈值
    private let animationInterval: TimeInterval = 0.005  // 动画更新间隔
    private let scaleStepFactor: CGFloat = 0.02  // 缩放变化步长
    private let sizeStepFactor: CGFloat = 0.03  // 大小变化步长
    
    private func calculateDropParameters(accumulatedData: Int) -> (CGFloat, CGFloat, CGFloat) {
        // 修改进度计算方式，使其更容易达到最大值
        let cappedData = min(accumulatedData, 10 * 1024 * 1024)  // 限制在10MB
        let mbAccumulated = Double(cappedData) / Double(1024 * 1024)
        var progress: CGFloat
        if mbAccumulated >= 10 {
            progress = 1.0  // 达到10MB时直接使用最大值
        } else {
            // 使用更直接的比例计算，让大小增长更明显
            let baseProgress = CGFloat(mbAccumulated / 10.0)  // 线性增长
            // 使用 pow 函数让初期增长更快
            progress = CGFloat(pow(Double(baseProgress), 0.5))
        }
        
        let size = minDropSize + (maxDropSize - minDropSize) * progress
        
        // 形状参数使用固定的最小和最大值
        let minWidthParameter: CGFloat = 1.0
        let maxWidthParameter: CGFloat = 1.5
        let minHeightParameter: CGFloat = 2.5
        let maxHeightParameter: CGFloat = 3.5
        
        // 根据进度计算形状参数
        let widthParameter = minWidthParameter + (maxWidthParameter - minWidthParameter) * progress
        let heightParameter = minHeightParameter + (maxHeightParameter - minHeightParameter) * progress
        
        return (size, widthParameter, heightParameter)
    }
    
    private func calculateFloatOffset(size: CGFloat, time: TimeInterval) -> CGFloat {
        // 修改浮动幅度计算，使其更线性
        let progress = (size - minDropSize) / (maxDropSize - minDropSize)
        let maxFloat: CGFloat = 6.0  // 进一步增大最大浮动幅度
        let amplitude = maxFloat * progress
        return sin(time * 1.5) * amplitude
    }
    
    private func createDrop(withInitialData data: Int = 0) -> WaterDrop {
        let randomX = CGFloat.random(in: 10...90)
        let (targetSize, targetWidth, targetHeight) = calculateDropParameters(accumulatedData: data)
        
        // 如果初始数据量大，直接创建对应大小的水滴
        let initialSize = data >= maxDataThreshold ? targetSize : minDropSize
        let initialWidth = data >= maxDataThreshold ? targetWidth : 1.0
        let initialHeight = data >= maxDataThreshold ? targetHeight : 2.5
        
        return WaterDrop(
            position: CGPoint(x: randomX, y: 0),
            size: initialSize,
            opacity: 0.8,
            speed: Double.random(in: 80...160),
            scale: 1.0,
            isGrowing: data < maxDataThreshold,  // 只有小水滴需要生长
            widthParameter: initialWidth,
            heightParameter: initialHeight,
            accumulatedData: data,
            shouldFall: data >= maxDataThreshold,  // 大水滴直接开始下落
            acceleration: 0.5
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 水面效果
                ForEach(splashes) { splash in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: splash.width, height: splash.height)
                        .position(x: splash.position.x, y: splash.position.y)
                        .opacity(splash.opacity)
                }
                
                // 水滴连接线
                ForEach(drops) { drop in
                    if !drop.shouldFall && !drop.isGrowing {
                        Path { path in
                            let startY: CGFloat = 0
                            let endY = drop.position.y + drop.size * 0.3  // 直接连接到水滴的中心位置
                            path.move(to: CGPoint(x: drop.position.x, y: startY))
                            path.addLine(to: CGPoint(x: drop.position.x, y: endY))
                        }
                        .stroke(color.opacity(0.5), lineWidth: max(0.2, 1.5 * (1.0 - abs(drop.position.y) / 6.0)))  // 根据浮动位置动态调整线宽
                    }
                }
                
                // 水滴
                ForEach(drops) { drop in
                    TeardropShape(widthParameter: drop.widthParameter, heightParameter: drop.heightParameter)
                        .fill(color)
                        .frame(width: drop.size, height: drop.size * 1.3)
                        .scaleEffect(drop.scale)
                        .position(drop.position)
                        .opacity(drop.opacity)
                }
            }
            .onAppear {
                // 初始化时记录当前值，但不计入差值计算
                lastValue = isUpload ? monitor.rawTotalUpload : monitor.rawTotalDownload
                timeWindowStart = Date()
                currentDifference = 0  // 确保初始差值为0
                
                // 获取视图尺寸
                let viewHeight = geometry.size.height
                let viewWidth = geometry.size.width
                
                timer = Timer.scheduledTimer(withTimeInterval: animationInterval, repeats: true) { _ in
                    withAnimation(.linear(duration: animationInterval)) {
                        let currentValue = isUpload ? monitor.rawTotalUpload : monitor.rawTotalDownload
                        let difference = currentValue - lastValue
                        
                        if difference > 0 {
                            // 只有在非初始状态下才累积差值
                            if lastValue > 0 {
                                currentDifference += difference
                            }
                            
                            // 检查时间窗口
                            let now = Date()
                            let elapsedTime = now.timeIntervalSince(timeWindowStart)
                            
                            // 水滴生成和更新逻辑
                            if drops.isEmpty {
                                // 如果累积数据超过1MB，直接创建对应大小的水滴
                                if currentDifference >= 1024 * 1024 {
                                    let newDrop = createDrop(withInitialData: currentDifference)
                                    drops.append(newDrop)
                                    dropGenerationProgress = 0
                                } else {
                                    // 正常的水滴生成进度
                                    dropGenerationProgress = min(elapsedTime / dropGenerationDuration, 1.0)
                                    if dropGenerationProgress >= 1.0 {
                                        let newDrop = createDrop()
                                        drops.append(newDrop)
                                        dropGenerationProgress = 0
                                    }
                                }
                            }
                            
                            // 每个时间窗口结束时更新水滴
                            if elapsedTime >= timeWindowDuration {
                                if let lastIndex = drops.indices.last {
                                    // 更新现有水滴的累积数据
                                    let oldAccumulated = drops[lastIndex].accumulatedData
                                    let newAccumulated = oldAccumulated + currentDifference
                                    drops[lastIndex].accumulatedData = newAccumulated
                                    
                                    // 计算目标参数
                                    let (targetSize, targetWidth, targetHeight) = calculateDropParameters(accumulatedData: newAccumulated)
                                    
                                    // 平滑地更新参数
                                    let currentSize = drops[lastIndex].size
                                    let currentWidth = drops[lastIndex].widthParameter
                                    let currentHeight = drops[lastIndex].heightParameter
                                    
                                    drops[lastIndex].size = currentSize + (targetSize - currentSize) * sizeStepFactor
                                    drops[lastIndex].widthParameter = currentWidth + (targetWidth - currentWidth) * sizeStepFactor
                                    drops[lastIndex].heightParameter = currentHeight + (targetHeight - currentHeight) * sizeStepFactor
                                    
                                    // 只有累积到10MB并且不在生长状态时才开始下落
                                    if newAccumulated >= maxDataThreshold && !drops[lastIndex].isGrowing {
                                        drops[lastIndex].shouldFall = true
                                    }
                                }
                                
                                // 重置时间窗口和当前差值
                                timeWindowStart = now
                                currentDifference = 0
                            }
                        }
                        
                        // 更新现有水滴
                        for i in drops.indices {
                            var drop = drops[i]
                            
                            if drop.isGrowing {
                                // 计算目标大小
                                let (targetSize, _, _) = calculateDropParameters(accumulatedData: drop.accumulatedData)
                                
                                // 平滑地更新大小
                                let currentSize = drop.size
                                let sizeProgress = (currentSize - minDropSize) / (targetSize - minDropSize)
                                
                                // 使用 easeOut 效果使初始增长更快
                                let easedProgress = 1 - pow(1 - sizeProgress, 3)
                                
                                // 更新大小
                                drop.size = currentSize + (targetSize - currentSize) * sizeStepFactor
                                
                                // 同时更新形状参数
                                let shapeProgress = easedProgress
                                let targetWidthParam = 1.0 + shapeProgress * 0.5
                                let targetHeightParam = 2.5 + shapeProgress * 1.0
                                
                                drop.widthParameter = drop.widthParameter + (targetWidthParam - drop.widthParameter) * sizeStepFactor
                                drop.heightParameter = drop.heightParameter + (targetHeightParam - drop.heightParameter) * sizeStepFactor
                                
                                // 当接近目标大小时结束生长状态
                                if abs(drop.size - targetSize) < 0.1 {
                                    drop.isGrowing = false
                                }
                            } else if drop.shouldFall {
                                drop.speed += drop.acceleration  // 应用加速度
                                drop.position.y += drop.speed/120
                                
                                // 下落过程中的变形效果
                                let fallProgress = min(drop.position.y / (viewHeight * 0.7), 1.0)
                                let maxWidthIncrease: CGFloat = 0.02  // 最大宽度增加1%
                                let maxHeightDecrease: CGFloat = 0.02  // 最大高度减少1%
                                
                                // 使用 easeInOut 效果使变形更自然
                                let easedProgress = 1 - pow(1 - fallProgress, 2)
                                
                                // 应用变形
                                drop.widthParameter = 1.5 * (1 + maxWidthIncrease * easedProgress)
                                drop.heightParameter = 3.5 * (1 - maxHeightDecrease * easedProgress)
                                
                                // 接近底部时逐渐降低透明度和变形
                                if drop.position.y >= viewHeight - drop.size * 2 {
                                    let distanceToBottom: CGFloat = viewHeight - drop.position.y
                                    let squashProgress = 1.0 - (distanceToBottom / (drop.size * 2))  // 0到1的进度
                                    
                                    // 逐渐增加宽度和减小高度
                                    drop.widthParameter = drop.widthParameter * (1 + squashProgress * 0.8)
                                    drop.heightParameter = drop.heightParameter * (1 - squashProgress * 0.9)
                                    
                                    // 同时降低透明度
                                    drop.opacity = Double(max(0, distanceToBottom / (drop.size * 3)))
                                    
                                    // 在这里创建和更新水面效果
                                    if splashes.isEmpty {
                                        let splash = WaterSplash(
                                            position: CGPoint(x: viewWidth/2, y: viewHeight),
                                            width: viewWidth,
                                            height: 0,
                                            opacity: 0.3,
                                            createdAt: Date(),
                                            delayStart: Date().addingTimeInterval(0.05)  // 添加0.05秒延迟
                                        )
                                        splashes.append(splash)
                                    }
                                }
                            } else {
                                // 水滴悬停，浮动幅度与大小相关
                                let floatOffset = calculateFloatOffset(size: drop.size, time: Date().timeIntervalSince1970)
                                drop.position.y = floatOffset
                            }
                            
                            // 检查是否碰到底部
                            if drop.position.y >= viewHeight {
                                drops.remove(at: i)
                                break
                            }
                            
                            drops[i] = drop
                        }
                        
                        // 清理超出范围的水滴
                        drops.removeAll { $0.position.y > viewHeight }
                        
                        // 更新水面效果
                        for i in splashes.indices {
                            let now = Date()
//                            let timeSinceCreation = now.timeIntervalSince(splashes[i].createdAt)
                            
                            // 检查是否已经到达延迟开始时间
                            if now < splashes[i].delayStart {
                                continue  // 如果还没到延迟时间，保持初始状态
                            }
                            
                            let timeSinceDelay = now.timeIntervalSince(splashes[i].delayStart)
                            let progress = timeSinceDelay / splashDuration
                            
                            if progress >= 1.0 {
                                splashes.remove(at: i)
                                break
                            }
                            
                            // 水面高度和透明度动画
                            let normalizedProgress = progress * 2 * .pi
                            let dampingFactor = 1 - progress
                            
                            let oscillation = sin(normalizedProgress * 3) * dampingFactor
                            let baseHeight = 1 - pow(progress - 0.5, 2) * 4
                            
                            let finalHeight = max(0, baseHeight + oscillation * 0.3)
                            splashes[i].height = 8 * finalHeight
                            splashes[i].opacity = max(0, 1 - progress * 1.2)
                        }
                        
                        lastValue = currentValue
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }
} 
