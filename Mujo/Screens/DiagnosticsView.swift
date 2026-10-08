#if DEBUG
import SwiftUI
import UIKit
import UserNotifications

struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var screenTime: ScreenTimeManager

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = true

    @State private var events: [DiagnosticEvent] = []
    @State private var monitoringSummary = "checking…"
    @State private var roundTripWorks = false
    @State private var notificationStatus = "checking…"
    @State private var isResetting = false

    var body: some View {
        NavigationStack {
            List {
                Section("Shared storage") {
                    diagnosticRow(
                        "App Group container",
                        value: appGroupContainerIsAvailable
                            ? "available"
                            : "unavailable"
                    )
                    diagnosticRow(
                        "Read/write test",
                        value: roundTripWorks
                            ? "passed"
                            : "failed"
                    )
                }

                Section("Measurement") {
                    diagnosticRow("Monitoring", value: monitoringSummary)
                    diagnosticRow(
                        "Started",
                        value: formattedTimestamp(
                            defaults?.double(
                                forKey: AppConfiguration.DefaultsKey
                                    .usageMonitoringStartedAt
                            ) ?? 0
                        )
                    )
                    diagnosticRow(
                        "Stored used",
                        value: TimeInterval(
                            defaults?.double(
                                forKey: AppConfiguration.DefaultsKey
                                    .estimatedUsedTime
                            ) ?? 0
                        ).formatted()
                    )
                    diagnosticRow(
                        "Has checkpoint",
                        value: defaults?.bool(
                            forKey: AppConfiguration.DefaultsKey
                                .hasUsageCheckpoint
                        ) == true ? "yes" : "no"
                    )
                    diagnosticRow(
                        "Checkpoint time zone",
                        value: defaults?.string(
                            forKey: AppConfiguration.DefaultsKey
                                .lastCheckpointTimeZoneIdentifier
                        ) ?? "—"
                    )
                    diagnosticRow(
                        "Current time zone",
                        value: TimeZone.autoupdatingCurrent.identifier
                    )
                }

                Section("Reports and notifications") {
                    diagnosticRow(
                        "Onboarding report",
                        value: "Rendered privately by iOS"
                    )
                    diagnosticRow(
                        "Limit editor report",
                        value: "Rendered privately by iOS"
                    )
                    diagnosticRow(
                        "Notifications",
                        value: notificationStatus
                    )
                }

                Section("Widget") {
                    diagnosticRow(
                        "Last reload request",
                        value: formattedTimestamp(
                            defaults?.double(
                                forKey: AppConfiguration.DefaultsKey
                                    .lastWidgetReloadRequestedAt
                            ) ?? 0
                        )
                    )
                    diagnosticRow(
                        "Last timeline",
                        value: formattedTimestamp(
                            defaults?.double(
                                forKey: AppConfiguration.DefaultsKey
                                    .lastWidgetTimelineAt
                            ) ?? 0
                        )
                    )
                }

                Section("Events") {
                    if events.isEmpty {
                        Text("No diagnostic events yet.")
                    } else {
                        ForEach(events.reversed()) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.source.uppercased())
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tint)
                                Text(event.message)
                                    .font(.callout.monospaced())
                                    .textSelection(.enabled)
                                Text(event.date.formatted(
                                    date: .abbreviated,
                                    time: .standard
                                ))
                                .font(.caption)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                Section("Actions") {
                    Button("Copy diagnostics") {
                        UIPasteboard.general.string = exportedDiagnostics
                    }

                    Button("Clear diagnostic log") {
                        DiagnosticsStore.clear(defaults: defaults)
                        reload()
                    }

                    Button("Reset measurement test", role: .destructive) {
                        resetMeasurement(forceNoHistory: false)
                    }
                    .disabled(isResetting)

                    Button("Test onboarding without history") {
                        resetMeasurement(forceNoHistory: true)
                    }
                    .disabled(isResetting)
                }
            }
            .navigationTitle("Diagnostics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await refresh()
            }
            .safeAreaInset(edge: .bottom) {
                Text(buildDescription)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
        }
    }

    private var defaults: UserDefaults? {
        screenTime.diagnosticDefaults
    }

    private var appGroupContainerIsAvailable: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier:
                AppConfiguration.appGroupIdentifier
        ) != nil
    }

    private func testSharedDefaultsRoundTrip() -> Bool {
        guard let defaults else { return false }
        let key = "mujo.debug.roundTrip"
        let value = UUID().uuidString
        defaults.set(value, forKey: key)
        defer { defaults.removeObject(forKey: key) }
        return defaults.string(forKey: key) == value
    }

    private var exportedDiagnostics: String {
        let header = [
            "Mujo diagnostics",
            "App Group: \(appGroupContainerIsAvailable)",
            "Monitoring: \(monitoringSummary)",
            "Used: \(screenTime.usageSnapshot.estimatedUsedTime)",
            "Time zone: \(TimeZone.autoupdatingCurrent.identifier)",
            "Notifications: \(notificationStatus)",
            buildDescription
        ]
        let eventLines = events.map {
            "\($0.date.ISO8601Format()) [\($0.source)] \($0.message)"
        }
        return (header + eventLines).joined(separator: "\n")
    }

    private var buildDescription: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "—"
        return "Version \(version) (\(build)) · DEBUG"
    }

    @ViewBuilder
    private func diagnosticRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formattedTimestamp(_ timestamp: TimeInterval) -> String {
        guard timestamp > 0 else { return "—" }
        return Date(timeIntervalSince1970: timestamp).formatted(
            date: .abbreviated,
            time: .standard
        )
    }

    private func reload() {
        events = DiagnosticsStore.load(defaults: defaults)
    }

    private func refresh() async {
        monitoringSummary = await screenTime.monitoringDiagnosticsSummary()
        let settings = await UNUserNotificationCenter.current()
            .notificationSettings()
        notificationStatus = String(describing: settings.authorizationStatus)
        roundTripWorks = testSharedDefaultsRoundTrip()
        reload()
    }

    private func resetMeasurement(forceNoHistory: Bool) {
        guard !isResetting else { return }
        isResetting = true
        Task {
            if forceNoHistory {
                DiagnosticsScenarioStore.scheduleNoHistoryOnboarding()
            }
            await screenTime.resetMeasurementForDiagnostics()
            UserDefaults.standard.removeObject(
                forKey: TimeDialPreferences.hasUsedCenteredHintKey
            )
            hasCompletedOnboarding = false
            isResetting = false
            dismiss()
        }
    }
}
#endif
