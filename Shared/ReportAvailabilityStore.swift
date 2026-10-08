import Foundation

nonisolated enum ReportAvailability: String, Equatable, Sendable {
    case loading
    case hasData
    case noData
}

nonisolated enum ReportAvailabilityKind: String, Sendable {
    case onboardingHistory
    case limitEditor
}

nonisolated struct ReportAvailabilityRequest: Equatable, Sendable {
    let id: String
    let status: ReportAvailability
}

nonisolated struct OnboardingHistorySummary: Codable, Equatable, Sendable {
    let averageMinutes: Int
    let suggestedMinutes: Int
    let availableDayCount: Int
}

enum OnboardingHistorySummaryStore {
    private static let key = "mujo.onboardingHistorySummary"

    static func save(
        _ summary: OnboardingHistorySummary,
        defaults: UserDefaults
    ) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        defaults.set(data, forKey: key)
    }

    static func load(defaults: UserDefaults) -> OnboardingHistorySummary? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(
            OnboardingHistorySummary.self,
            from: data
        )
    }

    static func clear(defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}

enum ReportAvailabilityStore {
    private static let prefix = "mujo.reportAvailability"

    static func begin(
        _ kind: ReportAvailabilityKind,
        defaults: UserDefaults
    ) -> ReportAvailabilityRequest {
        let request = ReportAvailabilityRequest(
            id: UUID().uuidString,
            status: .loading
        )
        defaults.set(request.id, forKey: idKey(kind))
        defaults.set(request.status.rawValue, forKey: statusKey(kind))
        return request
    }

    static func current(
        _ kind: ReportAvailabilityKind,
        defaults: UserDefaults
    ) -> ReportAvailabilityRequest? {
        guard let id = defaults.string(forKey: idKey(kind)),
              let rawStatus = defaults.string(forKey: statusKey(kind)),
              let status = ReportAvailability(rawValue: rawStatus)
        else { return nil }

        return ReportAvailabilityRequest(id: id, status: status)
    }

    static func resolveCurrent(
        _ kind: ReportAvailabilityKind,
        requestID: String,
        as status: ReportAvailability,
        defaults: UserDefaults
    ) {
        guard status != .loading,
              defaults.string(forKey: idKey(kind)) == requestID
        else { return }
        defaults.set(status.rawValue, forKey: statusKey(kind))
    }

    private static func idKey(_ kind: ReportAvailabilityKind) -> String {
        "\(prefix).\(kind.rawValue).id"
    }

    private static func statusKey(_ kind: ReportAvailabilityKind) -> String {
        "\(prefix).\(kind.rawValue).status"
    }
}
