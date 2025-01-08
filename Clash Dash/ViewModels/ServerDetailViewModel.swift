import Foundation

@MainActor
class ServerDetailViewModel: ObservableObject {
    @Published var serverViewModel: ServerViewModel
    
    init() {
        self.serverViewModel = ServerViewModel()
    }
    
    // 可以在这里添加更多的属性和方法
} 