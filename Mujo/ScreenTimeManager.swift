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
    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published private(set) var errorMessage: String?
    @Published private(set) var dailyLimitMinutes: Int
    @Published private(set) var usageSnapshot: UsageSnapshot
    @Published private(set) var countedActivitySelection: FamilyActivitySelection?

    private let limitStore: DailyLimitStore
    private lazy var monitoring = ScreenTimeMonitoring(
        suiteName: AppConfiguration.appGroupIdentifier
    )
    private let usageSnapshotLoader: UsageSnapshotLoader
    private lazy var appUpdateRecovery = AppUpdateRecovery()
    private var authorizationStatusSubscription: AnyCancellable?
    private var isRecoveringAppUpdate = false
    private var badgeUpdateTracker = RemainingTimeBadgeUpdateTracker()
    private let sharedDefaults: UserDefaults?
    private var hasUnrecordedAuthorizationLoss = false

    let usesSimulatedData: Bool
    lazy var notificationAuthorization = NotificationAuthorization(
        simulatesPermission: usesSimulatedData
    )

    convenience init(defaults: UserDefaults? = nil) {
        self.init(defaults: defaults, usesSimulatedData: false)
    }

#if DEBUG
    convenience init(workflowDefaults: UserDefaults) {
        self.init(defaults: workflowDefaults, usesSimulatedData: true)
    }
