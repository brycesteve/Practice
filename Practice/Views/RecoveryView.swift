// RecoveryView.swift — iOS
// Full readiness/recovery detail screen.
// Reads live from HealthKit each time it appears; caches today's score in SwiftData.

import SwiftUI
import SwiftData
import Charts

struct RecoveryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecoveryScoreRecord.date, order: .reverse) private var cachedScores: [RecoveryScoreRecord]
    
    @State private var score: RecoveryScore? = nil
    @State private var isLoading = true
    @State private var scoreHistory: [RecoveryScoreRecord] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        loadingCard
                    } else if let score {
                        mainScoreCard(score)
                        metricsGrid(score)
                        contributionBars(score)
                        if cachedScores.count > 1 { historyChart }
                        dataQualityFooter(score)
                    } else {
                        noDataCard
                    }
                }
                .padding()
            }
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadScore() }
            .refreshable { await loadScore() }
        }
    }
    
    // MARK: - Loading
    
    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Reading HealthKit…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var noDataCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No recovery data available")
                .font(.headline)
            Text("Wear your Apple Watch overnight to collect HRV, sleep, and resting heart rate data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Main score card
    
    private func mainScoreCard(_ score: RecoveryScore) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Readiness")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(score.label)
                        .font(.title.bold())
                        .foregroundStyle(scoreColor(score.overall))
                    Text(score.emoji + " \(Int(score.overall)) / 100")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Circular gauge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: score.overall / 100)
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
                    Text("\(Int(score.overall))")
                        .font(.title2.bold().monospacedDigit())
                }
                .frame(width: 80, height: 80)
            }
            
            // Recommendation
            let advice = trainingAdvice(score: score.overall)
            HStack(spacing: 8) {
                Image(systemName: advice.icon)
                    .foregroundStyle(advice.color)
                Text(advice.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(advice.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Metrics grid
    
    private func metricsGrid(_ score: RecoveryScore) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let hrv = score.metrics.hrv {
                MetricCard(
                    title: "HRV",
                    value: String(format: "%.0f ms", hrv),
                    icon: "waveform.path.ecg",
                    color: .purple,
                    subtitle: hrvLabel(hrv),
                    score: score.hrvContribution
                )
            }
            if let rhr = score.metrics.restingHeartRate {
                MetricCard(
                    title: "Resting HR",
                    value: String(format: "%.0f bpm", rhr),
                    icon: "heart.fill",
                    color: .red,
                    subtitle: rhrLabel(rhr),
                    score: score.restingHRContribution
                )
            }
            if let hours = score.metrics.sleepDuration {
                MetricCard(
                    title: "Sleep",
                    value: String(format: "%.1f hrs", hours),
                    icon: "bed.double.fill",
                    color: .indigo,
                    subtitle: sleepDurationLabel(hours),
                    score: score.sleepDurationContribution
                )
            }
            if let quality = score.metrics.sleepQualityPercent {
                MetricCard(
                    title: "Sleep Quality",
                    value: String(format: "%.0f%%", quality),
                    icon: "moon.zzz.fill",
                    color: .blue,
                    subtitle: "Deep + REM",
                    score: score.sleepQualityContribution
                )
            }
            if let resp = score.metrics.respiratoryRate {
                MetricCard(
                    title: "Resp. Rate",
                    value: String(format: "%.1f /min", resp),
                    icon: "lungs.fill",
                    color: .teal,
                    subtitle: respLabel(resp),
                    score: score.respiratoryContribution
                )
            }
            if let energy = score.metrics.activeEnergyYesterday {
                MetricCard(
                    title: "Yesterday Kcal",
                    value: String(format: "%.0f kcal", energy),
                    icon: "flame.fill",
                    color: .orange,
                    subtitle: "Training load",
                    score: score.trainingLoadContribution
                )
            }
        }
    }
    
    // MARK: - Contribution bars
    
    private func contributionBars(_ score: RecoveryScore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Breakdown")
                .font(.headline)
            
            let contributions: [(String, Double?, Double)] = [
                ("HRV",            score.hrvContribution,          0.30),
                ("Resting HR",     score.restingHRContribution,    0.20),
                ("Sleep Duration", score.sleepDurationContribution, 0.20),
                ("Sleep Quality",  score.sleepQualityContribution,  0.15),
                ("Resp. Rate",     score.respiratoryContribution,   0.05),
                ("Training Load",  score.trainingLoadContribution,  0.10),
            ]
            
            ForEach(contributions, id: \.0) { name, componentScore, weight in
                if let s = componentScore {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(name).font(.caption)
                            Spacer()
                            Text("\(Int(s))/100")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text("(\(Int(weight * 100))%)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.15))
                                Capsule()
                                    .fill(scoreColor(s))
                                    .frame(width: geo.size.width * (s / 100))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 14-day history chart
    
    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("14-Day Trend")
                .font(.headline)
            
            let recent = Array(cachedScores.prefix(14).reversed())
            
            Chart {
                ForEach(recent) { record in
                    AreaMark(
                        x: .value("Date", record.date, unit: .day),
                        y: .value("Score", record.overallScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [scoreColor(recent.last?.overallScore ?? 70).opacity(0.3), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    
                    LineMark(
                        x: .value("Date", record.date, unit: .day),
                        y: .value("Score", record.overallScore)
                    )
                    .foregroundStyle(scoreColor(recent.last?.overallScore ?? 70))
                    .symbol(.circle)
                    .symbolSize(30)
                }
                
                // 70 threshold line
                RuleMark(y: .value("Good", 70))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.green.opacity(0.5))
            }
            .frame(height: 160)
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Data quality footer
    
    private func dataQualityFooter(_ score: RecoveryScore) -> some View {
        HStack(spacing: 8) {
            Image(systemName: score.dataQuality == .rich ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(score.dataQuality == .rich ? .green : .orange)
            Text(dataQualityText(score.dataQuality))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Load & cache score
    
    private func loadScore() async {
        isLoading = true
        
        let today = Calendar.current.startOfDay(for: Date())
        let todayRecord = cachedScores.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        
        // If we have a cached score from today that is less than 3 hours old, use it
        let cacheIsFresh = todayRecord.map {
            Date().timeIntervalSince($0.date) < 2 * 3600
        } ?? false
        
        if !cacheIsFresh {
            // Recompute and cache via BackgroundTaskManager (single source of truth)
            let container = modelContext.container
            await BackgroundTaskManager.shared.computeAndCacheScore(modelContainer: container)
        }
        
        // Build the display score from cached record to avoid a second HealthKit query
        if let record = cachedScores.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            score = RecoveryScore(
                overall: record.overallScore,
                hrvContribution: record.hrvScore,
                restingHRContribution: record.restingHRScore,
                sleepDurationContribution: record.sleepDurationScore,
                sleepQualityContribution: record.sleepQualityScore,
                respiratoryContribution: record.respiratoryRateScore,
                trainingLoadContribution: record.trainingLoadScore,
                metrics: RecoveryMetrics(
                    hrv: record.hrv,
                    restingHeartRate: record.restingHR,
                    sleepDuration: record.sleepHours,
                    respiratoryRate: record.respiratoryRate,
                    activeEnergyYesterday: record.activeEnergyYesterday
                ),
                dataQuality: dataQuality(from: record)
            )
        } else {
            // Fallback — no cached data available
            score = nil
        }
        
        isLoading = false
    }
    
    private func dataQuality(from record: RecoveryScoreRecord) -> RecoveryScore.DataQuality {
        let count = [record.hrv, record.restingHR, record.sleepHours,
                     record.sleepQualityScore, record.respiratoryRate]
            .compactMap { $0 }.count
        switch count {
        case 4...: return .rich
        case 2...3: return .moderate
        default: return .limited
        }
    }
    
    // MARK: - Helpers
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 85...100: return .green
        case 70..<85:  return .blue
        case 50..<70:  return .yellow
        case 30..<50:  return .orange
        default:       return .red
        }
    }
    
    private func hrvLabel(_ ms: Double) -> String {
        switch ms {
        case 70...:    return "Excellent"
        case 50..<70:  return "Good"
        case 30..<50:  return "Average"
        default:       return "Low"
        }
    }
    
    private func rhrLabel(_ bpm: Double) -> String {
        switch bpm {
        case ..<50:    return "Athletic"
        case 50..<65:  return "Good"
        case 65..<75:  return "Average"
        default:       return "Elevated"
        }
    }
    
    private func sleepDurationLabel(_ hours: Double) -> String {
        switch hours {
        case 7..<9.5:  return "Optimal"
        case 6..<7:    return "Slightly low"
        case 9.5...:   return "Long"
        default:       return "Insufficient"
        }
    }
    
    private func respLabel(_ rate: Double) -> String {
        switch rate {
        case 12..<16:  return "Normal"
        case 16..<20:  return "Slightly high"
        default:       return rate < 12 ? "Low" : "Elevated"
        }
    }
    
    private func dataQualityText(_ quality: RecoveryScore.DataQuality) -> String {
        switch quality {
        case .rich:     return "Rich data — score is highly reliable"
        case .moderate: return "Moderate data — score is a reasonable estimate"
        case .limited:  return "Limited data — wear your Watch overnight for better accuracy"
        }
    }
    
    private struct TrainingAdvice {
        let text: String; let icon: String; let color: Color
    }
    
    private func trainingAdvice(score: Double) -> TrainingAdvice {
        switch score {
        case 85...:    return TrainingAdvice(text: "Peak readiness — push hard today.", icon: "bolt.fill", color: .green)
        case 70..<85:  return TrainingAdvice(text: "Good to train — normal intensity.", icon: "checkmark.circle.fill", color: .blue)
        case 50..<70:  return TrainingAdvice(text: "Moderate — consider a lighter session.", icon: "minus.circle.fill", color: .yellow)
        case 30..<50:  return TrainingAdvice(text: "Low — prioritise rest or mobility only.", icon: "exclamationmark.circle.fill", color: .orange)
        default:       return TrainingAdvice(text: "Very low — rest today.", icon: "bed.double.fill", color: .red)
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String
    let score: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let s = score {
                    Text("\(Int(s))")
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(contributionColor(s).opacity(0.2), in: Capsule())
                        .foregroundStyle(contributionColor(s))
                }
            }
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let s = score {
                ProgressView(value: s / 100)
                    .tint(contributionColor(s))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    private func contributionColor(_ score: Double) -> Color {
        switch score {
        case 70...: return .green
        case 50..<70: return .yellow
        case 30..<50: return .orange
        default: return .red
        }
    }
}
