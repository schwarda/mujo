//
//  ReportMonitor.swift
//  ReportMonitor
//
//  Created by Lopk Art on 06/09/2026.
//

import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct ReportMonitor: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { configuration in
            TotalActivityView(configuration: configuration)
        }
    }
}
