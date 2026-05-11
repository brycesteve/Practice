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

// RecoveryView.swift — watchOS (Refactored UI)
// Focus: clearer hierarchy, reduced colour noise, consistent material surfaces

import SwiftUI
import SwiftData

struct WatchRecoveryView: View {
    @State private var score: RecoveryScore? = nil
    @State private var syncedScoreOnly: Double? = nil
    @State private var isLoading = true
    @State private var source: DataSource = .unknown
    
    enum DataSource { case synced, liveHK, unknown }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                
                // MARK: - Score Section
                if isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Reading Health…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                } else if let score {
                    scoreHeader(score)
                    metricsSection(score)
                    adviceSection(score)
                    footer
                    
                } else if let synced = syncedScoreOnly {
                    syncedScoreView(synced)
                    
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("Recovery")
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .recoveryScoreReceived)) { notification in
            if let s = notification.userInfo?["score"] as? Double {
                syncedScoreOnly = s
                if score == nil { isLoading = false }
            }
        }
    }
    
    // MARK: - Score Header (Primary)
    
    private func scoreHeader(_ score: RecoveryScore) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: score.overall / 100)
                    .stroke(
                        scoreColor(score.overall),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(Int(score.overall))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Recovery")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)
            
            Text(score.label)
                .font(.headline)
                .foregroundStyle(scoreColor(score.overall))
        }
        .padding(.vertical, 6)
        .padding(.top, 20)
    }
    
    // MARK: - Metrics Section (Secondary)
    
    private func metricsSection(_ score: RecoveryScore) -> some View {
        VStack(spacing: 8) {
            if let hrv = score.metrics.hrv {
                metricRow("waveform.path.ecg", "HRV", String(format: "%.0f ms", hrv), .purple)
            }
            if let rhr = score.metrics.restingHeartRate {
                metricRow("heart.fill", "Rest HR", String(format: "%.0f bpm", rhr), .red)
            }
            if let sleep = score.metrics.sleepDuration {
                metricRow("bed.double.fill", "Sleep", String(format: "%.1f hrs", sleep), .indigo)
            }
            if let quality = score.metrics.sleepQualityPercent {
                metricRow("moon.zzz.fill", "Sleep Quality", String(format: "%.0f%%", quality), .indigo)
            }
            if let resp = score.metrics.respiratoryRate {
                metricRow("lungs.fill", "Resp", String(format: "%.1f/min", resp), .cyan)
            }
        }
    }
    
    private func metricRow(_ icon: String, _ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.headline)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption2).fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Advice Section (Action Layer)
    
    private func adviceSection(_ score: RecoveryScore) -> some View {
        let (text, icon, color) = trainingAdvice(score.overall)
        
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
            
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Synced Score
    
    private func syncedScoreView(_ s: Double) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: s / 100)
                    .stroke(
                        scoreColor(s),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(s))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .frame(width: 80, height: 80)
            
            Text(labelFor(s))
                .font(.headline)
                .foregroundStyle(scoreColor(s))
            
            let (text, icon, color) = trainingAdvice(s)
            
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            
            Text("Synced from iPhone")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Footer / Empty
    
    private var footer: some View {
        Text(source == .synced ? "Synced from iPhone" : "Live from HealthKit")
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "No data yet",
            systemImage: "heart.slash",
            description: Text("Wear Watch overnight or open iPhone app")
        )
        .padding(.top, 16)
    }
    
    // MARK: - Load
    
    private func load() async {
        WatchConnectivityManager.shared.requestFullSync()
        
        if let result = try? await RecoveryEngine().computeScore() {
            score = result
            source = .liveHK
        }
        
        isLoading = false
    }
    
    // MARK: - Helpers
    
    private func scoreColor(_ s: Double) -> Color {
        switch s {
        case 85...: return .green
        case 70..<85: return .blue
        case 50..<70: return .yellow
        case 30..<50: return .orange
        default: return .red
        }
    }
    
    private func labelFor(_ s: Double) -> String {
        switch s {
        case 85...: return "Excellent"
        case 70..<85: return "Good"
        case 50..<70: return "Moderate"
        case 30..<50: return "Poor"
        default: return "Very Low"
        }
    }
    
    private func trainingAdvice(_ s: Double) -> (String, String, Color) {
        switch s {
        case 85...: return ("Peak - push hard", "bolt.fill", .green)
        case 70..<85: return ("Good — train normally", "checkmark.circle.fill", .blue)
        case 50..<70: return ("Moderate — go lighter", "minus.circle.fill", .yellow)
        case 30..<50: return ("Low — rest or mobility", "exclamationmark.circle.fill", .orange)
        default: return ("Very low — rest today", "bed.double.fill", .red)
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
    
    return NavigationStack {
        WatchRecoveryView(score: score)
    }
}




#endif
