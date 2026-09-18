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
    private let sharedDefaults: UserDefaults
    
    private lazy var dailySchedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
        repeats: true
    )
    
    init(suiteName: String) {
        sharedDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    }
    
    func restore(limit: TimeInterval) throws {
        let center = DeviceActivityCenter()
        try ensureUsageMonitoring(limit: limit, using: center)
        removeLegacyMonitoring(from: center)
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
        let events = usageEvents(for: limit)
        let isCurrentConfiguration = center.schedule(for: .mujoUsage)
        == dailySchedule
        && center.events(for: .mujoUsage) == events
        
        if isCurrentConfiguration {
            recordUsageMonitoringStartIfNeeded()
            return
        }
        
        // startMonitoring replaces this activity's configuration. Keep the old
        // one running if registration fails, and never reset today's estimate.
        try center.startMonitoring(
            .mujoUsage,
            during: dailySchedule,
            events: events
        )
        recordUsageMonitoringStartIfNeeded()
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
    
    private func recordUsageMonitoringStartIfNeeded() {
        guard sharedDefaults.double(
            forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
        ) == 0 else { return }
        
        sharedDefaults.set(
            Date.now.timeIntervalSince1970,
            forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
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
    
    private func usageEvents(
        for limit: TimeInterval
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
                includesPastActivity: true
            )
        }
        return events
    }
}
