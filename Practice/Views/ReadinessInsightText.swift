//
//  ReadinessInsightText.swift
//  Practice
//
//  Created by Steve Bryce on 17/08/2025.
//

import SwiftUI

struct ReadinessInsightText: View {
    @Environment(ReadinessManager.self) private var readiness
    
    func insight() -> String {
            if readiness.readinessScore < 40 {
                if readiness.hrvDelta < 0 {
                    return "Low recovery due to reduced HRV"
                } else if readiness.sleepDelta < 0 {
                    return "Low recovery from short sleep"
                } else {
                    return "Low recovery from accumulated fatigue"
                }
            } else if readiness.readinessScore > 70 {
                return "Strong recovery — well done"
            } else {
                return "Moderate recovery — steady training recommended"
            }
    }
    
    var body: some View {
        Text(insight())
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.top, 4)
    }
}
