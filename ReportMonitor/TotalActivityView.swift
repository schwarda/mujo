//
//  TotalActivityView.swift
//  ReportMonitor
//
//  Created by Lopk Art on 06/09/2026.
//

import SwiftUI

struct TotalActivityView: View {
    let configuration: TodayActivityConfiguration

    private let defaultDailyLimit: TimeInterval = 5 * 60 * 60
    private let sharedDefaults = UserDefaults(
        suiteName: "group.AikariStudio.Mujo.shared"
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
    }

    private var remainingTimeView: some View {
        VStack {
            Text("Remaining")
                .font(.custom(
                    "AvenirNext-Medium",
                    size: 12,
                    relativeTo: .caption2
                ))
                .textCase(.uppercase)
                .foregroundStyle(accentColor.opacity(0.72))

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
        .foregroundStyle(accentColor)
        .padding(.horizontal, 24)
    }

    private var accentColor: Color {
        Color(red: 0.96, green: 0.62, blue: 0.72)
    }

    private var remainingTime: TimeInterval {
        let previewLimit = sharedDefaults?.double(
            forKey: "previewDailyLimitSeconds"
        ) ?? 0
        let storedLimit = sharedDefaults?.double(
            forKey: "dailyLimitSeconds"
        ) ?? 0
        let dailyLimit: TimeInterval

        if previewLimit > 0 {
            dailyLimit = previewLimit
        } else if storedLimit > 0 {
            dailyLimit = storedLimit
        } else {
            dailyLimit = defaultDailyLimit
        }

        return max(0, dailyLimit - configuration.usedTime)
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
