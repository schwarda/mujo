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

extension DeviceActivityName {
    static let mujoUsage = Self(MujoShared.Monitoring.usageActivityName)
    static let mujoLimit = Self(MujoShared.Monitoring.limitActivityName)
    fileprivate static let legacyMujoDaily = Self("mujo.daily")
}

extension DeviceActivityReport.Context {
    static let mujoToday = Self("mujo.today")
}

@MainActor
final class ScreenTimeManager: ObservableObject {
    private static let checkpointIntervalMinutes = 15
    private static let maximumTrackedUsageMinutes = 12 * 60

    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published private(set) var errorMessage: String?
    @Published private(set) var dailyLimitMinutes: Int

    private let sharedDefaults: UserDefaults
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

        let center = DeviceActivityCenter()

        do {
            removeLegacyMonitoring(from: center)
            try ensureUsageMonitoring(using: center)
            try ensureLimitMonitoring(
                limit: storedDailyLimit,
                using: center
            )
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
            let center = DeviceActivityCenter()
            removeLegacyMonitoring(from: center)
            try ensureUsageMonitoring(using: center)
            try ensureLimitMonitoring(
                limit: storedDailyLimit,
                using: center
            )
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
        sharedDefaults.set(
            safeLimit,
            forKey: MujoShared.DefaultsKey.dailyLimit
        )
        dailyLimitMinutes = Int(safeLimit / 60)
        WidgetCenter.shared.reloadTimelines(ofKind: MujoShared.widgetKind)

        do {
            let center = DeviceActivityCenter()
            try ensureUsageMonitoring(using: center)
            try ensureLimitMonitoring(limit: safeLimit, using: center)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var dailySchedule: DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
    }

    private var usageEvents: [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        for usedMinutes in stride(
            from: Self.checkpointIntervalMinutes,
            through: Self.maximumTrackedUsageMinutes,
            by: Self.checkpointIntervalMinutes
        ) {
            let name = DeviceActivityEvent.Name(
                MujoShared.Monitoring.usedEventPrefix + "\(usedMinutes)"
            )
            events[name] = DeviceActivityEvent(
                threshold: durationComponents(
                    for: TimeInterval(usedMinutes * 60)
                ),
                includesPastActivity: true
            )
        }

        return events
    }

    private func ensureUsageMonitoring(
        using center: DeviceActivityCenter
    ) throws {
        let events = usageEvents
        let isCurrentConfiguration = center.schedule(for: .mujoUsage)
            == dailySchedule
            && center.events(for: .mujoUsage) == events

        if isCurrentConfiguration {
            recordUsageMonitoringStartIfNeeded()
            return
        }

        if center.activities.contains(.mujoUsage) {
            center.stopMonitoring([.mujoUsage])
        }

        try center.startMonitoring(
            .mujoUsage,
            during: dailySchedule,
            events: events
        )
        sharedDefaults.set(
            Date.now.timeIntervalSince1970,
            forKey: MujoShared.DefaultsKey.usageMonitoringStartedAt
        )
    }

    private func ensureLimitMonitoring(
        limit: TimeInterval,
        using center: DeviceActivityCenter
    ) throws {
        let eventName = DeviceActivityEvent.Name(
            MujoShared.Monitoring.limitEventName(seconds: Int(limit))
        )
        let events = [
            eventName: DeviceActivityEvent(
                threshold: durationComponents(for: limit),
                includesPastActivity: true
            )
        ]
        let isCurrentConfiguration = center.schedule(for: .mujoLimit)
            == dailySchedule
            && center.events(for: .mujoLimit) == events

        guard !isCurrentConfiguration else { return }

        if center.activities.contains(.mujoLimit) {
            center.stopMonitoring([.mujoLimit])
        }

        try center.startMonitoring(
            .mujoLimit,
            during: dailySchedule,
            events: events
        )
    }

    private func removeLegacyMonitoring(from center: DeviceActivityCenter) {
        guard center.activities.contains(.legacyMujoDaily) else { return }
        center.stopMonitoring([.legacyMujoDaily])
    }

    private func recordUsageMonitoringStartIfNeeded() {
        guard sharedDefaults.double(
            forKey: MujoShared.DefaultsKey.usageMonitoringStartedAt
        ) == 0 else { return }

        sharedDefaults.set(
            Date.now.timeIntervalSince1970,
            forKey: MujoShared.DefaultsKey.usageMonitoringStartedAt
        )
    }

    private func durationComponents(
        for duration: TimeInterval
    ) -> DateComponents {
        let totalSeconds = max(1, Int(duration))

        return DateComponents(
            hour: totalSeconds / 3_600,
            minute: totalSeconds % 3_600 / 60,
            second: totalSeconds % 60
        )
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
