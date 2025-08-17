//
//  PracticeDetailStatsView.swift
//  Practice
//
//  Created by Steve Bryce on 17/08/2025.
//

import SwiftUI

struct PracticeDetailStatsView: View {
    @State var practice: PracticeDetailViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SummaryMetricView(
                    icon: "clock",
                    title: "Duration",
                    value: Duration
                        .seconds(practice.duration)
                        .formatted(.time(pattern: .hourMinuteSecond)),
                    color: .purple
                )
                SummaryMetricView(
                    icon: "flame.fill",
                    title: "Energy",
                    value: "\(practice.totalActiveEnergy.formatted(.number.precision(.fractionLength(0))))kcal",
                    color: .orange
                )
            }
            HStack {
                SummaryMetricView(
                    icon: "heart.fill",
                    title: "Avg HR",
                    value: "\(practice.avgHR.formatted(.number.precision(.fractionLength(0))))bpm",
                    color: .red
                )
                SummaryMetricView(
                    icon: "scalemass.fill",
                    title: "Tonnage",
                    value: "\(practice.tonnage.formatted(.number.precision(.fractionLength(0))))kg",
                    color: .green
                )
            }
            WorkRestSummaryView(
                workDuration: practice.workToRestRatio.workTime,
                restDuration: practice.workToRestRatio.restTime
            )
            .glassEffect(.regular, in: .rect(cornerRadius: 8))
        }
        .cleanListItem()
    }
}
