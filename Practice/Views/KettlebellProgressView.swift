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
    
    private var latestSwingKg: Double? { swingRecords.first?.weightKg }
    private var latestTGUKg:   Double? { tguRecords.first?.weightKg   }
    
    private var swingPB: Double? { swingRecords.max(by: { $0.weightKg < $1.weightKg })?.weightKg }
    private var tguPB:   Double? { tguRecords.max(by:   { $0.weightKg < $1.weightKg })?.weightKg }
    
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
                        records: Array(swingRecords.suffix(30).reversed()),
                        pbKg: swingPB,
                        targetKg: settings.targetSwingWeightKg,
                        color: .orange
                    )
                    
                    // MARK: TGU chart
                    exerciseCard(
                        title: "Turkish Get-Up",
                        icon: "figure.mind.and.body",
                        records: Array(tguRecords.suffix(30).reversed()),
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
                label: "Swing",
                current: latestSwingKg ?? 0,
                target: settings.targetSwingWeightKg,
                color: .orange
            )
            progressRow(
                label: "TGU",
                current: latestTGUKg ?? 0,
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
            Text("Recent Sets")
                .font(.headline)
            
            ForEach(Array(allRecords.prefix(15))) { record in
                HStack {
                    Image(systemName: record.exerciseType == .swing ? "figure.strengthtraining.functional" : "figure.mind.and.body")
                        .foregroundStyle(record.exerciseType == .swing ? .orange : .purple)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.exerciseType.shortName)
                            .font(.subheadline)
                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatWeight(record.weightKg))
                        .font(.subheadline.bold())
                    Text("× \(record.reps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
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
