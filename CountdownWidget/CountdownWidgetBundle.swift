//
//  CountdownWidgetBundle.swift
//  CountdownWidget
//
//  Created by Lopk Art on 09/09/2026.
//

import WidgetKit
import SwiftUI

@main
struct CountdownWidgetBundle: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
        CountdownWidgetControl()
        CountdownWidgetLiveActivity()
    }
}
