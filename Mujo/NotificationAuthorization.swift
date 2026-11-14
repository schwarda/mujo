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
    enum RequestOutcome {
        case authorized
        case denied
        case failed
    }
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    @Published private(set) var hasLoadedSettings = false
    @Published private(set) var alertSetting: UNNotificationSetting = .notSupported
    @Published private(set) var notificationCenterSetting: UNNotificationSetting = .notSupported
    @Published private(set) var badgeSetting: UNNotificationSetting = .notSupported

    private let simulatesPermission: Bool
    private lazy var center = UNUserNotificationCenter.current()

    init(simulatesPermission: Bool = false) {
        self.simulatesPermission = simulatesPermission
    }

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
        if simulatesPermission {
            hasLoadedSettings = true
            return
        }

        let settings = await center.notificationSettings()
        status = settings.authorizationStatus
        alertSetting = settings.alertSetting
        notificationCenterSetting = settings.notificationCenterSetting
        badgeSetting = settings.badgeSetting
        hasLoadedSettings = true
    }

    func requestAuthorization() async -> RequestOutcome {
        if simulatesPermission {
            status = .authorized
            alertSetting = .enabled
            notificationCenterSetting = .enabled
            badgeSetting = .enabled
            hasLoadedSettings = true
            return .authorized
        }

        do {
            _ = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
        } catch {
            await refreshStatus()
            return .failed
        }

        await refreshStatus()
        return isAuthorized ? .authorized : .denied
    }
}
