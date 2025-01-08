import Foundation
import SwiftUI

enum OverviewCard: String, CaseIterable, Identifiable, Codable {
    case speed = "speed"
    case totalTraffic = "totalTraffic"
    case status = "status"
    case speedChart = "speedChart"
    case memoryChart = "memoryChart"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .speed: return "实时速度"
        case .totalTraffic: return "总流量"
        case .status: return "状态信息"
        case .speedChart: return "速率图表"
        case .memoryChart: return "内存图表"
        }
    }
    
    var icon: String {
        switch self {
        case .speed: return "speedometer"
        case .totalTraffic: return "arrow.up.arrow.down.circle"
        case .status: return "info.circle"
        case .speedChart: return "chart.line.uptrend.xyaxis"
        case .memoryChart: return "memorychip"
        }
    }
}

class OverviewCardSettings: ObservableObject {
    @AppStorage("overviewCardOrder") private var orderData: Data = Data()
    @AppStorage("overviewCardVisibility") private var visibilityData: Data = Data()
    
    @Published private(set) var cardOrder: [OverviewCard]
    @Published private(set) var cardVisibility: [OverviewCard: Bool]
    
    init() {
        // 先初始化存储属性
        self.cardOrder = OverviewCard.allCases.map { $0 }
        self.cardVisibility = Dictionary(uniqueKeysWithValues: OverviewCard.allCases.map { ($0, true) })
        
        // 然后从持久化存储加载数据
        if let data = try? Data(contentsOf: Self.orderFileURL),
           let savedOrder = try? JSONDecoder().decode([OverviewCard].self, from: data) {
            self.cardOrder = savedOrder
        }
        
        if let data = try? Data(contentsOf: Self.visibilityFileURL),
           let savedVisibility = try? JSONDecoder().decode([String: Bool].self, from: data) {
            self.cardVisibility = Dictionary(uniqueKeysWithValues: OverviewCard.allCases.map { card in
                (card, savedVisibility[card.rawValue] ?? true)
            })
        }
    }
    
    private static var orderFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("overviewCardOrder.json")
    }
    
    private static var visibilityFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("overviewCardVisibility.json")
    }
    
    func saveOrder() {
        if let encoded = try? JSONEncoder().encode(cardOrder) {
            try? encoded.write(to: Self.orderFileURL)
        }
    }
    
    func saveVisibility() {
        let visibilityDict = Dictionary(uniqueKeysWithValues: cardVisibility.map { ($0.key.rawValue, $0.value) })
        if let encoded = try? JSONEncoder().encode(visibilityDict) {
            try? encoded.write(to: Self.visibilityFileURL)
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