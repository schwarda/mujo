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

enum DiagnosticsScenarioStore {
    nonisolated private static let forceNoHistoryKey =
        "mujo.debug.forceNoHistoryOnboarding"

    nonisolated static func scheduleNoHistoryOnboarding() {
        UserDefaults.standard.set(true, forKey: forceNoHistoryKey)
    }

    nonisolated static func consumeNoHistoryOnboarding() -> Bool {
        guard UserDefaults.standard.bool(forKey: forceNoHistoryKey) else {
            return false
        }
        UserDefaults.standard.removeObject(forKey: forceNoHistoryKey)
        return true
    }
}
#endif
