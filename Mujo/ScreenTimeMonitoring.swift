//
//  ScreenTimeMonitoring.swift
//  Mujo
//

import DeviceActivity
import FamilyControls
import Foundation

private extension DeviceActivityName {
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
    
    @discardableResult
    func updateLimit(to limit: TimeInterval) throws -> Bool {
        guard let sharedDefaults else { throw Error.sharedStorageUnavailable }
        let scope = try UsageScopeLock.withLock {
            try CountedActivityScope.load(from: sharedDefaults)
        }
        let center = DeviceActivityCenter()
        let beganMeasurement = try ensureUsageMonitoring(limit: limit, scope: scope, using: center)
        removeInactiveMonitoring(keeping: DeviceActivityName(scope.activityName), from: center)
        return beganMeasurement
    }

    // Keep the previous registration and estimate available until iOS accepts
    // the replacement. The activity name also identifies stale callbacks.
    func updateScope(
        selectionData: Data,
        limit: TimeInterval,
        authorizationRevision: String?
    ) throws -> Bool {
        guard let sharedDefaults else { throw Error.sharedStorageUnavailable }
        let selection = try CountedActivityScope.decodeSelection(selectionData)
        let matchesPrevious = try UsageScopeLock.withLock {
            try checkAuthorizationRevision(authorizationRevision, defaults: sharedDefaults)
            guard let previous = try? CountedActivityScope.load(from: sharedDefaults) else {
                return false
            }
            return selection.countsSameActivity(as: previous.selection)
        }
        if matchesPrevious {
            return try updateLimit(to: limit)
        }

        let generation = UUID()
        let name = AppConfiguration.Monitoring.scopedActivityName(generation: generation)
        let activity = DeviceActivityName(name)
        let scope = CountedActivityScope(selection: selection, activityName: name)
        let center = DeviceActivityCenter()
        let start = Date.now
        try center.startMonitoring(
            activity,
            during: dailySchedule,
            events: usageEvents(for: limit, scope: scope, includesPastActivity: false)
        )

        do {
            try UsageScopeLock.withLock {
                try checkAuthorizationRevision(authorizationRevision, defaults: sharedDefaults)
                sharedDefaults.set(
                    [
                        AppConfiguration.Monitoring.scopeGenerationKey: generation.uuidString,
                        AppConfiguration.Monitoring.scopeSelectionKey: selectionData
                    ],
                    forKey: AppConfiguration.DefaultsKey.countedActivityScope
                )
                resetUsageMonitoringStart(to: start, defaults: sharedDefaults)
            }
        } catch {
            center.stopMonitoring([activity])
            throw error
        }
        removeInactiveMonitoring(keeping: activity, from: center)
        return true
    }

    private func checkAuthorizationRevision(_ revision: String?, defaults: UserDefaults) throws {
        guard defaults.string(
            forKey: AppConfiguration.DefaultsKey.countedActivityAuthorizationRevision
        ) == revision else { throw CountedActivityScope.StorageError.authorizationChanged }
    }
    
    private func ensureUsageMonitoring(
        limit: TimeInterval,
        scope: CountedActivityScope,
        using center: DeviceActivityCenter
    ) throws -> Bool {
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
            scope: scope,
            includesPastActivity: startedAt > 0 && !startedToday
        )
        let activity = DeviceActivityName(scope.activityName)
        let isCurrentConfiguration = center.schedule(for: activity)
        == dailySchedule
        && center.events(for: activity) == events
        
        if isCurrentConfiguration {
            return try UsageScopeLock.withLock {
                prepareUsageMonitoringStartIfNeeded()
            }
        }

        // Re-registering with includesPastActivity disabled would restart the
        // first day's counter. Keep the active first-day session intact. Its
        // universal 15-minute checkpoints still advance measurement. Custom
        // alerts use crossing detection until the next registration can safely
        // include past activity.
        if startedToday, center.activities.contains(activity) {
#if DEBUG
            DiagnosticsStore.record(
                source: "app",
                message: "Preserved first-day monitoring while limit changed",
                defaults: sharedDefaults
            )
#endif
            return false
        }
        
        // startMonitoring replaces this activity's configuration. Keep the old
        // one running if registration fails, and never reset today's estimate.
        let preparedNewMeasurement = try UsageScopeLock.withLock {
            prepareUsageMonitoringStartIfNeeded()
        }
        do {
            try center.startMonitoring(
                activity,
                during: dailySchedule,
                events: events
            )
        } catch {
            if preparedNewMeasurement {
                try? UsageScopeLock.withLock {
                    clearPreparedUsageMonitoringStart()
                }
            }
            throw error
        }
        return preparedNewMeasurement
    }

    private func removeInactiveMonitoring(
        keeping active: DeviceActivityName? = nil,
        from center: DeviceActivityCenter
    ) {
        let legacy: [DeviceActivityName] = [
            .legacyMujoDaily,
            .legacyMujoLimit,
            .legacyMujoNotifications
        ]
        let running = center.activities.filter {
            $0 != active && (
                legacy.contains($0)
                    || $0.rawValue == AppConfiguration.Monitoring.usageActivityName
                    || AppConfiguration.Monitoring.isScopedActivityName($0.rawValue)
            )
        }
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

        resetUsageMonitoringStart(to: .now, defaults: sharedDefaults)
        return true
    }

    private func resetUsageMonitoringStart(to now: Date, defaults sharedDefaults: UserDefaults) {
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
        scope: CountedActivityScope,
        includesPastActivity: Bool
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        let minutes = Int(
            AppConfiguration.DailyLimit.normalizedLimit(limit) / 60
        )
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for usedMinutes in AppConfiguration.Monitoring
            .usageThresholdMinutes(
                forLimitMinutes: minutes,
                customPercentages: NotificationPreferences.load(from: sharedDefaults)
                    .customPercentages
            ) {
            let name = DeviceActivityEvent.Name(
                AppConfiguration.Monitoring.usageEventName(minutes: usedMinutes)
            )
            events[name] = DeviceActivityEvent(
                applications: scope.selection.applicationTokens,
                categories: scope.selection.categoryTokens,
                webDomains: scope.selection.webDomainTokens,
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
        removeInactiveMonitoring(from: DeviceActivityCenter())
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
        guard let sharedDefaults,
              let name = AppConfiguration.Monitoring.activeUsageActivityName(in: sharedDefaults)
        else { return "inactive" }
        let activity = DeviceActivityName(name)
        guard center.activities.contains(activity) else {
            return "inactive"
        }
        return "active · \(center.events(for: activity).count) events"
    }
#endif
}
