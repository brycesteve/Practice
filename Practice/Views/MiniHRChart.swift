//
//  MiniHRChart.swift
//  Practice
//
//  Created by Steve Bryce on 17/08/2025.
//
import SwiftUI
import Charts


struct MiniHRChart: View {
    let hrData: [(Date, Double)]
    
    
    
    var body: some View {
        if hrData.isEmpty {
            Text("No HR data for this phase")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Chart {
                ForEach(hrData, id: \.0) { point in
                    LineMark(
                        x: .value("Time", point.0),
                        y: .value("HR", point.1)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.monotone)
                }
            }
            .chartYAxisLabel("HR")
            .chartXAxis(.hidden)
            .padding(.horizontal)
        }
    }
}
