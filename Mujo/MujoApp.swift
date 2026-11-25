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

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preview-workflow") {
                WorkflowPreview()
            } else if ProcessInfo.processInfo.arguments.contains("--ui-test-home") {
                HomeScreenPreview()
            } else {
                ContentView(localDefaults: .standard)
            }
#else
            ContentView(localDefaults: .standard)
#endif
        }
    }
}
