//
//  ScreenTimeManager.swift
//  Mujo
//

import Combine
import DeviceActivity
import FamilyControls
import Foundation
import SwiftUI
import WidgetKit

extension DeviceActivityReport.Context {
    static let mujoToday = Self(AppConfiguration.Reporting.todayContextName)
}

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published private(set) var errorMessage: String?
    @Published private(set) var dailyLimitMinutes: Int

    private let limitStore: DailyLimitStore
    private let monitoring: ScreenTimeMonitoring
    private let activityReportLoader: ActivityReportLoadCoordinator
    private var authorizationStatusSubscription: AnyCancellable?

    init() {
        let defaults = UserDefaults(
            suiteName: AppConfiguration.appGroupIdentifier
        ) ?? .standard
        let limitStore = DailyLimitStore(sharedDefaults: defaults)
        self.limitStore = limitStore
        activityReportLoader = ActivityReportLoadCoordinator(
            sharedDefaults: defaults
        )
        monitoring = ScreenTimeMonitoring(
            suiteName: AppConfiguration.appGroupIdentifier
        )
        dailyLimitMinutes = max(1, Int(limitStore.currentLimit / 60))
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

    func reportFilter(for interval: DateInterval) -> DeviceActivityFilter {
        return DeviceActivityFilter(
            segment: .hourly(during: interval)
        )
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginActivityReportLoad() -> String {
        activityReportLoader.beginLoading()
    }

    func waitUntilActivityReportIsReady(requestID: String) async {
        _ = await activityReportLoader.waitUntilReady(requestID: requestID)
    }

    func requestAuthorizationAndStart() async {
        errorMessage = nil

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus

            guard isAuthorized else { return }
            try await monitoring.restore(limit: limitStore.currentLimit)
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

        let safeLimit = max(60, TimeInterval(minutes * 60))
        if limitStore.save(safeLimit) {
            dailyLimitMinutes = Int(safeLimit / 60)
            WidgetCenter.shared.reloadTimelines(ofKind: AppConfiguration.widgetKind)
        }

        do {
            try await monitoring.updateLimit(to: safeLimit)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
