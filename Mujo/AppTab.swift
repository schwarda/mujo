//
//  Tabs.swift
//  Mujo
//
//  Created by Aikari Studio on 05/09/2026.
//

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case history

    var id: Self { self }

    var title: String {
        switch self {
            case .home: "Home"
            case .history: "Past days"
        }
    }

    var systemImage: String {
        switch self {
            case .home: "house.fill"
            case .history: "calendar"
        }
    }
}
