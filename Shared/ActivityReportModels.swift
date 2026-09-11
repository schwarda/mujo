//
//  ActivityReportModels.swift
//  Mujo
//

import Foundation

enum TodayActivityDataState {
    case available
    case noData
}

struct TodayActivityConfiguration {
    let usedTime: TimeInterval
    let dataState: TodayActivityDataState
}
