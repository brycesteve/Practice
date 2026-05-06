//
//  PersonalRecordsView.swift
//  Practice
//
//  Created by Steve Bryce on 02/05/2026.
//


// PersonalRecordsView.swift — iOS

import SwiftUI
import HealthKit
import SwiftData

struct PersonalRecordsView: View {
    @Query(sort: \KettlebellWeightRecord.date, order: .reverse) private var kbRecords: [KettlebellWeightRecord]
    @Query private var progressionRecords: [SkillProgressionRecord]
    @Query(sort: \SkillSessionRecord.date, order: .reverse) private var skillHistory: [SkillSessionRecord]
    @Query(sort: \WorkoutRecord.startDate, order: .reverse) private var workouts: [WorkoutRecord]
    @Query private var restDays: [RestDayRecord]
    @Query private var settingsResults: [AppSettings]

    @State private var vo2Peak: Double? = nil
    @State private var rhrBest: Double? = nil
    @State private var userAge: Int? = nil
    @State private var userSex: HealthKitManager.BiologicalSex = .notSet

    private var settings: AppSettings { settingsResults.first ?? AppSettings() }

    // MARK: - Kettlebell PBs

    private var swingPB: KettlebellWeightRecord? {
        kbRecords.filter { $0.exerciseType == .swing }.max(by: { $0.weightKg < $1.weightKg })
    }

    private var tguPB: KettlebellWeightRecord? {
        kbRecords.filter { $0.exerciseType == .tgu }.max(by: { $0.weightKg < $1.weightKg })
    }

    // MARK: - Consistency (rolling 28 days, target 5/7)

    private var consistencyPercent: Double {
        let cal    = Calendar.current
        let start  = cal.date(byAdding: .day, value: -27, to: cal.startOfDay(for: Date()))!
        let days   = 28

        var trainedDays = 0
        var restMarkedDays = 0

        for offset in 0..<days {
            let day = cal.date(byAdding: .day, value: offset, to: start)!
            let worked   = workouts.contains  { cal.isDate($0.startDate, inSameDayAs: day) }
            let rested   = restDays.contains  { cal.isDate($0.date,      inSameDayAs: day) }
            if worked { trainedDays += 1 }
            else if rested { restMarkedDays += 1 }
        }

        // Target: 5 sessions per 7 days = 20 per 28 days
        // Credit intentional rest days as meeting the target
        let target = Int(Double(days) * 5.0 / 7.0)  // = 20
        let credited = trainedDays + restMarkedDays
        return min(Double(credited) / Double(target), 1.0) * 100
    }

    private var trainedLast28: Int {
        let start = Calendar.current.date(byAdding: .day, value: -27, to: Calendar.current.startOfDay(for: Date()))!
        return workouts.filter { $0.startDate >= start }.count
    }

