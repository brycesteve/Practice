
//
//  SummaryCardView.swift
//  Practice
//
//  Created by Steve Bryce on 18/08/2025.
//
import SwiftUI

struct PracticeDetailSummaryCardView: View {
    var practice: PracticeDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack(spacing: 20) {
                PracticeDetailSummaryMetricView(
                    title: "Duration",
                    value: Duration.seconds(practice.duration)
                        .formatted(.time(pattern: .hourMinuteSecond)),
                    color: .yellow,
                    icon: "clock.fill"
                )
                PracticeDetailSummaryMetricView(
                    title: "Energy",
                    value: "\(practice.totalActiveEnergy.formatted(.number.precision(.fractionLength(0)))) kcal",
                    color: .pink,
                    icon: "flame.fill"
                )
                PracticeDetailSummaryMetricView(
                    title: "Avg HR",
                    value: "\(practice.avgHR.formatted(.number.precision(.fractionLength(0)))) bpm",
                    color: .red,
                    icon: "heart.fill"
                )
            }
            WorkRestSummaryView(
                workDuration: practice.workToRestRatio.workTime,
                restDuration: practice.workToRestRatio.restTime
            )
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }
}
