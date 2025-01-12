import Foundation
import SwiftUI

enum OverviewCard: String, CaseIterable, Identifiable, Codable {
    case speed = "speed"
    case totalTraffic = "totalTraffic"
    case status = "status"
    case speedChart = "speedChart"
    case memoryChart = "memoryChart"
    case modeSwitch = "modeSwitch"
    case subscription = "subscription"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .speed: return "实时速度"
        case .totalTraffic: return "总流量"
        case .status: return "状态信息"
        case .speedChart: return "速率图表"
        case .memoryChart: return "内存图表"
        case .modeSwitch: return "代理模式切换"
        case .subscription: return "订阅信息"
        }
    }
    
    var icon: String {
        switch self {
        case .speed: return "speedometer"
        case .totalTraffic: return "arrow.up.arrow.down.circle"
        case .status: return "info.circle"
        case .speedChart: return "chart.line.uptrend.xyaxis"
        case .memoryChart: return "memorychip"
        case .modeSwitch: return "switch.2"
        case .subscription: return "doc.text.fill"
        }
    }
}

class OverviewCardSettings: ObservableObject {
    @AppStorage("overviewCardOrder") private var orderData: Data = Data()
    @AppStorage("overviewCardVisibility") private var visibilityData: Data = Data()
    
    @Published var cardOrder: [OverviewCard]
    @Published var cardVisibility: [OverviewCard: Bool]
    
    init() {
        // 先初始化存储属性
        cardOrder = OverviewCard.allCases
        cardVisibility = Dictionary(uniqueKeysWithValues: OverviewCard.allCases.map { card in
            // 订阅卡片默认隐藏
            if card == .subscription {
                return (card, false)
            }
            return (card, true)
        })
        
        // 然后从 AppStorage 加载数据
        if let savedOrder = try? JSONDecoder().decode([OverviewCard].self, from: orderData) {
            cardOrder = savedOrder
        }
        
        if let savedVisibility = try? JSONDecoder().decode([String: Bool].self, from: visibilityData) {
            cardVisibility = Dictionary(uniqueKeysWithValues: OverviewCard.allCases.map { card in
                (card, savedVisibility[card.rawValue] ?? (card == .subscription ? false : true))
            })
        }
    }
    
    func saveOrder() {
        if let encoded = try? JSONEncoder().encode(cardOrder) {
            orderData = encoded
        }
    }
    
    func saveVisibility() {
        let visibilityDict = Dictionary(uniqueKeysWithValues: cardVisibility.map { ($0.key.rawValue, $0.value) })
        if let encoded = try? JSONEncoder().encode(visibilityDict) {
            visibilityData = encoded
        }
    }
    
    func moveCard(from source: IndexSet, to destination: Int) {
        cardOrder.move(fromOffsets: source, toOffset: destination)
        saveOrder()
    }
    
    func toggleVisibility(for card: OverviewCard) {
        cardVisibility[card]?.toggle()
        saveVisibility()
    }
} 