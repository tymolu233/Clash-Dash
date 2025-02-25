import SwiftUI

/// 数字动画视图，用于实现数字变动的平滑过渡效果
/// 类似于 Apple Health 应用中的数字变动效果
struct AnimatedNumberView: View {
    let value: String
    let color: Color
    let font: Font
    let fontWeight: Font.Weight
    
    @State private var animatedValue: String
    @State private var previousValue: String
    @State private var isAnimating: Bool = false
    
    init(value: String, color: Color, font: Font = .title2, fontWeight: Font.Weight = .bold) {
        self.value = value
        self.color = color
        self.font = font
        self.fontWeight = fontWeight
        self._animatedValue = State(initialValue: value)
        self._previousValue = State(initialValue: value)
    }
    
    private func extractNumericPart(_ value: String) -> (String, String?) {
        // 处理特殊情况：纯数字（如活动连接数）
        if let _ = Int(value) {
            return (value, nil)
        }
        
        // 处理 N/A 或其他非数字情况
        if !value.contains(" ") || value == "N/A" {
            return (value, nil)
        }
        
        // 分离数字部分和单位部分
        let components = value.split(separator: " ")
        if components.count > 1 {
            return (String(components[0]), String(components[1...].joined(separator: " ")))
        }
        return (value, nil)
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            let (numericPart, unitPart) = extractNumericPart(animatedValue)
            
            // 数字部分使用动画效果
            Text(numericPart)
                .font(font)
                .fontWeight(fontWeight)
                .foregroundColor(color)
                .contentTransition(.numericText())
                .transaction { transaction in
                    transaction.animation = .spring(
                        response: 0.4,
                        dampingFraction: 0.8
                    )
                }
            
            // 单位部分不使用动画
            if let unit = unitPart {
                Text(" \(unit)")
                    .font(font)
                    .fontWeight(fontWeight)
                    .foregroundColor(color)
            }
        }
        .onChange(of: value) { newValue in
            // 当值发生变化时，更新动画值
            if newValue != previousValue {
                previousValue = animatedValue
                animatedValue = newValue
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AnimatedNumberView(value: "123.45 MB", color: .blue)
        AnimatedNumberView(value: "67.89 GB", color: .green)
        AnimatedNumberView(value: "42", color: .orange)
        AnimatedNumberView(value: "0 B", color: .red)
        AnimatedNumberView(value: "N/A", color: .gray)
    }
    .padding()
} 