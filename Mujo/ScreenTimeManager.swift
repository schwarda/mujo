//
//  ScreenTimeManager.swift
//  Mujo
//

import Combine
import FamilyControls
import Foundation
import OSLog
import SwiftUI
import WidgetKit

private let usageLogger = Logger(
    subsystem: "AikariStudio.Mujo",
    category: "UsageEstimate"
)

private let updateRecoveryLogger = Logger(
    subsystem: "AikariStudio.Mujo",
    category: "AppUpdateRecovery"
)

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published private(set) var errorMessage: String?
    @Published private(set) var dailyLimitMinutes: Int
    @Published private(set) var usageSnapshot: UsageSnapshot

    private let limitStore: DailyLimitStore
    private let monitoring: ScreenTimeMonitoring
    private let usageSnapshotLoader: UsageSnapshotLoader
    private let appUpdateRecovery: AppUpdateRecovery
    private var authorizationStatusSubscription: AnyCancellable?
    private var isRecoveringAppUpdate = false
    private var badgeUpdateTracker = RemainingTimeBadgeUpdateTracker()
    private let sharedDefaults: UserDefaults?

    init(defaults: UserDefaults? = nil) {
        let sharedDefaults = defaults ?? UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        )
        self.sharedDefaults = sharedDefaults
        let limitStore = DailyLimitStore(sharedDefaults: sharedDefaults)
        self.limitStore = limitStore
        appUpdateRecovery = AppUpdateRecovery()
        usageSnapshotLoader = UsageSnapshotLoader(defaults: sharedDefaults)
        monitoring = ScreenTimeMonitoring(
            suiteName: AppConfiguration.appGroupIdentifier
        )
        dailyLimitMinutes = Int(limitStore.currentLimit / 60)
        usageSnapshot = usageSnapshotLoader.load()
        if limitStore.migratedLimit != nil {
            WidgetCenter.shared.reloadAllTimelines()
        }
        authorizationStatusSubscription = AuthorizationCenter.shared
            .$authorizationStatus
            .removeDuplicates()
            .sink { [weak self] status in
                self?.authorizationStatus = status
            }
#if DEBUG
        DiagnosticsStore.record(
            source: "app",
            message: sharedDefaults == nil
                ? "App Group unavailable"
                : "App Group available",
            defaults: sharedDefaults
        )
#endif
    }

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    @discardableResult
    func refreshAuthorizationStatus() -> Bool {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        return isAuthorized
    }

    func restoreMonitoringIfPossible() async {
        guard refreshAuthorizationStatus() else { return }

        do {
            try await monitoring.restore(limit: limitStore.currentLimit)
            refreshUsageSnapshot()
            await RemainingTimeLiveActivityController.reconcile(
                with: usageSnapshot
            )
        } catch {
            handleMonitoringError(error)
        }
    }

    func requestAuthorization() async {
        errorMessage = nil

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            handleMonitoringError(error)
        }
    }

    func clearError() {
        errorMessage = nil
    }

#if DEBUG
    func showPreviewError(_ message: String) {
        errorMessage = message
    }

    var diagnosticDefaults: UserDefaults? {
        sharedDefaults
    }

    func resetMeasurementForDiagnostics() async {
        await monitoring.resetForDiagnostics()
        sharedDefaults?.set(
            AppConfiguration.defaultDailyLimit,
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        )
        dailyLimitMinutes = Int(AppConfiguration.defaultDailyLimit / 60)
        refreshUsageSnapshot()
        requestWidgetReload()
    }

    func monitoringDiagnosticsSummary() async -> String {
        await monitoring.diagnosticsSummary()
    }
#endif

    func recoverAfterAppUpdateIfNeeded() async {
        guard appUpdateRecovery.isRequired,
              !isRecoveringAppUpdate
        else { return }

        isRecoveringAppUpdate = true
        defer { isRecoveringAppUpdate = false }

        WidgetCenter.shared.reloadAllTimelines()

        do {
            try await RemainingTimeLiveActivityController
                .restartActiveAfterAppUpdate(with: usageSnapshot)
            appUpdateRecovery.markCompleted()
        } catch {
            updateRecoveryLogger.error(
                "Live Activity recovery failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func usageEstimate(forLimitMinutes minutes: Int) -> UsageEstimate {
        UsageEstimator.estimate(
            from: usageSnapshot,
            dailyLimit: TimeInterval(
                AppConfiguration.DailyLimit.normalizedMinutes(minutes) * 60
            ),
            at: .now
        )
    }

    func refreshUsageSnapshot() {
        let refreshedSnapshot = usageSnapshotLoader.load()
        let badgeCount = RemainingTimeBadge.badgeCount(
            from: refreshedSnapshot
        ) ?? 0
        if badgeUpdateTracker.shouldApply(badgeCount) {
            RemainingTimeBadge.update(count: badgeCount)
        }
        guard refreshedSnapshot != usageSnapshot else { return }

        usageSnapshot = refreshedSnapshot
        Task {
            await RemainingTimeLiveActivityController.reconcile(
                with: refreshedSnapshot
            )
        }
#if DEBUG
        let estimate = UsageEstimator.estimate(
            from: refreshedSnapshot,
            at: .now
        )
        usageLogger.debug(
            "limit=\(refreshedSnapshot.storedDailyLimit) used=\(refreshedSnapshot.estimatedUsedTime) valid=\(estimate.isAvailable) remaining=\(estimate.remainingTime)"
        )
#endif
    }

    func requestWidgetReload() {
        WidgetCenter.shared.reloadAllTimelines()
#if DEBUG
        sharedDefaults?.set(
            Date.now.timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.lastWidgetReloadRequestedAt
        )
        DiagnosticsStore.record(
            source: "app",
            message: "Widget reload requested",
            defaults: sharedDefaults
        )
#endif
    }

    func setDailyLimit(minutes: Int) async {
        errorMessage = nil

        if !isAuthorized {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            } catch {
                authorizationStatus = AuthorizationCenter.shared.authorizationStatus
                errorMessage = error.localizedDescription
                return
            }
        }

        guard isAuthorized else { return }

        let normalizedMinutes = AppConfiguration.DailyLimit
            .normalizedMinutes(minutes)
        let safeLimit = TimeInterval(normalizedMinutes * 60)
        let didChangeLimit = limitStore.save(safeLimit)
        if didChangeLimit {
            dailyLimitMinutes = normalizedMinutes
            refreshUsageSnapshot()
            WidgetCenter.shared.reloadAllTimelines()
        }

        do {
            try await monitoring.updateLimit(to: safeLimit)
            await RemainingTimeLiveActivityController.reconcile(
                with: usageSnapshot,
                resumeAfterLimitChange: didChangeLimit
            )
        } catch {
            handleMonitoringError(error)
        }
    }

    private func handleMonitoringError(_ error: Error) {
        if let monitoringError = error as? ScreenTimeMonitoring.Error,
           case .sharedStorageUnavailable = monitoringError {
            usageLogger.fault("App Group storage is unavailable")
#if DEBUG
            DiagnosticsStore.record(
                source: "app",
                message: "Monitoring stopped: App Group unavailable",
                defaults: sharedDefaults
            )
#endif
            return
        }
        errorMessage = error.localizedDescription
    }
}
