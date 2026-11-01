#if DEBUG
import Foundation

struct DiagnosticEvent: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let source: String
    let message: String
}

enum DiagnosticsStore {
    nonisolated private static let eventsKeyPrefix =
        "mujo.debug.diagnosticEvents"
    nonisolated private static let knownSources = [
        "app", "monitor", "widget", "report"
    ]
    nonisolated private static let maximumEventsPerSource = 100

    nonisolated static func record(
        source: String,
        message: String,
        defaults: UserDefaults?
    ) {
        guard let defaults else { return }
        var events = load(source: source, defaults: defaults)
        events.append(DiagnosticEvent(
            id: UUID(),
            date: .now,
            source: source,
            message: message
        ))
        if events.count > maximumEventsPerSource {
            events.removeFirst(events.count - maximumEventsPerSource)
        }
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: eventsKey(source))
    }

    nonisolated static func load(
        defaults: UserDefaults?
    ) -> [DiagnosticEvent] {
        knownSources
            .flatMap { load(source: $0, defaults: defaults) }
            .sorted { $0.date < $1.date }
    }

    nonisolated static func clear(defaults: UserDefaults?) {
        knownSources.forEach {
            defaults?.removeObject(forKey: eventsKey($0))
        }
    }

    nonisolated private static func load(
        source: String,
        defaults: UserDefaults?
    ) -> [DiagnosticEvent] {
        guard let data = defaults?.data(forKey: eventsKey(source)),
              let events = try? JSONDecoder().decode(
                  [DiagnosticEvent].self,
                  from: data
              )
        else { return [] }
        return events
    }

    nonisolated private static func eventsKey(_ source: String) -> String {
        "\(eventsKeyPrefix).\(source)"
    }
}

enum OnboardingDiagnosticsScenario: String, CaseIterable, Identifiable,
    Sendable {
    case noData
    case oneDay
    case threeDays
    case sixDays
    case eightDays

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .noData: "No data"
        case .oneDay: "1 day"
        case .threeDays: "3 days"
        case .sixDays: "6 days"
        case .eightDays: "8 days in history"
        }
    }

    nonisolated var detail: String {
        switch self {
        case .noData:
            "Screen Time data is unavailable"
        case .oneDay:
            "1h daily average · 1 reported day"
        case .threeDays:
            "2h daily average · 3 reported days"
        case .sixDays:
            "3h 30m daily average · 6 reported days"
        case .eightDays:
            "5h daily average · last 7 of 8 days"
        }
    }

    nonisolated var historyDayCount: Int {
        switch self {
        case .noData: 0
        case .oneDay: 1
        case .threeDays: 3
        case .sixDays: 6
        case .eightDays: 8
        }
    }
}

enum DiagnosticsScenarioStore {
    nonisolated private static let onboardingScenarioKey =
        "mujo.debug.onboardingDataScenario"

    nonisolated static func scheduleOnboarding(
        scenario: OnboardingDiagnosticsScenario
    ) {
        sharedDefaults?.set(scenario.rawValue, forKey: onboardingScenarioKey)
    }

    nonisolated static func activeOnboardingScenario()
        -> OnboardingDiagnosticsScenario? {
        guard let rawValue = sharedDefaults?.string(
            forKey: onboardingScenarioKey
        ) else { return nil }
        return OnboardingDiagnosticsScenario(rawValue: rawValue)
    }

    nonisolated static func clearOnboardingScenario() {
        sharedDefaults?.removeObject(forKey: onboardingScenarioKey)
    }

    nonisolated private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppConfiguration.appGroupIdentifier)
    }
}
#endif
