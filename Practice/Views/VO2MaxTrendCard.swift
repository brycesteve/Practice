//
//  VO2MaxTrendCard.swift
//  Practice
//
//  Created by Steve Bryce on 17/08/2025.
//

import SwiftUI
import Charts
import HealthKit

struct VO2MaxTrendCard: View {
    @Environment(HistoryManager.self) private var history
    @State private var samples: [HKQuantitySample] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lungs.fill")
                    .foregroundStyle(.blue)
                Text("VO₂ Max Trend")
                    .font(.headline)
            }
            
            if samples.isEmpty {
                Text("No recent VO₂ Max data")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(rollingTrend, id: \.0) { (date, value) in
                        LineMark(
                            x: .value("Date", date),
                            y: .value("VO₂ Max", value)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.monotone)
                        
                        PointMark(
                            x: .value("Date", date),
                            y: .value("VO₂ Max", value)
                        )
                        .symbolSize(20)
                        .foregroundStyle(.blue)
                    }
                }
                .chartYAxisLabel("ml/kg/min")
                .frame(height: 120)
            }
        }
        
        .frame(maxWidth: .infinity)
        .task {
            samples = await history.fetchVO2MaxSamples(limit: 30)
        }
    }
    
    /// Calculate a 7-day rolling average
    private var rollingTrend: [(Date, Double)] {
        let values = samples.map {
            ($0.startDate, $0.quantity.doubleValue(for: .init(from: "ml/kg*min")))
        }
        guard !values.isEmpty else { return [] }
        
        var trend: [(Date, Double)] = []
        let window = 3   // rolling window (3 samples smoothing)
        
        for i in values.indices {
            let slice = values[max(0, i-window)...i]
            let avg = slice.map { $0.1 }.reduce(0, +) / Double(slice.count)
            trend.append((values[i].0, avg))
        }
        return trend.sorted { $0.0 < $1.0 }
    }
}
