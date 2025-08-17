//
//  ReadinessStackedBarView.swift
//  Practice
//
//  Created by Steve Bryce on 16/08/2025.
//


import SwiftUI

struct ReadinessStackedBarView: View {
    @Environment(ReadinessManager.self) var readinessManager

    // Compute weighted contributions (0–1)
    var contributions: [(name: String, value: Double, color: Color)] {
        let hrv = HRVMetric()
        let hrvC = hrv.calculate(readinessManager: readinessManager) * hrv.weight
        let rhr = RHRMetric()
        let rhrC = rhr.calculate(
            readinessManager: readinessManager
        ) * rhr.weight
        let sleepS = SleepMetric()
        let sleepC = sleepS.calculate(readinessManager: readinessManager) * sleepS.weight
        let strain = StrainMetric()
        let strainC = (
            (100 - strain.calculate(readinessManager: readinessManager)
        )) * 0.10 // invert penalty
        let consistency = SleepConsistencyMetric()
        let consistencyC = consistency.calculate(
            readinessManager: readinessManager
        ) * consistency.weight
        
        let sleepQ = SleepQualityMetric()
        let sleepQualityC = sleepQ.calculate(
            readinessManager: readinessManager
        ) * sleepQ.weight
        let hrvTrnd = HRVTrendMetric()
        let hrvTrendC = hrvTrnd.calculate(
            readinessManager: readinessManager
        ) * hrvTrnd.weight
        let strainR = StrainRatioMetric()
        let strainRatioC = strainR.calculate(
            readinessManager: readinessManager
        ) * strainR.weight
        
        return [
            ("HRV", hrvC, .green),
            ("RHR", rhrC, .blue),
            ("Sleep", sleepC, .yellow),
            ("Strain", strainC, .red),
            ("Consistency", consistencyC, .purple),
            ("Sleep Quality", sleepQualityC, .teal),
            ("HRV Trend", hrvTrendC, .orange),
            ("Strain Ratio", strainRatioC, .pink)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recovery Breakdown")
                .font(.headline)
                .foregroundStyle(.primary)
            
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(contributions, id: \.name) { metric in
                        Rectangle()
                            .fill(metric.color)
                            .frame(width: CGFloat(metric.value / 100) * geo.size.width)
                            .animation(.easeInOut(duration: 0.8), value: metric.value)
                    }
                }
                .frame(height: 20)
                .cornerRadius(6)
            }
            .frame(height: 20)

            // Optional legend
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 8),
                    count: 3
                ),
                alignment: .leading, spacing: 4
            ) {
                ForEach(contributions, id: \.name) { metric in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(metric.color)
                            .frame(width: 10, height: 10)
                        Text(metric.name)
                            .font(.caption2)
                    }
                }
            }
            
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.8), value: contributions.map { $0.value })
    }
}