    private var currentStreak: Int {
        let cal   = Calendar.current
        var streak = 0
        var day   = cal.startOfDay(for: Date())

        while true {
            let worked = workouts.contains { cal.isDate($0.startDate, inSameDayAs: day) }
            let rested = restDays.contains  { cal.isDate($0.date,     inSameDayAs: day) }
            if worked || rested {
                streak += 1
                day = cal.date(byAdding: .day, value: -1, to: day)!
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {

                // MARK: Consistency
                Section {
                    consistencyCard
                } header: {
                    Label("Consistency", systemImage: "chart.line.uptrend.xyaxis")
                }

                // MARK: Kettlebell PBs
                Section {
                    if let pb = swingPB {
                        PRRow(
                            title: "Swing PB",
                            value: formatWeight(pb.weightKg),
                            subtitle: pb.date.formatted(date: .abbreviated, time: .omitted),
                            icon: "figure.strengthtraining.functional",
                            color: .orange,
                            isGoalMet: pb.weightKg >= settings.targetSwingWeightKg
                        )
                    } else {
                        Text("No swing sessions logged yet").font(.caption).foregroundStyle(.secondary)
                    }
                    if let pb = tguPB {
                        PRRow(
                            title: "TGU PB",
                            value: formatWeight(pb.weightKg),
                            subtitle: pb.date.formatted(date: .abbreviated, time: .omitted),
                            icon: "figure.mind.and.body",
                            color: .purple,
                            isGoalMet: pb.weightKg >= settings.targetTGUWeightKg
                        )
                    } else {
                        Text("No TGU sessions logged yet").font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Kettlebell", systemImage: "dumbbell.fill")
                }

                // MARK: Skill bests
                Section {
                    ForEach(progressionRecords) { record in
                        skillBestRow(record: record)
                    }
                } header: {
                    Label("Skills", systemImage: "figure.gymnastics")
                }

                // MARK: Health peaks
                Section {
                    if let vo2 = vo2Peak {
                        PRRow(title: "VO₂ Max Peak", value: String(format: "%.1f mL/kg/min", vo2),
                              subtitle: "All time", icon: "lungs.fill", color: .green)
                    }
                    if let rhr = rhrBest {
                        PRRow(title: "Lowest Resting HR", value: String(format: "%.0f bpm", rhr),
                              subtitle: "All time", icon: "heart.fill", color: .red)
                    }
                    if vo2Peak == nil && rhrBest == nil {
                        Text("Wear your Watch overnight to collect health data.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Health", systemImage: "heart.text.square.fill")
                }
            }
            .navigationTitle("Personal Records")
            .task { await loadHealthPeaks() }
        }
    }

    // MARK: - Consistency card

    private var consistencyCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("4-Week Consistency")
                        .font(.subheadline.bold())
                    Text("\(trainedLast28) sessions · target 20")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Current streak: \(currentStreak) day\(currentStreak == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: consistencyPercent / 100)
                        .stroke(consistencyColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(consistencyPercent))%")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .frame(width: 58, height: 58)
            }

            ProgressView(value: consistencyPercent / 100)
                .tint(consistencyColor)

            Text("Counts training days + intentional rest days against a 5/7 target.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var consistencyColor: Color {
        switch consistencyPercent {
        case 90...:    return .green
        case 70..<90:  return .blue
        case 50..<70:  return .yellow
        default:       return .orange
        }
    }

    // MARK: - Skill best row

    @ViewBuilder
    private func skillBestRow(record: SkillProgressionRecord) -> some View {
        let history = skillHistory.filter { $0.skillProgressionID == record.id }

        // Best hold (timed) or best total reps across all sessions
        let bestHold = history.flatMap { $0.sets ?? [] }.compactMap(\.durationSeconds).max()
        let bestReps = history.flatMap { $0.sets ?? [] }.compactMap(\.reps).max()

        if let hold = bestHold {
            PRRow(
                title: "\(record.skillName) Best Hold",
                value: "\(hold)s",
                subtitle: "Level \(record.currentLevel): \(record.currentSkillLevel?.name ?? "")",
                icon: skillIcon(record.skillName),
                color: skillColor(record.skillName)
            )
        } else if let reps = bestReps {
            PRRow(
                title: "\(record.skillName) Best Set",
                value: "\(reps) reps",
                subtitle: "Level \(record.currentLevel): \(record.currentSkillLevel?.name ?? "")",
                icon: skillIcon(record.skillName),
                color: skillColor(record.skillName)
            )
        } else {
            HStack {
                Image(systemName: skillIcon(record.skillName)).foregroundStyle(skillColor(record.skillName))
                Text("\(record.skillName)").font(.subheadline)
                Spacer()
                Text("No sessions yet").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Load health peaks

    private func loadHealthPeaks() async {
        async let vo2History  = HealthKitManager.shared.fetchVO2MaxHistory(days: 365)
        // async let massHistory = HealthKitManager.shared.fetchBodyMassHistory(days: 365)

        // VO2Max peak
        if let history = try? await vo2History {
            vo2Peak = history.map(\.value).max()
        }

        // Lowest resting HR (approximate via Recovery Engine's fetch)
        // Re-use the shared HealthKit fetch pattern
        rhrBest = await fetchLowestRHR()
        userAge = try? HealthKitManager.shared.fetchAge()
        userSex = (try? HealthKitManager.shared.fetchBiologicalSex()) ?? .notSet
    }

    private func fetchLowestRHR() async -> Double? {
        // Re-uses HealthKitManager's generic fetch, scanning the last year
        // and returning the minimum resting HR recorded.
        let store = HKHealthStore()
        let type  = HKQuantityType(.restingHeartRate)
        let unit  = HKUnit.count().unitDivided(by: .minute())
        let start = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let pred  = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: pred,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                let values = (samples as? [HKQuantitySample])?.map { $0.quantity.doubleValue(for: unit) }
                continuation.resume(returning: values?.min())
            }
            store.execute(query)
        }
    }

    // MARK: - Helpers

    private func formatWeight(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg)) kg" : "\(kg) kg"
    }

    private func skillIcon(_ name: String) -> String {
        Skill(rawValue: name)?.icon ?? ""
    }

    private func skillColor(_ name: String) -> Color {
        Skill(rawValue: name)?.color ?? .accentColor
    }
}

// MARK: - PR Row

struct PRRow: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    var isGoalMet: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title).font(.subheadline)
                    if isGoalMet {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(isGoalMet ? .green : .primary)
        }
        .padding(.vertical, 2)
    }
}
