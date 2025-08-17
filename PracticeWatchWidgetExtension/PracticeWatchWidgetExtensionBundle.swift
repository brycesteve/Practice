//
//  PracticeWatchWidgetExtensionBundle.swift
//  PracticeWatchWidgetExtension
//
//  Created by Steve Bryce on 06/08/2025.
//

import WidgetKit
import SwiftUI

@main
struct PracticeWatchWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        ReadinessWidget()
    }
}

#Preview(as: .accessoryRectangular) {
    ReadinessWidget()
}
timeline: {
    ReadinessEntry(date: .now, readinessScore: 75, isStale: false)
}
