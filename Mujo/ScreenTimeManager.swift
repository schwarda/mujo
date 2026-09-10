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

    private let sharedDefaults: UserDefaults
    private let monitoring: ScreenTimeMonitoring
    private let previewWriteQueue = DispatchQueue(
        label: "AikariStudio.Mujo.daily-limit-preview",
        qos: .userInitiated
    )
    private var pendingPreviewWrite: DispatchWorkItem?

    init() {
        let defaults = UserDefaults(
            suiteName: MujoShared.appGroupIdentifier
        ) ?? .standard
        sharedDefaults = defaults
        monitoring = ScreenTimeMonitoring(sharedDefaults: defaults)
        let storedValue = defaults.double(
            forKey: MujoShared.DefaultsKey.dailyLimit
        )
        let initialLimit = storedValue > 0
            ? storedValue
            : MujoShared.defaultDailyLimit
        defaults.removeObject(
            forKey: MujoShared.DefaultsKey.previewDailyLimit
        )
        dailyLimitMinutes = max(1, Int(initialLimit / 60))
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
            try monitoring.restore(limit: storedDailyLimit)
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
            try monitoring.restore(limit: storedDailyLimit)
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func previewDailyLimit(minutes: Int) {
        let safeMinutes = max(1, minutes)
        let previewLimit = TimeInterval(safeMinutes * 60)
        let suiteName = MujoShared.appGroupIdentifier
        let key = MujoShared.DefaultsKey.previewDailyLimit
        let workItem = DispatchWorkItem {
            UserDefaults(suiteName: suiteName)?.set(
                previewLimit,
                forKey: key
            )
        }

        pendingPreviewWrite?.cancel()
        pendingPreviewWrite = workItem
        previewWriteQueue.asyncAfter(
            deadline: .now() + .milliseconds(50),
            execute: workItem
        )
    }

    func setDailyLimit(minutes: Int) async {
        errorMessage = nil
        defer {
            clearDailyLimitPreview()
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
        if safeLimit != storedDailyLimit {
            sharedDefaults.set(
                safeLimit,
                forKey: MujoShared.DefaultsKey.dailyLimit
            )
            dailyLimitMinutes = Int(safeLimit / 60)
            WidgetCenter.shared.reloadTimelines(ofKind: MujoShared.widgetKind)
        }

        do {
            try monitoring.updateLimit(to: safeLimit)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var storedDailyLimit: TimeInterval {
        let storedValue = sharedDefaults.double(
            forKey: MujoShared.DefaultsKey.dailyLimit
        )
        return storedValue > 0
            ? storedValue
            : MujoShared.defaultDailyLimit
    }

    private func clearDailyLimitPreview() {
        pendingPreviewWrite?.cancel()
        pendingPreviewWrite = nil

        let suiteName = MujoShared.appGroupIdentifier
        let key = MujoShared.DefaultsKey.previewDailyLimit
        previewWriteQueue.async {
            UserDefaults(suiteName: suiteName)?.removeObject(forKey: key)
        }
    }
}