#endif

    private init(defaults: UserDefaults?, usesSimulatedData: Bool) {
        self.usesSimulatedData = usesSimulatedData
        let sharedDefaults = defaults ?? UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        )
        self.sharedDefaults = sharedDefaults
        let limitStore = DailyLimitStore(sharedDefaults: sharedDefaults)
        self.limitStore = limitStore
        usageSnapshotLoader = UsageSnapshotLoader(defaults: sharedDefaults)
        dailyLimitMinutes = Int(limitStore.currentLimit / 60)
        usageSnapshot = usageSnapshotLoader.load()
        countedActivitySelection = try? CountedActivityScope.load(from: sharedDefaults).selection
        guard !usesSimulatedData else { return }

        applyAuthorizationStatus(AuthorizationCenter.shared.authorizationStatus)
        if limitStore.migratedLimit != nil {
            WidgetCenter.shared.reloadAllTimelines()
        }
        authorizationStatusSubscription = AuthorizationCenter.shared
            .$authorizationStatus
            .removeDuplicates()
            .sink { [weak self] status in
                self?.applyAuthorizationStatus(status)
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
        guard !usesSimulatedData else { return isAuthorized }
        applyAuthorizationStatus(AuthorizationCenter.shared.authorizationStatus)
        return isAuthorized && !hasUnrecordedAuthorizationLoss
    }

    private func applyAuthorizationStatus(
        _ status: AuthorizationStatus,
        aboutToRequest: Bool = false
    ) {
        // Screen Time can briefly return .notDetermined on launch. A transition
        // away from observed approval or an actual new request can invalidate tokens.
        if status != .approved, authorizationStatus == .approved
            || (status == .denied && authorizationStatus != .denied)
            || aboutToRequest {
            hasUnrecordedAuthorizationLoss = true
        }
        if hasUnrecordedAuthorizationLoss, let sharedDefaults {
            do {
                let selectionWasInvalidated = try UsageScopeLock.withLock {
                    CountedActivityScope.recordAuthorizationLoss(in: sharedDefaults)
                }
                hasUnrecordedAuthorizationLoss = false
                if selectionWasInvalidated {
                    countedActivitySelection = nil
                    refreshUsageSnapshot()
                    requestWidgetReload()
                }
            } catch {
                // Retain the pending invalidation and retry before restoring monitoring.
                usageLogger.error(
                    "Could not record the change in Screen Time access: \(String(reflecting: error), privacy: .public)"
                )
            }
        }
        authorizationStatus = status
    }

    func restoreMonitoringIfPossible() async {
        guard !usesSimulatedData, refreshAuthorizationStatus() else { return }

        do {
            try await monitoring.restore(limit: limitStore.currentLimit)
            refreshUsageSnapshot()
            await RemainingTimeLiveActivityController.reconcile(
                with: usageSnapshot
            )
        } catch CountedActivityScope.StorageError.authorizationChanged {
            countedActivitySelection = nil
            refreshUsageSnapshot()
        } catch {
            handleMonitoringError(error)
        }
    }

    func requestAuthorization() async {
        errorMessage = nil
        if usesSimulatedData {
            authorizationStatus = .approved
            return
        }

        applyAuthorizationStatus(
            AuthorizationCenter.shared.authorizationStatus,
            aboutToRequest: true
        )
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
        } catch {
            refreshAuthorizationStatus()
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
        guard !usesSimulatedData,
              appUpdateRecovery.isRequired,
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
        if usesSimulatedData {
            if refreshedSnapshot != usageSnapshot {
                usageSnapshot = refreshedSnapshot
            }
            return
        }

        let badgeCount = RemainingTimeBadge.badgeCount(
            from: refreshedSnapshot,
            preferences: NotificationPreferences.load(from: sharedDefaults)
        ) ?? 0
        if badgeUpdateTracker.shouldApply(badgeCount) {
            RemainingTimeBadge.update(count: badgeCount)
        }
        guard refreshedSnapshot != usageSnapshot else { return }

        usageSnapshot = refreshedSnapshot
        Task {
            guard refreshedSnapshot == usageSnapshot else { return }
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
        guard !usesSimulatedData else { return }
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

    func refreshNotificationPreferences() async {
        guard !usesSimulatedData else { return }
        refreshUsageSnapshot()
        guard refreshAuthorizationStatus() else { return }
        do {
            try await monitoring.restore(limit: limitStore.currentLimit)
        } catch CountedActivityScope.StorageError.authorizationChanged {
            return
        } catch {
            handleMonitoringError(error)
        }
    }

    var notificationPreferences: NotificationPreferences {
        NotificationPreferences.load(from: sharedDefaults)
    }

    var canSaveNotificationPreferences: Bool { sharedDefaults != nil }

    func refreshNotificationBadge() {
        guard !usesSimulatedData else { return }
        let count = RemainingTimeBadge.badgeCount(
            from: usageSnapshotLoader.load(),
            preferences: notificationPreferences
        ) ?? 0
        _ = badgeUpdateTracker.shouldApply(count)
        RemainingTimeBadge.update(count: count)
    }

    func saveNotificationPreferences(_ preferences: NotificationPreferences) {
        guard let sharedDefaults else { return }
        preferences.save(to: sharedDefaults)
        refreshUsageSnapshot()
    }

    func setDailyLimit(minutes: Int, startMonitoring: Bool = true) async {
        errorMessage = nil

        if !isAuthorized, !usesSimulatedData {
            await requestAuthorization()
        }

        guard isAuthorized, !hasUnrecordedAuthorizationLoss else { return }

        guard sharedDefaults != nil else {
            errorMessage = String(localized: "Screen Time storage is unavailable. Open Mujø again and try again.")
            return
        }

        let normalizedMinutes = AppConfiguration.DailyLimit
            .normalizedMinutes(minutes)
        let safeLimit = TimeInterval(normalizedMinutes * 60)
        let didChangeLimit = limitStore.save(safeLimit)
        if didChangeLimit {
            dailyLimitMinutes = normalizedMinutes
            refreshUsageSnapshot()
            if !usesSimulatedData {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }

        guard !usesSimulatedData, startMonitoring else { return }

        do {
            try await monitoring.updateLimit(to: safeLimit)
            await RemainingTimeLiveActivityController.reconcile(
                with: usageSnapshot,
                resumeAfterLimitChange: didChangeLimit
            )
        } catch CountedActivityScope.StorageError.authorizationChanged {
            return
        } catch {
            handleMonitoringError(error)
            if errorMessage == nil {
                errorMessage = String(localized: "Screen Time monitoring is unavailable. Open Mujø again and try again.")
            }
        }
    }

    func saveCountedActivity(_ selection: FamilyActivitySelection) async throws {
        guard refreshAuthorizationStatus() else {
            throw CountedActivitySaveError.authorizationRequired
        }
        let selectionData = try CountedActivityScope.encodeSelection(selection)
        if usesSimulatedData {
            countedActivitySelection = selection
            return
        }

        let authorizationRevision = sharedDefaults?.string(
            forKey: AppConfiguration.DefaultsKey.countedActivityAuthorizationRevision
        )
        let didStartMeasurement = try await monitoring.updateScope(
            selectionData: selectionData,
            limit: limitStore.currentLimit,
            authorizationRevision: authorizationRevision
        )
        guard refreshAuthorizationStatus() else {
            throw CountedActivitySaveError.authorizationRequired
        }
        guard sharedDefaults?.string(
            forKey: AppConfiguration.DefaultsKey.countedActivityAuthorizationRevision
        ) == authorizationRevision else {
            throw CountedActivityScope.StorageError.authorizationChanged
        }
        if countedActivitySelection != selection {
            countedActivitySelection = selection
        }
        clearError()
        refreshUsageSnapshot()
        if didStartMeasurement {
            requestWidgetReload()
            refreshNotificationBadge()
        }
    }

    private enum CountedActivitySaveError: LocalizedError {
        case authorizationRequired

        var errorDescription: String? {
            String(localized: "Allow access to Screen Time, then try again.")
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
