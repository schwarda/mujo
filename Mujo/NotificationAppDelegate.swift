//
//  NotificationAppDelegate.swift
//  Mujo
//
//  Created by Aikari Studio on 16/09/2026.
//

import UIKit
import UserNotifications

final class NotificationAppDelegate: NSObject,
    UIApplicationDelegate,
    UNUserNotificationCenterDelegate
{
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Returning without a custom action lets iOS open Mujø normally.
        completionHandler()
    }
}
