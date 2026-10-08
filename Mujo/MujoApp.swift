//
//  MujoApp.swift
//  Mujo
//
//  Created by Aikari Studio on 05/09/2026.
//

import SwiftUI

@main
struct MujoApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self)
    private var notificationAppDelegate

    init() {
#if DEBUG
        PerformanceDiagnostics.startFrameMonitoring()
        PerformanceDiagnostics.markPhase("app.init")
        PerformanceDiagnostics.log("app-lifecycle", "MujoApp initialized")
#endif
    }

    var body: some Scene {
#if DEBUG
        let _ = PerformanceDiagnostics.throttledLog(
            key: "MujoApp.body",
            "swiftui-body",
            "MujoApp body evaluated"
        )
#endif
        WindowGroup {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-test-home") {
                HomeScreenPreview()
            } else {
                ContentView()
            }
#else
            ContentView()
#endif
        }
    }
}
