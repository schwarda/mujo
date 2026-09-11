//
//  TotalActivityReport.swift
//  ReportMonitor
//
//  Created by Lopk Art on 06/09/2026.
//

import DeviceActivity
import ExtensionKit
import SwiftUI

extension DeviceActivityReport.Context {
    static let mujoToday = Self(MujoShared.Reporting.todayContextName)
}

struct TotalActivityReport: nonisolated DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .mujoToday

    let content: (TodayActivityConfiguration) -> TotalActivityView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> TodayActivityConfiguration {
        var usedTime: TimeInterval = 0
        var hasActivityData = false

        for await activityData in data {
            hasActivityData = true

            for await segment in activityData.activitySegments {
                usedTime += segment.totalActivityDuration
            }
        }

        return TodayActivityConfiguration(
            usedTime: usedTime,
            dataState: hasActivityData ? .available : .noData
        )
    }
}
