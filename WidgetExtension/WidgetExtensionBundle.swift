//
//  WidgetExtensionBundle.swift
//  WidgetExtension
//
//  Created by Mou Yan on 12/17/24.
//

import WidgetKit
import SwiftUI

@main
struct WidgetLauncher {
    static func main() {
        if #available(iOSApplicationExtension 18.0, *) {
            WidgetsBundle18.main()
        } else {
            WidgetsBundle16.main()
        }
    }
}

struct WidgetsBundle16: WidgetBundle {
    var body: some Widget {
        SimpleWidget()
    }
}

@available(iOSApplicationExtension 18.0, *)
struct WidgetsBundle18: WidgetBundle {
    var body: some Widget {
        SimpleWidget()
        WidgetButton()
    }
}
