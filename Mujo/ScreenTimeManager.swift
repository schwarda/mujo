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
    static let mujoToday = Self("mujo.today")
}

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published private(set) var errorMessage: String?
    @Published private(set) var dailyLimitMinutes: Int

    private let limitStore: DailyLimitStore
    private let monitoring: ScreenTimeMonitoring

    init() {
        let defaults = UserDefaults(
            suiteName: MujoShared.appGroupIdentifier
        ) ?? .standard
        let limitStore = DailyLimitStore(sharedDefaults: defaults)
        self.limitStore = limitStore
        monitoring = ScreenTimeMonitoring(sharedDefaults: defaults)
        dailyLimitMinutes = max(1, Int(limitStore.currentLimit / 60))
    }

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    var reportFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        return DeviceActivityFilter(
            segment: .hourly(during: DateInterval(start: start, end: end))
        )
    }

    func restoreMonitoringIfPossible() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        guard isAuthorized else { return }

        do {
            try monitoring.restore(limit: limitStore.currentLimit)
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
            try monitoring.restore(limit: limitStore.currentLimit)
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
            WidgetCenter.shared.reloadTimelines(ofKind: MujoShared.widgetKind)
        }

        do {
            try monitoring.updateLimit(to: safeLimit)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
