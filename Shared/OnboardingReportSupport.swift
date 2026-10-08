import Combine
import DeviceActivity
import Foundation
import SwiftUI

extension DeviceActivityReport.Context {
    nonisolated static let mujoInsightsCarousel = Self(
        "Mujo Insights Carousel"
    )
    nonisolated static let mujoDailyAverage = Self("Mujo Daily Average")
    nonisolated static let mujoWeeklyTotal = Self("Mujo Weekly Total")
    nonisolated static let mujoYearlyTotal = Self("Mujo Yearly Total")
    nonisolated static let mujoLimitEditorDescription = Self(
        "Mujo Limit Editor Description"
    )
    nonisolated static let mujoDailySavings = Self("Mujo Daily Savings")
    nonisolated static let mujoWeeklySavings = Self("Mujo Weekly Savings")
    nonisolated static let mujoAnnualSavings = Self("Mujo Annual Savings")
    nonisolated static let mujoSavingsCarousel = Self(
        "Mujo Savings Carousel"
    )
}

// Screen Time data stays inside the system report extension. Keep its view
// unchanged when unrelated host state (for example the limit dial) changes.
struct ScreenTimeReportView: View, Equatable {
    let context: DeviceActivityReport.Context
    let filter: DeviceActivityFilter

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.context == rhs.context && lhs.filter == rhs.filter
    }

    var body: some View {
#if DEBUG
        let bodyStartedAt = PerformanceDiagnostics.now
        let _ = PerformanceDiagnostics.log(
            "report-host",
            "ScreenTimeReportView body; context=\(context.rawValue)"
        )
#endif
        DeviceActivityReport(context, filter: filter)
            .onAppear {
#if DEBUG
                PerformanceDiagnostics.markPhase(
                    "report-host.appeared.\(context.rawValue)"
                )
                PerformanceDiagnostics.log(
                    "report-host",
                    "DeviceActivityReport appeared; context=\(context.rawValue)"
                )
                PerformanceDiagnostics.mainQueueProbe(
                    "report-host",
                    "after DeviceActivityReport appeared",
                    startedAt: bodyStartedAt
                )
#endif
            }
            .onDisappear {
#if DEBUG
                PerformanceDiagnostics.markPhase(
                    "report-host.disappeared.\(context.rawValue)"
                )
                PerformanceDiagnostics.log(
                    "report-host",
                    "DeviceActivityReport disappeared; context=\(context.rawValue)"
                )
#endif
            }
    }
}

enum OnboardingReportStorage {
    nonisolated static let appGroupIdentifier =
        "group.AikariStudio.Mujo.shared"
    nonisolated static let dailyLimitSecondsKey = "dailyLimitSeconds"
}

enum OnboardingProjectionRules {
    nonisolated static let recentDayCount = 7
    nonisolated static let annualDayCount = 365
    nonisolated static let suggestedLimitRatio = 0.85

    nonisolated static var limitStepMinutes: Int {
        AppConfiguration.DailyLimit.stepMinutes
    }

    nonisolated static var minimumLimitMinutes: Int {
        AppConfiguration.DailyLimit.minimumMinutes
    }
}

enum OnboardingDurationFormatter {
    nonisolated static func string(
        minutes totalMinutes: Int,
        emptyPlaceholder: String? = nil
    ) -> String {
        guard totalMinutes > 0 else {
            return emptyPlaceholder ?? "0m"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        guard hours > 0 else {
            return "\(minutes)m"
        }

        return String(format: "%dh %02dm", hours, minutes)
    }
}

enum OnboardingCardDurationFormatter {
    nonisolated static func string(minutes totalMinutes: Int) -> String {
        let safeMinutes = max(0, totalMinutes)
        let hours = safeMinutes / 60
        let minutes = safeMinutes % 60
        return String(format: "%dh\n%02dm", hours, minutes)
    }
}

enum OnboardingYearDurationFormatter {
    nonisolated static func string(minutes totalMinutes: Int) -> String {
        let totalHours = max(0, totalMinutes) / 60
        let days = totalHours / 24
        let hours = totalHours % 24
        return String(format: "%dd\n%dh", days, hours)
    }
}

enum OnboardingSavingsDurationFormatter {
    nonisolated static func string(minutes totalMinutes: Int) -> String {
        let safeMinutes = max(0, totalMinutes)
        let totalHours = safeMinutes / 60

        if totalHours >= 24 {
            let days = totalHours / 24
            let hours = totalHours % 24
            return String(format: "%dd\n%dh", days, hours)
        }

        let minutes = safeMinutes % 60
        return String(format: "%dh\n%02dm", totalHours, minutes)
    }
}

enum OnboardingAnnualSavingsCalculator {
    nonisolated static func minutes(
        annualTotalMinutes: Int,
        recentDailyAverageMinutes: Int,
        availableDayCount: Int,
        dailyLimitMinutes: Int
    ) -> Int {
        let annualBaseline = availableDayCount
            >= OnboardingProjectionRules.annualDayCount
            ? annualTotalMinutes
            : recentDailyAverageMinutes
                * OnboardingProjectionRules.annualDayCount
        let limitedAnnualTotal = max(0, dailyLimitMinutes)
            * OnboardingProjectionRules.annualDayCount
        return max(0, annualBaseline - limitedAnnualTotal)
    }
}

struct OnboardingInsightCard: View {
    let value: String
    let primaryCaption: OnboardingInsightCaption
    let secondaryCaption: OnboardingInsightCaption
    var horizontalPadding: CGFloat = 28


