import Foundation

enum SpeedChartStyle: String, CaseIterable {
    case line = "line"
    case bar = "bar"
    
    var description: String {
        switch self {
        case .line:
            return "曲线"
        case .bar:
            return "柱状"
        }
    }
} 