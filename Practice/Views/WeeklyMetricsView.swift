//
//  WeeklyWorkRestView.swift
//  Practice
//
//  Created by Steve Bryce on 02/08/2025.
//

import SwiftUI
import HealthKit
import Charts
import OSLog

struct WeeklyMetricsView: View {
    var practices: [HKWorkout]
    
    @State private var weeklyMetrics: [WeeklyMetrics] = []
    @State private var smoothedMetrics: [WeeklyMetrics] = []

    var body: some View {
        VStack(alignment: .leading) {
            Text("Weekly Metrics")
                .font(.headline)
            
            TonnageWorkRestView(
                xValues: weeklyMetrics.map { $0.weekStart },
                tonnage: weeklyMetrics.map { Double($0.tonnage) },
                ratio: smoothedMetrics.map { $0.ratio }
            )
            .frame(height: 200)

        }
        .onChange(of: practices, initial: true) {
            let raw = practices.calculateWeeklyMetrics()
            withAnimation(.easeInOut(duration: 0.6)) {
                weeklyMetrics = raw
                smoothedMetrics = smoothedWeeklyMetrics(raw)

            }
        }
    }
    
    func smoothedWeeklyMetrics(_ weekly: [WeeklyMetrics], window: Int = 2) -> [WeeklyMetrics] {
        guard !weekly.isEmpty else { return [] }
        
        var smoothed: [WeeklyMetrics] = []
        
        for i in 0..<weekly.count {
            let start = max(0, i - (window - 1))
            let slice = weekly[start...i]
            let avgRatio = slice.map { $0.ratio }.reduce(0, +) / Double(slice.count)
            
            var item = weekly[i]
            // Replace raw ratio with smoothed ratio
            item = WeeklyMetrics(
                weekStart: item.weekStart,
                work: avgRatio * (item.work + item.rest), // back-calculate work/rest based on avg
                rest: (1 - avgRatio) * (item.work + item.rest),
                tonnage: item.tonnage,
                changeFromLast: i > 0 ? avgRatio - smoothed.last!.ratio : nil
            )
            smoothed.append(item)
        }
        
        return smoothed
    }


}
