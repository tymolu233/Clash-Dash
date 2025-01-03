//
//  Clash_Dash.swift
//  Clash Dash
//
//  Created by Mou Yan on 11/19/24.
//

import SwiftUI
import Network

@main
struct Clash_Dash: App {
    @StateObject private var networkMonitor = NetworkMonitor()
    
    init() {
        // 请求本地网络访问权限
        Task { @MainActor in
            let localNetworkAuthorization = LocalNetworkAuthorization()
            let authorized = await localNetworkAuthorization.requestAuthorization()
            print("Local network authorization status: \(authorized)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(networkMonitor)
        }
    }
}
