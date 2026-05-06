// RecoveryView.swift — watchOS
// Shows readiness score detail when tapping the complication or the
// Recovery button in the session picker.
//
// Data priority:
//  1. WCSyncPayload pushed from iOS (arrives via WatchConnectivityManager)
//     — fast, no HealthKit query needed on the watch
//  2. Live HealthKit query on the watch as fallback (slower, less data)
//
// The watch registers a WatchConnectivityDelegate to receive the payload
// and posts it via NotificationCenter so this view can update reactively.

import SwiftUI
import SwiftData

struct WatchRecoveryView: View {
    @State private var score: RecoveryScore?   = nil
    @State private var syncedScoreOnly: Double? = nil   // fast path from WC payload
    @State private var isLoading               = true
    @State private var source: DataSource      = .unknown
    
    
    
    enum DataSource { case synced, liveHK, unknown }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Reading Health…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                } else if let score {
                    scoreRing(score)
                    metricRows(score)
                    adviceRow(score)
                    sourceFooter
                    
                } else if let synced = syncedScoreOnly {
                    // We have a score from iOS but no metric breakdown
                    simpleSyncedScore(synced)
                    
                } else {
                    noDataView
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Recovery")
        .task { await load() }
        // React to incoming WatchConnectivity sync payloads
        .onReceive(
            NotificationCenter.default.publisher(for: .recoveryScoreReceived)
        ) { notification in
            if let s = notification.userInfo?["score"] as? Double {
                syncedScoreOnly = s
                // If we don't already have a full HealthKit score, surface the synced one
                if score == nil { isLoading = false }
            }
        }
    }
    
    // MARK: - Score ring (full detail)
    
    private func scoreRing(_ score: RecoveryScore) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: score.overall / 100)
                    .stroke(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(score.overall))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("/100")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(score.label)
                    .font(.headline)
                    .foregroundStyle(scoreColor(score.overall))
                Text(score.emoji + " Readiness")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Simple synced score (no metric breakdown available)
    
    private func simpleSyncedScore(_ s: Double) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: s / 100)
                    .stroke(
                        AngularGradient(
                            colors: [.red, .orange, .yellow, .green],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(s))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("/100")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, height: 70)
            
            Text(labelFor(s))
                .font(.headline)
                .foregroundStyle(scoreColor(s))
            
            let (text, icon, color) = trainingAdvice(s)
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color)
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            
            Text("Synced from iPhone")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Metric rows (shown when full HealthKit score available)
    
    private func metricRows(_ score: RecoveryScore) -> some View {
        VStack(spacing: 6) {
            if let hrv = score.metrics.hrv {
                metricRow(icon: "waveform.path.ecg", label: "HRV",
                          value: String(format: "%.0f ms", hrv),
                          contribution: score.hrvContribution, color: .purple)
            }
            if let rhr = score.metrics.restingHeartRate {
                metricRow(icon: "heart.fill", label: "Resting HR",
                          value: String(format: "%.0f bpm", rhr),
                          contribution: score.restingHRContribution, color: .red)
            }
            if let hours = score.metrics.sleepDuration {
                metricRow(icon: "bed.double.fill", label: "Sleep",
                          value: String(format: "%.1f hrs", hours),
                          contribution: score.sleepDurationContribution, color: .indigo)
            }
            if let quality = score.metrics.sleepQualityPercent {
                metricRow(icon: "moon.zzz.fill", label: "Sleep Quality",
                          value: String(format: "%.0f%%", quality),
                          contribution: score.sleepQualityContribution, color: .blue)
            }
            if let resp = score.metrics.respiratoryRate {
                metricRow(icon: "lungs.fill", label: "Resp. Rate",
                          value: String(format: "%.1f /min", resp),
                          contribution: score.respiratoryContribution, color: .teal)
            }
        }
    }
    
    @ViewBuilder
    private func metricRow(icon: String, label: String, value: String,
                           contribution: Double?, color: Color) -> some View {
        VStack(alignment: .leading) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    if let c = contribution {
                        Spacer().frame(maxHeight: 2)
                        HStack {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.gray.opacity(0.2))
                                    Capsule()
                                        .fill(contributionColor(c))
                                        .frame(width: geo.size.width * (c / 100))
                                }
                            }
                            .frame(height: 5)
                            Text("\(Int(c))")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .trailing)
                        }
                    }
                }
                
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
        }
        
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Advice row
    
    private func adviceRow(_ score: RecoveryScore) -> some View {
        let (text, icon, color) = trainingAdvice(score.overall)
        return HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Source footer
    
    private var sourceFooter: some View {
        Text(source == .synced ? "Synced from iPhone" : "Live from HealthKit")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
    }
    
    // MARK: - No data
    
    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No data yet")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Wear Watch overnight\nor open iPhone app")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Load
    
    private func load() async {
        guard score == nil else { return }
        // Fast path: request a sync from iOS immediately
        // If the watch is reachable the payload will arrive within seconds
        WatchConnectivityManager.shared.requestFullSync()
        
        // Attempt a live HealthKit query in parallel (may have limited data on watch)
        if let result = try? await RecoveryEngine().computeScore() {
            score = result
            source = .liveHK
        }
        
        isLoading = false
    }
    
    // MARK: - Helpers
    
    private func scoreColor(_ s: Double) -> Color {
        switch s {
        case 85...:   return .green
        case 70..<85: return .blue
        case 50..<70: return .yellow
        case 30..<50: return .orange
        default:      return .red
        }
    }
    
    private func contributionColor(_ s: Double) -> Color {
        switch s {
        case 70...:   return .green
        case 50..<70: return .yellow
        case 30..<50: return .orange
        default:      return .red
        }
    }
    
    private func labelFor(_ s: Double) -> String {
        switch s {
        case 85...:   return "Excellent"
        case 70..<85: return "Good"
        case 50..<70: return "Moderate"
        case 30..<50: return "Poor"
        default:      return "Very Low"
        }
    }
    
    private func trainingAdvice(_ s: Double) -> (String, String, Color) {
        switch s {
        case 85...:   return ("Peak — push hard",        "bolt.fill",                   .green)
        case 70..<85: return ("Good — train normally",   "checkmark.circle.fill",       .blue)
        case 50..<70: return ("Moderate — go lighter",   "minus.circle.fill",           .yellow)
        case 30..<50: return ("Low — rest or mobility",  "exclamationmark.circle.fill", .orange)
        default:      return ("Very low — rest today",   "bed.double.fill",             .red)
        }
    }
}

#if DEBUG
extension WatchRecoveryView {
    /// For Preview Only
    init(score: RecoveryScore) {
        self._score = State(initialValue: score)
        self._isLoading = State(initialValue: false)
    }
}

#Preview {
    let score = RecoveryScore(
        overall: 75,
        hrvContribution: 30,
        metrics: RecoveryMetrics(
            hrv: 42, restingHeartRate: 64,
            sleepDuration: 8, sleepQualityPercent: 0.7,
            respiratoryRate: 15, activeEnergyYesterday: 200,
            activeEnergyTwoDaysAgo: 200
        ),
        dataQuality: .rich
    )
    
    return WatchRecoveryView(score: score)
}

#endif
