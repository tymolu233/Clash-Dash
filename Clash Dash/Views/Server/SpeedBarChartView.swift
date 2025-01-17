import SwiftUI
import Charts

struct SpeedBarChartView: View {
    let speedHistory: [SpeedRecord]
    
    // 固定显示最近的30条数据，并反转顺序
    private var displayData: [SpeedRecord] {
        Array(speedHistory.suffix(30)).reversed()
    }
    
    // 使用索引作为X轴位置，这样新数据总是在右边
    private var indexedData: [(index: Int, record: SpeedRecord)] {
        displayData.enumerated().map { (index, record) in
            (29 - index, record)  // 反转索引，使新数据从右边开始
        }
    }
    
    private var maxValue: Double {
        let maxUpload = speedHistory.map { $0.upload }.max() ?? 0
        let maxDownload = speedHistory.map { $0.download }.max() ?? 0
        let currentMax = max(maxUpload, maxDownload)
        
        if currentMax < 2_000 {
            return 2_000
        }
        
        let magnitude = pow(10, floor(log10(currentMax)))
        let normalized = currentMax / magnitude
        
        let scale: Double
        if normalized <= 1 {
            scale = 1
        } else if normalized <= 2 {
            scale = 2
        } else if normalized <= 5 {
            scale = 5
        } else {
            scale = 10
        }
        
        return magnitude * scale * 1.2
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        if speed >= 1_000_000 {
            return String(format: "%.1f MB/s", speed / 1_000_000)
        } else if speed >= 1_000 {
            return String(format: "%.1f KB/s", speed / 1_000)
        } else {
            return String(format: "%.0f B/s", speed)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                Text("速率图表")
                    .font(.headline)
            }
            
            Chart {
                // 添加预设的网格线和标签
                ForEach(Array(stride(from: 0, to: maxValue, by: maxValue/4)), id: \.self) { value in
                    RuleMark(
                        y: .value("Speed", value)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.gray.opacity(0.1))
                }
                
                ForEach(indexedData, id: \.index) { item in
                    // 上传速度柱子（上半部分）
                    BarMark(
                        x: .value("Index", item.index),
                        yStart: .value("Speed", item.record.download),
                        yEnd: .value("Speed", item.record.download + item.record.upload),
                        width: .fixed(6)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.green.opacity(0.7), .green.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // 下载速度柱子（下半部分）
                    BarMark(
                        x: .value("Index", item.index),
                        yStart: .value("Speed", 0),
                        yEnd: .value("Speed", item.record.download),
                        width: .fixed(6)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.blue.opacity(0.7), .blue.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(preset: .extended, position: .leading) { value in
                    if let speed = value.as(Double.self) {
                        AxisGridLine()
                        AxisValueLabel(horizontalSpacing: 0) {
                            Text(formatSpeed(speed))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...maxValue)
            .chartXAxis {
                // 隐藏X轴标签，因为索引数字对用户没有意义
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(.clear)
                    AxisTick()
                        .foregroundStyle(.clear)
                    AxisValueLabel("")
                }
            }
            .chartXScale(domain: -1...30)  // 固定X轴范围，确保柱子间距一致
            
            // 图例
            HStack {
                Label("下载", systemImage: "circle.fill")
                    .foregroundColor(.blue)
                Label("上传", systemImage: "circle.fill")
                    .foregroundColor(.green)
            }
            .font(.caption)
        }
    }
} 