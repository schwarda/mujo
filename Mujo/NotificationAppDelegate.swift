//
//  NotificationAppDelegate.swift
//  Mujo
//
//  Created by Aikari Studio on 16/09/2026.
//

import OSLog
import UIKit
import UserNotifications
import FamilyControls

final class NotificationAppDelegate: NSObject,
    UIApplicationDelegate,
    UNUserNotificationCenterDelegate
{
    private struct Invitation {
        let limitMinutes: Int
        let remainingMinutes: Int
        let receivedAt: Date
    }

    private static var pendingInvitation: Invitation?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    @MainActor
    static func processPendingInvitationIfActive() async {
        guard UIApplication.shared.applicationState == .active,
              let invitation = pendingInvitation
        else { return }

        pendingInvitation = nil

        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved, .approvedWithDataAccess:
            break
        default:
            return
        }

        guard Calendar.current.isDate(invitation.receivedAt, inSameDayAs: .now),
              let defaults = UserDefaults(
                  suiteName: AppConfiguration.appGroupIdentifier
              ),
              let storedLimit = defaults.object(
                  forKey: AppConfiguration.DefaultsKey.dailyLimit
              ) as? TimeInterval,
              storedLimit.isFinite,
              storedLimit > 0
        else { return }

        let limitMinutes = Int(
            AppConfiguration.DailyLimit.normalizedLimit(storedLimit) / 60
        )

        guard invitation.limitMinutes == limitMinutes,
              (1...limitMinutes).contains(invitation.remainingMinutes)
        else { return }

        let snapshot = UsageSnapshotLoader(defaults: defaults).load()
        let estimate = UsageEstimator.estimate(from: snapshot, at: .now)

        let remainingMinutes = estimate.isAvailable
            ? min(invitation.remainingMinutes, Int(estimate.remainingTime / 60))
            : invitation.remainingMinutes

        guard remainingMinutes > 0 else { return }

        do {
            _ = try await RemainingTimeLiveActivityController.start(
                remainingMinutes: remainingMinutes,
                limitMinutes: limitMinutes,
                updatedAt: invitation.receivedAt
            )
        } catch {
            Logger(
                subsystem: "AikariStudio.Mujo",
                category: "NotificationTap"
            ).error("Could not start Live Activity: \(error.localizedDescription)")
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let info = response.notification.request.content.userInfo

        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              info["mujoAction"] as? String == "startLiveActivity",
              let limitMinutes = info["limitMinutes"] as? Int,
              let remainingMinutes = info["remainingMinutes"] as? Int,
              let receivedAt = info["receivedAt"] as? TimeInterval,
              receivedAt.isFinite
        else { return }

        Task { @MainActor in
            Self.pendingInvitation = Invitation(
                limitMinutes: limitMinutes,
                remainingMinutes: remainingMinutes,
                receivedAt: Date(timeIntervalSince1970: receivedAt)
            )

            Logger(
                subsystem: "AikariStudio.Mujo",
                category: "NotificationTap"
            ).notice("Live Activity invitation queued")
            
            await Self.processPendingInvitationIfActive()
        }
    }
}
