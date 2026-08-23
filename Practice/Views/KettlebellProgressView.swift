// KettlebellProgressView.swift — iOS
// Tracks weight used for swings and TGUs, shows progress toward S&S Simple milestone,
// and charts weight used over time for each exercise.

import SwiftUI
import Charts
import SwiftData

struct KettlebellProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KettlebellWeightRecord.date, order: .reverse) private var allRecords: [KettlebellWeightRecord]
    @Query private var settingsResults: [AppSettings]
    
    private var settings: AppSettings { settingsResults.first ?? AppSettings() }
    
    private var swingRecords: [KettlebellWeightRecord] { allRecords.filter { $0.exerciseType == .swing } }
    private var tguRecords:   [KettlebellWeightRecord] { allRecords.filter { $0.exerciseType == .tgu   } }
    
    private var swingPB: Double? { swingRecords.max(by: { $0.weightKg < $1.weightKg })?.weightKg }
    private var tguPB:   Double? { tguRecords.max(by:   { $0.weightKg < $1.weightKg })?.weightKg }
    
    private var recentSummaries: [KettlebellSessionSummary] {
        KettlebellSessionSummary.makeSummaries(from: allRecords)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: Milestone progress
                    milestoneCard
                    
                    // MARK: Swing chart
                    exerciseCard(
                        title: "One-Arm Swing",
                        icon: "figure.strengthtraining.functional",
                        records: Array(swingRecords.prefix(30).reversed()),
                        pbKg: swingPB,
                        targetKg: settings.targetSwingWeightKg,
                        color: .orange
                    )
                    
                    // MARK: TGU chart
                    exerciseCard(
                        title: "Turkish Get-Up",
                        icon: "figure.mind.and.body",
                        records: Array(tguRecords.prefix(30).reversed()),
                        pbKg: tguPB,
                        targetKg: settings.targetTGUWeightKg,
                        color: .purple
                    )
                    
                    // MARK: Recent log
                    recentLog
                }
                .padding()
            }
            .navigationTitle("Kettlebell")
        }
    }
    
    // MARK: - Milestone card
    
    private var milestoneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("S&S Simple Progress", systemImage: "flag.checkered")
                .font(.headline)
            
            progressRow(
                label: "Swing PB",
                current: swingPB ?? 0,
                target: settings.targetSwingWeightKg,
                color: .orange
            )
            progressRow(
                label: "TGU PB",
                current: tguPB ?? 0,
                target: settings.targetTGUWeightKg,
                color: .purple
            )
            
            let swingDone = (swingPB ?? 0) >= settings.targetSwingWeightKg
            let tguDone   = (tguPB   ?? 0) >= settings.targetTGUWeightKg
            if swingDone && tguDone {
                Label("S&S Simple achieved! 🏆", systemImage: "trophy.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.yellow)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func progressRow(label: String, current: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(formatWeight(current)) / \(formatWeight(target))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(current, target), total: target)
                .tint(current >= target ? .green : color)
        }
    }
    
    // MARK: - Exercise card with chart
    
    @ViewBuilder
    private func exerciseCard(title: String, icon: String, records: [KettlebellWeightRecord],
                              pbKg: Double?, targetKg: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                Spacer()
                if let pb = pbKg {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("PB").font(.caption2).foregroundStyle(.secondary)
                        Text(formatWeight(pb)).font(.subheadline.bold()).foregroundStyle(color)
                    }
                }
            }
            
            if records.isEmpty {
                Text("No sessions logged yet. Complete a morning workout on the Watch to record weights.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Weight over time chart
                Chart {
                    ForEach(records) { record in
                        LineMark(
                            x: .value("Date", record.date, unit: .day),
                            y: .value("Weight (kg)", record.weightKg)
                        )
                        .symbol(.circle)
                        .foregroundStyle(color.gradient)
                    }
                    // Target line
                    RuleMark(y: .value("Target", targetKg))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.green.opacity(0.7))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Target").font(.system(size: 9)).foregroundStyle(.green)
                        }
                }
                .frame(height: 120)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month())
                    }
                }
                .chartYScale(domain: yDomain(records: records, target: targetKg))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Recent log
    
    private var recentLog: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Sessions")
                .font(.headline)
            
            if recentSummaries.isEmpty {
                Text("No kettlebell sets logged yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(recentSummaries.prefix(10))) { summary in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: summary.exerciseType == .swing ? "figure.strengthtraining.functional" : "figure.mind.and.body")
                            .foregroundStyle(summary.exerciseType == .swing ? .orange : .purple)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(summary.exerciseType.shortName)
                                .font(.subheadline)
                            Text(summary.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(summary.loadBreakdown.map { "\(formatWeight($0.weightKg)) x \($0.sets) sets" }.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatWeight(summary.topWeightKg))
                                .font(.subheadline.bold())
                            Text("\(summary.totalSets) sets · \(summary.totalReps) reps")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helpers
    
    private func yDomain(records: [KettlebellWeightRecord], target: Double) -> ClosedRange<Double> {
        let minVal = (records.min(by: { $0.weightKg < $1.weightKg })?.weightKg ?? 8) - 4
        let maxVal = max(records.max(by: { $0.weightKg < $1.weightKg })?.weightKg ?? target, target) + 4
        return minVal...maxVal
    }
    
    private func formatWeight(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg))kg" : "\(kg)kg"
    }
}

private struct KettlebellSessionSummary: Identifiable {
    let id: String
    let date: Date
    let exerciseType: KettlebellExerciseType
    let totalSets: Int
    let totalReps: Int
    let topWeightKg: Double
    let loadBreakdown: [(weightKg: Double, sets: Int)]
    
    static func makeSummaries(from records: [KettlebellWeightRecord]) -> [KettlebellSessionSummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { record in
            SummaryKey(
                day: calendar.startOfDay(for: record.date),
                exerciseType: record.exerciseType
            )
        }
        
        return grouped.map { key, records in
            let sortedRecords = records.sorted { $0.date < $1.date }
            let loadBreakdown = Dictionary(grouping: records, by: \.weightKg)
                .map { weight, records in
                    (weightKg: weight, sets: records.map(\.sets).reduce(0, +))
                }
                .sorted { $0.weightKg < $1.weightKg }
            
            return KettlebellSessionSummary(
                id: "\(key.exerciseType.rawValue)-\(key.day.timeIntervalSinceReferenceDate)",
                date: sortedRecords.first?.date ?? key.day,
                exerciseType: key.exerciseType,
                totalSets: records.map(\.sets).reduce(0, +),
                totalReps: records.map { $0.sets * $0.reps }.reduce(0, +),
                topWeightKg: records.map(\.weightKg).max() ?? 0,
                loadBreakdown: loadBreakdown
            )
        }
        .sorted { $0.date > $1.date }
    }
    
    private struct SummaryKey: Hashable {
        let day: Date
        let exerciseType: KettlebellExerciseType
    }
}
