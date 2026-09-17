//
//  NotificationAuthorization.swift
//  Mujo
//
//  Created by Aikari Studio on 16/09/2026.
//

import UserNotifications
import Combine

@MainActor
final class NotificationAuthorization: ObservableObject {
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    var isAuthorized: Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            true

        case .notDetermined, .denied:
            false

        @unknown default:
            false
        }
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        status = settings.authorizationStatus
    }

    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            // Neskôr sem napojíme používateľskú chybovú hlášku.
        }

        await refreshStatus()
    }
}
