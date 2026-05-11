// ConditioningView.swift — iOS
// Shows the weekly conditioning score — a trend-based measure of fitness
// improvement separate from the daily readiness score.
// Components: HR recovery rate, RHR trend, HRV trend, VO2Max trend,
// training consistency, and KB strength-to-weight ratio.

import SwiftUI
import SwiftData
import Charts

struct ConditioningView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConditioningScoreRecord.date, order: .reverse) private var history: [ConditioningScoreRecord]
    @Query(sort: \KettlebellWeightRecord.date, order: .reverse) private var kbRecords: [KettlebellWeightRecord]
    @Query(sort: \WorkoutRecord.startDate, order: .reverse) private var workouts: [WorkoutRecord]
    @Query private var restDays: [RestDayRecord]

    @State private var current: ConditioningResult? = nil
    @State private var isLoading = false
    @State private var bodyMassKg: Double? = nil

    private var latestRecord: ConditioningScoreRecord? { history.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        loadingCard
                    } else if let record = latestRecord {
                        mainScoreCard(record: record)
                        componentBreakdown(record: record)
                        if history.count > 1 { historyChart }
                        rawMetricsCard(record: record)
                        explanationCard
                    } else {
                        emptyCard
                    }
                }
                .padding()
            }
            .navigationTitle("Conditioning")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await recompute() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                bodyMassKg = try? await HealthKitManager.shared.fetchLatestBodyMass()
                // Compute if no record exists for this week
                let weekStart = Calendar.current.date(
                    from: Calendar.current.dateComponents(
                        [.yearForWeekOfYear, .weekOfYear], from: Date()
                    )
                ) ?? Calendar.current.startOfDay(for: Date())
                if !history.contains(where: { $0.date >= weekStart }) {
                    await recompute()
                }
            }
            .refreshable { await recompute() }
        }
    }

    // MARK: - Main score card

    private func mainScoreCard(record: ConditioningScoreRecord) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Conditioning Trend")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(record.trendLabel)
                        .font(.title.bold())
                        .foregroundStyle(scoreColor(record.overallScore))
                    Text("\(record.trendEmoji) \(Int(record.overallScore)) / 100")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Week of \(record.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()

                // Dial
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: record.overallScore / 100)
                        .stroke(
                            AngularGradient(
                                colors: [.red, .orange, .yellow, .green],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(record.overallScore))")
                        .font(.title2.bold().monospacedDigit())
                }
                .frame(width: 90, height: 90)
            }

            // Difference from previous week
            if history.count >= 2 {
                let delta = history[0].overallScore - history[1].overallScore
                HStack(spacing: 6) {
                    Image(systemName: delta >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(delta >= 0 ? .green : .red)
                    Text(String(format: "%+.0f from last week", delta))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Component breakdown

    private func componentBreakdown(record: ConditioningScoreRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Components").font(.headline)

            let components: [(String, Double?, Double, String)] = [
                ("HR Recovery",    record.hrRecoveryScore,    0.25, "heart.fill"),
                ("Resting HR Trend", record.rhrTrendScore,   0.20, "waveform.path.ecg"),
                ("HRV Trend",      record.hrvTrendScore,     0.20, "waveform"),
                ("VO₂ Max Trend",  record.vo2TrendScore,     0.15, "lungs.fill"),
                ("Consistency",    record.consistencyScore,  0.12, "calendar.badge.checkmark"),
                ("Strength Ratio", record.strengthRatioScore, 0.08, "dumbbell.fill"),
            ]

            ForEach(components, id: \.0) { name, score, weight, icon in
                if let s = score {
                    ComponentRow(
                        name:   name,
                        score:  s,
                        weight: weight,
                        icon:   icon
                    )
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - History chart

    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Trend").font(.headline)

            Chart {
                ForEach(history.prefix(12).reversed()) { record in
                    LineMark(
                        x: .value("Week", record.date, unit: .weekOfYear),
                        y: .value("Score", record.overallScore)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                    .symbol(.circle)
                    .symbolSize(30)

                    AreaMark(
                        x: .value("Week", record.date, unit: .weekOfYear),
                        yStart: .value("Base", 0),
                        yEnd:   .value("Score", record.overallScore)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.12))
                    .interpolationMethod(.monotone)
                }

                // 50 = steady line
                RuleMark(y: .value("Steady", 50))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .annotation(position: .trailing) {
                        Text("Steady").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
            }
            .frame(height: 160)
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Raw metrics card

    private func rawMetricsCard(record: ConditioningScoreRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Raw Metrics").font(.headline)

            if let hrr = record.hrRecoveryRate {
                rawRow("HR Recovery", value: String(format: "%.0f bpm/min", hrr),
                       note: hrr >= 20 ? "Good" : hrr >= 12 ? "Moderate" : "Low")
            }
            if let slope = record.rhrSlope {
                rawRow("Resting HR Slope",
                       value: String(format: "%+.2f bpm/day", slope),
                       note: slope < 0 ? "↓ Improving" : slope > 0.02 ? "↑ Concern" : "Stable")
            }
            if let slope = record.hrvSlope {
                rawRow("HRV Slope",
                       value: String(format: "%+.3f ms/day", slope * 1000),
                       note: slope > 0 ? "↑ Improving" : slope < -0.0001 ? "↓ Declining" : "Stable")
            }
            if let slope = record.vo2Slope {
                rawRow("VO₂ Max Slope",
                       value: String(format: "%+.4f/day", slope),
                       note: slope > 0 ? "↑ Improving" : "Stable or declining")
            }
            if let ratio = record.latestKBRatio {
                rawRow("Strength Ratio (swing/BW)",
                       value: String(format: "%.2f", ratio),
                       note: ratio >= 0.5 ? "S&S Simple ✓" : String(format: "%.0f%% of Simple target", ratio / 0.5 * 100))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func rawRow(_ label: String, value: String, note: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.monospacedDigit())
            }
            Spacer()
            Text(note).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    // MARK: - Explanation card

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How this is calculated", systemImage: "info.circle")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text("This score measures the **direction** your fitness is moving, not your absolute level. It uses linear regression on 8 weeks of HealthKit data to compute trends for each metric. A score above 50 means your overall trend is positive. It updates weekly.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Empty / loading states

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text("No conditioning data yet")
                .font(.headline)
            Text("The conditioning score needs at least 3 weeks of HealthKit workout and health data. Tap ↺ to compute from existing data.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Compute now") { Task { await recompute() } }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
            Text("Computing conditioning score…")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("Analysing HealthKit trends — this may take a moment.")
                .font(.caption).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Computation

    private func recompute() async {
        isLoading = true

        let bm = bodyMassKg ?? (try? await HealthKitManager.shared.fetchLatestBodyMass())
        bodyMassKg = bm

        // Consistency
        let cal     = Calendar.current
        let today   = cal.startOfDay(for: Date())
        let start28 = cal.date(byAdding: .day, value: -27, to: today)!
        var credited = 0; var elapsed = 0
        for offset in 0..<28 {
            let day = cal.date(byAdding: .day, value: offset, to: start28)!
            guard day <= today else { break }
            elapsed += 1
            let worked = workouts.contains { cal.isDate($0.startDate, inSameDayAs: day) }
            let rested = restDays.contains  { cal.isDate($0.date,     inSameDayAs: day) }
            if worked || rested { credited += 1 }
        }
        let target      = max(1, Int((Double(elapsed) * 5.0 / 7.0).rounded()))
        let consistency = min(Double(credited) / Double(target), 1.0) * 100

        let engine = ConditioningEngine()
        guard let result = try? await engine.computeScore(
            workoutRecords:     workouts,
            kbRecords:          kbRecords,
            bodyMassKg:         bm,
            consistencyPercent: consistency
        ) else {
            isLoading = false
            return
        }

        // Upsert this week's record
        let weekStart = cal.date(
            from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? today

        let existing = history.first { $0.date >= weekStart }
        let record   = existing ?? {
            let r = ConditioningScoreRecord(date: weekStart, overallScore: result.overallScore)
            modelContext.insert(r)
            return r
        }()

        record.overallScore       = result.overallScore
        record.hrRecoveryScore    = result.hrRecoveryScore
        record.rhrTrendScore      = result.rhrTrendScore
        record.hrvTrendScore      = result.hrvTrendScore
        record.vo2TrendScore      = result.vo2TrendScore
        record.consistencyScore   = result.consistencyScore
        record.strengthRatioScore = result.strengthRatioScore
        record.hrRecoveryRate     = result.hrRecoveryRate
        record.rhrSlope           = result.rhrSlope
        record.hrvSlope           = result.hrvSlope
        record.vo2Slope           = result.vo2Slope
        record.latestKBRatio      = result.kbRatio
        try? modelContext.save()

        isLoading = false
    }

    // MARK: - Helpers

    private func scoreColor(_ s: Double) -> Color {
        switch s {
        case 75...:   return .green
        case 55..<75: return .blue
        case 45..<55: return .secondary
        case 25..<45: return .orange
        default:      return .red
        }
    }
}

// MARK: - Component row

struct ComponentRow: View {
    let name:   String
    let score:  Double
    let weight: Double
    let icon:   String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(barColor)
                    .frame(width: 18)
                Text(name).font(.caption)
                Spacer()
                Text("\(Int(score))/100")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("(\(Int(weight * 100))%)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.12))
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * (score / 100))
                }
            }
            .frame(height: 6)
        }
    }

    private var barColor: Color {
        switch score {
        case 70...:   return .green
        case 50..<70: return .blue
        case 30..<50: return .orange
        default:      return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let container = try! ModelContainer(
        for: ConditioningScoreRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let record = ConditioningScoreRecord(date: .now, overallScore: 63)
    record.hrRecoveryScore    = 71
    record.rhrTrendScore      = 68
    record.hrvTrendScore      = 55
    record.vo2TrendScore      = 60
    record.consistencyScore   = 80
    record.strengthRatioScore = 45
    record.hrRecoveryRate     = 22
    record.rhrSlope           = -0.08
    record.hrvSlope           = 0.0003
    record.latestKBRatio      = 0.38
    container.mainContext.insert(record)

    return ConditioningView()
        .modelContainer(container)
        .environment(ErrorState())
}
#endif