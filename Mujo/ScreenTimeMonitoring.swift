//
//  ScreenTimeMonitoring.swift
//  Mujo
//

import DeviceActivity
import Foundation

private extension DeviceActivityName {
    nonisolated static let mujoUsage = Self(
        AppConfiguration.Monitoring.usageActivityName
    )
    nonisolated static let legacyMujoLimit = Self(
        AppConfiguration.Monitoring.legacyLimitActivityName
    )
    nonisolated static let legacyMujoDaily = Self("mujo.daily")
    nonisolated static let legacyMujoNotifications = Self(
        AppConfiguration.Monitoring.legacyNotificationActivityName
    )
}

actor ScreenTimeMonitoring {
    enum Error: LocalizedError {
        case sharedStorageUnavailable

        var errorDescription: String? {
            "Screen Time storage is unavailable."
        }
    }

    private let sharedDefaults: UserDefaults?
    
    private lazy var dailySchedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
        repeats: true
    )
    
    init(suiteName: String) {
        sharedDefaults = UserDefaults(suiteName: suiteName)
    }
    
    func restore(limit: TimeInterval) throws {
        try updateLimit(to: limit)
    }
    
    func updateLimit(to limit: TimeInterval) throws {
        let center = DeviceActivityCenter()
        try ensureUsageMonitoring(limit: limit, using: center)
        removeLegacyMonitoring(from: center)
    }
    
    private func ensureUsageMonitoring(
        limit: TimeInterval,
        using center: DeviceActivityCenter
    ) throws {
        guard let sharedDefaults else {
            throw Error.sharedStorageUnavailable
        }
        let now = Date.now
        let calendar = Calendar.autoupdatingCurrent
        let startedAt = sharedDefaults.double(
            forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
        )
        let startedToday = startedAt >= calendar.startOfDay(for: now)
            .timeIntervalSince1970
        let events = usageEvents(
            for: limit,
            includesPastActivity: startedAt > 0 && !startedToday
        )
        let isCurrentConfiguration = center.schedule(for: .mujoUsage)
        == dailySchedule
        && center.events(for: .mujoUsage) == events
        
        if isCurrentConfiguration {
            prepareUsageMonitoringStartIfNeeded()
            return
        }

        // Re-registering with includesPastActivity disabled would restart the
        // first day's counter. Keep the active first-day session intact. Its
        // universal 15-minute checkpoints still cover all notification
        // milestones for a changed limit.
        if startedToday, center.activities.contains(.mujoUsage) {
#if DEBUG
            DiagnosticsStore.record(
                source: "app",
                message: "Preserved first-day monitoring while limit changed",
                defaults: sharedDefaults
            )
#endif
            return
        }
        
        // startMonitoring replaces this activity's configuration. Keep the old
        // one running if registration fails, and never reset today's estimate.
        let preparedNewMeasurement = prepareUsageMonitoringStartIfNeeded()
        do {
            try center.startMonitoring(
                .mujoUsage,
                during: dailySchedule,
                events: events
            )
        } catch {
            if preparedNewMeasurement {
                clearPreparedUsageMonitoringStart()
            }
            throw error
        }
    }

    private func removeLegacyMonitoring(from center: DeviceActivityCenter) {
        let legacy: [DeviceActivityName] = [
            .legacyMujoDaily,
            .legacyMujoLimit,
            .legacyMujoNotifications
        ]
        let running = legacy.filter { center.activities.contains($0) }
        if !running.isEmpty {
            center.stopMonitoring(running)
        }
    }
    
    @discardableResult
    private func prepareUsageMonitoringStartIfNeeded() -> Bool {
        guard let sharedDefaults,
              sharedDefaults.double(
            forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
        ) == 0 else { return false }

        let now = Date.now
        let calendar = Calendar.autoupdatingCurrent
        sharedDefaults.set(
            now.timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
        )
        sharedDefaults.set(
            calendar.startOfDay(for: now).timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.lastCheckpointResetDay
        )
        sharedDefaults.set(
            calendar.timeZone.identifier,
            forKey: AppConfiguration.DefaultsKey
                .lastCheckpointTimeZoneIdentifier
        )
        sharedDefaults.set(
            false,
            forKey: AppConfiguration.DefaultsKey.hasUsageCheckpoint
        )
        sharedDefaults.set(
            0,
            forKey: AppConfiguration.DefaultsKey.estimatedUsedTime
        )
#if DEBUG
        DiagnosticsStore.record(
            source: "app",
            message: "Monitoring started at \(now.timeIntervalSince1970)",
            defaults: sharedDefaults
        )
#endif
        return true
    }

    private func clearPreparedUsageMonitoringStart() {
        guard let sharedDefaults else { return }
        [
            AppConfiguration.DefaultsKey.usageMonitoringStartedAt,
            AppConfiguration.DefaultsKey.lastCheckpointResetDay,
            AppConfiguration.DefaultsKey
                .lastCheckpointTimeZoneIdentifier,
            AppConfiguration.DefaultsKey.hasUsageCheckpoint,
            AppConfiguration.DefaultsKey.estimatedUsedTime
        ].forEach(sharedDefaults.removeObject(forKey:))
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
    
    private func usageEvents(
        for limit: TimeInterval,
        includesPastActivity: Bool
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        let minutes = Int(
            AppConfiguration.DailyLimit.normalizedLimit(limit) / 60
        )
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for usedMinutes in AppConfiguration.Monitoring
            .usageThresholdMinutes(forLimitMinutes: minutes) {
            let name = DeviceActivityEvent.Name(
                AppConfiguration.Monitoring.usageEventName(minutes: usedMinutes)
            )
            events[name] = DeviceActivityEvent(
                threshold: durationComponents(
                    for: TimeInterval(usedMinutes * 60)
                ),
                includesPastActivity: includesPastActivity
            )
        }
        return events
    }

#if DEBUG
    func resetForDiagnostics() {
        DeviceActivityCenter().stopMonitoring([.mujoUsage])
        guard let sharedDefaults else { return }
        let keys = [
            AppConfiguration.DefaultsKey.dailyLimit,
            AppConfiguration.DefaultsKey.estimatedUsedTime,
            AppConfiguration.DefaultsKey.lastCheckpointResetDay,
            AppConfiguration.DefaultsKey
                .lastCheckpointTimeZoneIdentifier,
            AppConfiguration.DefaultsKey.hasUsageCheckpoint,
            AppConfiguration.DefaultsKey.usageMonitoringStartedAt
        ]
        keys.forEach(sharedDefaults.removeObject(forKey:))
        sharedDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("mujo.notification.sent.") }
            .forEach(sharedDefaults.removeObject(forKey:))
        DiagnosticsStore.record(
            source: "app",
            message: "Measurement state reset for a new test",
            defaults: sharedDefaults
        )
    }

    func diagnosticsSummary() -> String {
        let center = DeviceActivityCenter()
        guard center.activities.contains(.mujoUsage) else {
            return "inactive"
        }
        return "active · \(center.events(for: .mujoUsage).count) events"
    }
#endif
}
