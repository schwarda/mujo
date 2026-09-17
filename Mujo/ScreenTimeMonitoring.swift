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
    nonisolated static let mujoLimit = Self(
        AppConfiguration.Monitoring.limitActivityName
    )
    nonisolated static let legacyMujoDaily = Self("mujo.daily")
    nonisolated static let mujoNotifications = Self(
        AppConfiguration.Monitoring.notificationActivityName
    )
}

actor ScreenTimeMonitoring {
    private static let checkpointIntervalMinutes =
    AppConfiguration.DailyLimit.stepMinutes
    private static let maximumTrackedUsageMinutes =
    AppConfiguration.DailyLimit.maximumMinutes
    
    private let sharedDefaults: UserDefaults
    
    private lazy var dailySchedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
        repeats: true
    )
    
    private lazy var usageEvents: [
        DeviceActivityEvent.Name: DeviceActivityEvent
    ] = {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        
        for usedMinutes in stride(
            from: Self.checkpointIntervalMinutes,
            through: Self.maximumTrackedUsageMinutes,
            by: Self.checkpointIntervalMinutes
        ) {
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
    }()
    
    init(suiteName: String) {
        sharedDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    }
    
    func restore(limit: TimeInterval) throws {
        let center = DeviceActivityCenter()
        removeLegacyMonitoring(from: center)
        try ensureUsageMonitoring(using: center)
        try ensureLimitMonitoring(limit: limit, using: center)
        try ensureNotificationMonitoring(limit: limit, using: center)
    }
    
    func updateLimit(to limit: TimeInterval) throws {
        let center = DeviceActivityCenter()
        try ensureUsageMonitoring(using: center)
        try ensureLimitMonitoring(limit: limit, using: center)
        try ensureNotificationMonitoring(limit: limit, using: center)
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
            forKey: AppConfiguration.DefaultsKey.usageMonitoringStartedAt
        )
    }
    
    private func ensureNotificationMonitoring(
        limit: TimeInterval,
        using center: DeviceActivityCenter
    ) throws {
        let events = notificationEvents(for: limit)

        if events.isEmpty {
            if center.activities.contains(.mujoNotifications) {
                center.stopMonitoring([.mujoNotifications])
            }
            return
        }

        let isCurrentConfiguration = center.schedule(for: .mujoNotifications)
            == dailySchedule
            && center.events(for: .mujoNotifications) == events

        guard !isCurrentConfiguration else { return }

        if center.activities.contains(.mujoNotifications) {
            center.stopMonitoring([.mujoNotifications])
        }

        try center.startMonitoring(
            .mujoNotifications,
            during: dailySchedule,
            events: events
        )
    }
    
    private func ensureLimitMonitoring(
        limit: TimeInterval,
        using center: DeviceActivityCenter
    ) throws {
        let normalizedLimit = AppConfiguration.DailyLimit.normalizedLimit(limit)
        let eventName = DeviceActivityEvent.Name(
            AppConfiguration.Monitoring.limitEventName(
                seconds: Int(normalizedLimit)
            )
        )
        let events = [
            eventName: DeviceActivityEvent(
                threshold: durationComponents(for: normalizedLimit),
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
    
    private func notificationEvents(
        for limit: TimeInterval
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        let minutes = Int(
            AppConfiguration.DailyLimit.normalizedLimit(limit) / 60
        )
        
        guard minutes == 15,
              let invitation = NotificationMilestone
            .forLimit(minutes: minutes)
            .first(where: { $0.kind == .liveActivityInvitation })
        else {
            return [:]
        }
        
        let name = DeviceActivityEvent.Name(
            invitation.eventName(forLimitMinutes: minutes)
        )
        
        return [
            name: DeviceActivityEvent(
                threshold: durationComponents(
                    for: TimeInterval(invitation.usedMinutes * 60)
                ),
                includesPastActivity: true
            )
        ]
    }
}
