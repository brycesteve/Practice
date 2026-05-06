//
//  BodyStatsView.swift
//  Practice
//
//  Created by Steve Bryce on 29/04/2026.
//


// BodyStatsView.swift — iOS
// Charts for body weight and VO2Max history pulled from HealthKit.

import SwiftUI
import Charts

struct BodyStatsView: View {
    @State private var weightHistory: [(date: Date, kg: Double)] = []
    @State private var vo2History:    [(date: Date, value: Double)] = []
    @State private var isLoading = true
    @State private var userAge: Int? = nil
    @State private var userSex: HealthKitManager.BiologicalSex = .notSet

    private var latestWeight: Double? { weightHistory.last?.kg }
    private var latestVO2:    Double? { vo2History.last?.value  }

    private var weightChange: Double? {
        guard weightHistory.count >= 2 else { return nil }
        return weightHistory.last!.kg - weightHistory.first!.kg
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading…")
                            .padding(40)
                    } else {
                        weightSection
                        vo2Section
                    }
                }
                .padding()
            }
            .navigationTitle("Body Stats")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadData() }
            .refreshable { await loadData() }
        }
    }

    // MARK: - Weight section

    @ViewBuilder
    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body Weight")
                        .font(.headline)
                    if let kg = latestWeight {
                        Text(String(format: "%.1f kg", kg))
                            .font(.largeTitle.bold())
                        if let change = weightChange {
                            Label(
                                String(format: "%+.1f kg (90 days)", change),
                                systemImage: change <= 0 ? "arrow.down.right" : "arrow.up.right"
                            )
                            .font(.caption)
                            .foregroundStyle(change <= 0 ? .green : .orange)
                        }
                    } else {
                        Text("No data")
                            .font(.title2).foregroundStyle(.secondary)
                        Text("Log weight in the Health app or on your Watch.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "scalemass.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.teal.opacity(0.8))
            }

            if !weightHistory.isEmpty {
                // 7-day rolling average overlay
                let smoothed = rollingAverage(weightHistory, window: 7)

                Chart {
                    ForEach(weightHistory, id: \.date) { point in
                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("kg", point.kg)
                        )
                        .symbolSize(20)
                        .foregroundStyle(Color.teal.opacity(0.5))
                    }

                    ForEach(smoothed, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("7d avg", point.kg)
                        )
                        .foregroundStyle(Color.teal)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)
                    }
                }
                .frame(height: 180)
                .chartYScale(domain: weightYDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 14)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }

                HStack {
                    Circle().fill(Color.teal.opacity(0.4)).frame(width: 8, height: 8)
                    Text("Daily log").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Rectangle().fill(Color.teal).frame(width: 16, height: 2)
                    Text("7-day avg").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - VO2Max section

    @ViewBuilder
    private var vo2Section: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VO₂ Max")
                        .font(.headline)
                    if let vo2 = latestVO2 {
                        Text(String(format: "%.1f", vo2))
                            .font(.largeTitle.bold())
                        Text("mL/kg/min · " + vo2Label(vo2))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No data")
                            .font(.title2).foregroundStyle(.secondary)
                        Text("Complete an outdoor run or walk with your Watch to record VO₂ Max.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "lungs.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green.opacity(0.8))
            }

            if !vo2History.isEmpty {
                let domain = vo2YDomain
                Chart {
                    ForEach(vo2History, id: \.date) { point in
                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            yStart: .value("Min", domain.lowerBound),
                            yEnd: .value("VO₂ Max", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green.opacity(0.3), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("VO₂ Max", point.value)
                        )
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)
                        .symbol(.circle)
                        .symbolSize(25)
                    }
                }
                .frame(height: 160)
                .chartYScale(domain: vo2YDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 21)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }

                // Category reference lines
                vo2CategoryAnnotations
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var vo2CategoryAnnotations: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reference ranges (\(ageGroupLabel))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack(spacing: 16) {
                ForEach(vo2Categories, id: \.label) { cat in
                    HStack(spacing: 4) {
                        Circle().fill(cat.color).frame(width: 6, height: 6)
                        Text(cat.label).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Load data

    private func loadData() async {
        isLoading = true
        async let weight = (try? HealthKitManager.shared.fetchBodyMassHistory(days: 90)) ?? []
        async let vo2    = (try? HealthKitManager.shared.fetchVO2MaxHistory(days: 180)) ?? []
        let (w, v) = await (weight, vo2)
        weightHistory = w
        vo2History    = v
        userAge = try? HealthKitManager.shared.fetchAge()
        userSex = (try? HealthKitManager.shared.fetchBiologicalSex()) ?? .notSet
        isLoading     = false
    }

    // MARK: - Helpers

    private func rollingAverage(_ data: [(date: Date, kg: Double)], window: Int) -> [(date: Date, kg: Double)] {
        guard data.count >= window else { return data }
        return data.indices.compactMap { i in
            guard i >= window - 1 else { return nil }
            let slice = data[(i - window + 1)...i]
            let avg   = slice.map(\.kg).reduce(0, +) / Double(window)
            return (date: data[i].date, kg: avg)
        }
    }

    private var weightYDomain: ClosedRange<Double> {
        guard !weightHistory.isEmpty else { return 60...100 }
        let values = weightHistory.map(\.kg)
        let lo = (values.min() ?? 60) - 2
        let hi = (values.max() ?? 100) + 2
        return lo...hi
    }

    private var vo2YDomain: ClosedRange<Double> {
        guard !vo2History.isEmpty else { return 30...60 }
        let values = vo2History.map(\.value)
        let lo = max(20, (values.min() ?? 30) - 3)
        let hi = (values.max() ?? 60) + 3
        return lo...hi
    }

    // MARK: - VO2Max ranges by age and sex
    // Source: ACSM's Guidelines for Exercise Testing and Prescription
    // Thresholds: veryPoor/poor/fair/good/excellent upper bounds
    
    private var vo2Thresholds: (veryPoor: Double, poor: Double, fair: Double, good: Double, excellent: Double) {
        let age  = userAge ?? 35
        let male = userSex != .female   // treat other/notSet as male (conservative)
        
        switch (male, age) {
            // Male
        case (true, ..<30):    return (31, 37, 43, 52, 60)
        case (true, 30..<40):  return (30, 35, 41, 49, 56)
        case (true, 40..<50):  return (27, 33, 38, 46, 53)
        case (true, 50..<60):  return (24, 29, 35, 42, 49)
        case (true, 60..<70):  return (21, 26, 32, 38, 45)
        case (true, _):        return (18, 23, 28, 34, 41)
            // Female
        case (false, ..<30):   return (23, 28, 34, 41, 49)
        case (false, 30..<40): return (22, 27, 32, 39, 46)
        case (false, 40..<50): return (20, 24, 29, 36, 43)
        case (false, 50..<60): return (18, 22, 27, 33, 40)
        case (false, 60..<70): return (16, 20, 24, 30, 36)
        case (false, _):       return (14, 17, 21, 26, 32)
        }
    }
    
    private var ageGroupLabel: String {
        guard let age = userAge else { return "age unknown" }
        let sexLabel = userSex == .female ? "female" : "male"
        let decade   = (age / 10) * 10
        return "\(sexLabel) \(decade)–\(decade + 9)"
    }
    
    private func vo2Label(_ vo2: Double) -> String {
        let t = vo2Thresholds
        switch vo2 {
        case ..<t.veryPoor:  return "Very Poor"
        case ..<t.poor:      return "Poor"
        case ..<t.fair:      return "Fair"
        case ..<t.good:      return "Good"
        case ..<t.excellent: return "Excellent"
        default:             return "Superior"
        }
    }
    
    private struct VO2Category { let label: String; let color: Color }
    private var vo2Categories: [VO2Category] {
        let t = vo2Thresholds
        return [
            VO2Category(label: "Very Poor (<\(Int(t.veryPoor)))", color: .red),
            VO2Category(label: "Poor (\(Int(t.veryPoor))–\(Int(t.poor)))",  color: .orange),
            VO2Category(label: "Fair (\(Int(t.poor))–\(Int(t.fair)))",      color: .yellow),
            VO2Category(label: "Good (\(Int(t.fair))–\(Int(t.good)))",      color: .blue),
            VO2Category(label: "Excellent (\(Int(t.good))+)",                    color: .green),
        ]
    }
}
