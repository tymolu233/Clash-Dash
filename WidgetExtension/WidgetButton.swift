//
//  WidgetButton.swift
//  Clash Dash
//
//  Created by Mou Yan on 12/17/24.
//


import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 18.0, *)
struct WidgetButton: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ClashDash") {
            ControlWidgetButton(action: WidgetButtonIntent()) {
                Label{
                    Text("Clash Dash")
                } icon: {
                    Image("Symbol")
                }
                
            }
        }
        .displayName("Clash Dash")
    }
}
@available(iOS 18.0, *)
struct WidgetButtonIntent: AppIntent {
    static let title: LocalizedStringResource = "WidgetButton"

    static var openAppWhenRun = true
    static var isDiscoverable = true

    func perform() async throws -> some IntentResult & OpensIntent {
        let url = URL(string: "clashdash://")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}
