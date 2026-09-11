//
//  TotalActivityView.swift
//  ReportMonitor
//
//  Created by Lopk Art on 06/09/2026.
//

import SwiftUI

struct TotalActivityView: View {
    let configuration: TodayActivityConfiguration

    private let sharedDefaults = UserDefaults(
        suiteName: AppConfiguration.appGroupIdentifier
    )

    var body: some View {
        Group {
            switch configuration.dataState {
            case .available:
                TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                    remainingTimeView
                }
            case .noData:
                noDataView
            }
        }
        .task {
            markActivityReportAsReady()
        }
    }

    private var remainingTimeView: some View {
        VStack {
            Text("Remaining")
                .font(MujoTheme.mediumFont(
                    size: 12,
                    relativeTo: .caption2
                ))
                .textCase(.uppercase)
                .foregroundStyle(
                    MujoTheme.glassAccent.opacity(
                        MujoTheme.secondaryTextOpacity
                    )
                )

            GlassText(value: remainingTime.formatted())
        }
        .padding()
    }

    private var noDataView: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .font(.title2)

            Text("No Screen Time data yet")
                .font(.headline)

            Text(
                "If you've already used this iPhone today, make sure "
                    + "App & Website Activity is turned on in Settings."
            )
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(MujoTheme.glassAccent)
        .padding(.horizontal, 24)
    }

    private var remainingTime: TimeInterval {
        let previewLimit = sharedDefaults?.double(
            forKey: AppConfiguration.DefaultsKey.previewDailyLimit
        ) ?? 0
        let storedLimit = sharedDefaults?.double(
            forKey: AppConfiguration.DefaultsKey.dailyLimit
        ) ?? 0

        return RemainingTimeCalculator.calculate(
            usedTime: configuration.usedTime,
            previewLimit: previewLimit,
            storedLimit: storedLimit
        )
    }

    private func markActivityReportAsReady() {
        guard let requestID = sharedDefaults?.string(
            forKey: AppConfiguration.DefaultsKey.activityReportRequestID
        ) else {
            return
        }

        sharedDefaults?.set(
            requestID,
            forKey: AppConfiguration.DefaultsKey.readyActivityReportRequestID
        )
    }
}

#Preview {
    TotalActivityView(
        configuration: TodayActivityConfiguration(
            usedTime: 37 * 60,
            dataState: .available
        )
    )
}
