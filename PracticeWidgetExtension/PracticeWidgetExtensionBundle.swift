//
//  PracticeWidgetExtensionBundle.swift
//  PracticeWidgetExtension
//
//  Created by Steve Bryce on 10/08/2025.
//

import WidgetKit
import SwiftUI

@main
struct PracticeWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        ReadinessWidget()
    }
}

#Preview(as: .systemSmall) {
    ReadinessWidget()
}
timeline: {
    ReadinessEntry(date: .now, readinessScore: 80, isStale: false)
}


