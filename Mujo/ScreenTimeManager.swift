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

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published private(set) var errorMessage: String?
    @Published private(set) var dailyLimitMinutes: Int
    @Published private(set) var usageSnapshot: UsageSnapshot

    private let limitStore: DailyLimitStore
    private let monitoring: ScreenTimeMonitoring
    private let usageSnapshotLoader: UsageSnapshotLoader
    private var authorizationStatusSubscription: AnyCancellable?

    init() {
        let defaults = UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        ) ?? .standard
        let limitStore = DailyLimitStore(sharedDefaults: defaults)
        self.limitStore = limitStore
        usageSnapshotLoader = UsageSnapshotLoader(defaults: defaults)
        monitoring = ScreenTimeMonitoring(
            suiteName: AppConfiguration.appGroupIdentifier
        )
        dailyLimitMinutes = Int(limitStore.currentLimit / 60)
        usageSnapshot = usageSnapshotLoader.load()
        if limitStore.migratedLimit != nil {
            WidgetCenter.shared.reloadTimelines(
                ofKind: AppConfiguration.widgetKind
            )
        }
        authorizationStatusSubscription = AuthorizationCenter.shared
            .$authorizationStatus
            .removeDuplicates()
            .sink { [weak self] status in
                self?.authorizationStatus = status
            }
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .approved, .approvedWithDataAccess:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestAuthorizationAndStart() async {
        errorMessage = nil

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus

            guard isAuthorized else { return }
            try await monitoring.restore(limit: limitStore.currentLimit)
            refreshUsageSnapshot()
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func previewDailyLimit(minutes: Int) {
        limitStore.preview(minutes: minutes)
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
        guard refreshedSnapshot != usageSnapshot else { return }

        usageSnapshot = refreshedSnapshot
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

    func setDailyLimit(minutes: Int) async {
        errorMessage = nil
        defer {
            limitStore.clearPreview()
        }

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
        if limitStore.save(safeLimit) {
            dailyLimitMinutes = normalizedMinutes
            refreshUsageSnapshot()
            WidgetCenter.shared.reloadTimelines(ofKind: AppConfiguration.widgetKind)
        }

        do {
            try await monitoring.updateLimit(to: safeLimit)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
