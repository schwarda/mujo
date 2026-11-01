import Foundation

nonisolated struct NotificationPreferences: Codable, Equatable, Sendable {
    private static let storageKey = "mujo.notification.preferences"

    var recommendedEnabled: Bool
    var limitReachedEnabled: Bool
    var badgeEnabled: Bool
    var customPercentages: [Int]

    init(
        recommendedEnabled: Bool = true,
        limitReachedEnabled: Bool = true,
        badgeEnabled: Bool = true,
        customPercentages: [Int] = []
    ) {
        self.recommendedEnabled = recommendedEnabled
        self.limitReachedEnabled = limitReachedEnabled
        self.badgeEnabled = badgeEnabled
        self.customPercentages = Self.validPercentages(customPercentages)
    }

    static func validPercentages(_ percentages: [Int]) -> [Int] {
        Set(percentages.filter { (1...99).contains($0) }).sorted()
    }

    static func customUsedMinutes(percentage: Int, limitMinutes: Int) -> Int {
        let limit = AppConfiguration.DailyLimit.normalizedMinutes(limitMinutes)
        return max(1, (limit * min(99, max(1, percentage)) + 99) / 100)
    }

    static func load(from defaults: UserDefaults?) -> Self {
        guard let data = defaults?.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(Self.self, from: data)
        else { return Self() }

        return Self(
            recommendedEnabled: value.recommendedEnabled,
            limitReachedEnabled: value.limitReachedEnabled,
            badgeEnabled: value.badgeEnabled,
            customPercentages: value.customPercentages
        )
    }

    func save(to defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.storageKey)
    }
}
