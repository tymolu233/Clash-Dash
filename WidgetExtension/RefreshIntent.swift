import AppIntents
import WidgetKit

@available(iOS 17.0, *)
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "刷新 Widget"
    static var description: IntentDescription = "刷新 Widget 数据"
    
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        await WidgetCenter.shared.reloadTimelines(ofKind: "SimpleWidget")
        return .result(value: true)
    }
} 