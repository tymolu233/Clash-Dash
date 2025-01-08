import SwiftUI

@MainActor
class ServerDetailViewModel: ObservableObject {
    let serverViewModel: ServerViewModel
    
    init() {
        self.serverViewModel = ServerViewModel()
    }
} 