    var body: some View {
        ZStack {
            VStack(spacing: -12) {
                ForEach(timeLines.indices, id: \.self) { index in
                    Text(timeLines[index])
                        .font(.system(
                            size: 88,
                            weight: .bold,
                            design: .rounded
                        ))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(primaryColor)
            .offset(y: -22)

            VStack {
                Spacer()

                VStack(spacing: 1) {
                    primaryCaption.text
                    secondaryCaption.text
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryColor)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 18)
        .glassEffect(.clear, in: .rect(cornerRadius: 36))
        .shadow(
            color: MujoTheme.brandAccent.opacity(0.20),
            radius: 16,
            y: 10
        )
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 32)
    }

    private var primaryColor: Color {
        MujoTheme.brandAccent
    }

    private var timeLines: [String] {
        value.split(separator: "\n").map(String.init)
    }

}

struct OnboardingInsightCaption {
    let leading: String
    let emphasis: String
    let trailing: String

    init(
        _ leading: String = "",
        emphasis: String = "",
        trailing: String = ""
    ) {
        self.leading = leading
        self.emphasis = emphasis
        self.trailing = trailing
    }

    var text: Text {
        let emphasizedText = Text(verbatim: emphasis)
            .font(MujoTheme.semiboldItalicFont(
                size: OnboardingTypography.descriptive,
                relativeTo: .body
            ))

        return Text("\(leading)\(emphasizedText)\(trailing)")
            .font(MujoTheme.italicFont(
                size: OnboardingTypography.descriptive,
                relativeTo: .body
            ))
    }
}

struct OnboardingSavingsCard: View {
    let annualSavingsMinutes: Int
    let page: Int
    var horizontalPadding: CGFloat = 28

    var body: some View {
        switch page {
        case 0:
            savingsCard(
                value: OnboardingCardDurationFormatter.string(
                    minutes: dailySavingsMinutes
                ),
                period: "every day"
            )
        case 1:
            savingsCard(
                value: OnboardingCardDurationFormatter.string(
                    minutes: weeklySavingsMinutes
                ),
                period: "every week"
            )
        default:
            savingsCard(
                value: OnboardingSavingsDurationFormatter.string(
                    minutes: annualSavingsMinutes
                ),
                period: "over the next year"
            )
        }
    }

    private var dailySavingsMinutes: Int {
        Int((Double(annualSavingsMinutes) / 365).rounded())
    }

    private var weeklySavingsMinutes: Int {
        dailySavingsMinutes * 7
    }

    private func savingsCard(value: String, period: String) -> some View {
        OnboardingInsightCard(
            value: value,
            primaryCaption: .init("you could ", emphasis: "reclaim"),
            secondaryCaption: .init(
                "screen-free time ",
                emphasis: period
            ),
            horizontalPadding: horizontalPadding
        )
    }
}

// This model lives in the report process in production. It does not export
// usage values or readiness through App Groups.
@MainActor
final class ReportContentLoader<Value>: ObservableObject {
    enum State {
        case loading
        case loaded(Value)
        case noData
        case timedOut
    }

    @Published private(set) var state: State = .loading
    private let operation: () async -> Value?
    private let timeout: Duration
    private var work: Task<Void, Never>?
    private var deadline: Task<Void, Never>?

    init(timeout: Duration = .seconds(15), operation: @escaping () async -> Value?) {
        self.timeout = timeout
        self.operation = operation
    }

    func start() {
        guard work == nil else { return }
        let operation = operation
        work = Task { [weak self] in
            let value = await operation()
            guard !Task.isCancelled else { return }
            self?.complete(value)
        }
        let timeout = timeout
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: timeout) }
            catch { return }
            guard let self, case .loading = self.state else { return }
            self.state = .timedOut
        }
    }

    private func complete(_ value: Value?) {
        deadline?.cancel()
        // A slow valid result may replace the timeout fallback. A deadline
        // never replaces content that has already loaded.
        state = value.map(State.loaded) ?? .noData
    }

    deinit {
        work?.cancel()
        deadline?.cancel()
    }
}
