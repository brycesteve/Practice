// WorkoutSummaryView.swift — watchOS

import SwiftUI

/// Captured before clearing the active session; picker refreshes cannot change a finished workout.
struct WorkoutSummarySnapshot {
    let plan: SessionPlan
    let completedExercises: [CompletedExercise]
    let activeCalories: Double
    let averageHeartRate: Double
    let elapsedSeconds: Int

    init(plan: SessionPlan, loggedExercises: [UUID: CompletedExercise], activeCalories: Double,
         averageHeartRate: Double, elapsedSeconds: Int) {
        self.plan = plan
        self.completedExercises = plan.steps.compactMap { loggedExercises[$0.id] }
        self.activeCalories = activeCalories
        self.averageHeartRate = averageHeartRate
        self.elapsedSeconds = elapsedSeconds
    }

    var loggedExerciseCount: Int {
        completedExercises.filter { $0.sets.contains(where: \.hasCompletedActivity) }.count
    }
}

struct WorkoutSummaryView: View {
    let summary: WorkoutSummarySnapshot

    private var swingSets: [CompletedSet] {
        summary.completedExercises.first {
            $0.exerciseName.localizedCaseInsensitiveContains("swing")
        }?.sets ?? []
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                
                Text("Done! 💪")
                    .font(.title3.bold())
                
                Text(summary.plan.sessionType.displayName + " Session")
                    .font(.caption)
                    .foregroundStyle(WatchAppearance.supportingText)
                
                Divider()
                
                // Stats
                statsRow(icon: "clock", label: "Duration", value: formatDuration(summary.elapsedSeconds), color: .cyan)
                statsRow(icon: "flame.fill", label: "Calories", value: "\(Int(summary.activeCalories)) kcal", color: .orange)
                if summary.averageHeartRate > 0 {
                    statsRow(icon: "heart.fill", label: "Avg HR", value: "\(Int(summary.averageHeartRate)) bpm", color: .red)
                }
                if let averagePeak = average(swingSets.compactMap(\.peakHeartRate)) {
                    statsRow(icon: "heart.text.clipboard", label: "Swing peak", value: "\(Int(averagePeak)) bpm", color: .red)
                }
                if let averageRecovery = average(swingSets.compactMap(\.recoveryDuration)) {
                    statsRow(icon: "timer", label: "Avg recovery", value: "\(Int(averageRecovery.rounded())) sec", color: .mint)
                }
                
                Divider()
                
                Text("\(summary.loggedExerciseCount) / \(summary.plan.steps.count) exercises logged")
                    .font(.caption2)
                    .foregroundStyle(WatchAppearance.supportingText)
                
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
    }
    
    @ViewBuilder
    private func statsRow(icon: String, label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(WatchAppearance.supportingText)
                Text(value)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
    
    private func saveNotes() {
        // Persist notes to the most recent WorkoutRecord
        // The record was already inserted by WorkoutGuideView; we just update notes.
        // Using a slight delay to avoid saving on every keystroke.
        Task {
            try? await Task.sleep(for: .seconds(1))
            // Notes are passed back via the binding — WorkoutGuideView saves them
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#if DEBUG
#Preview {
    WorkoutSummaryView(summary: WorkoutSummarySnapshot(
        plan: WorkoutData.plan(for: .morning), loggedExercises: [:],
        activeCalories: 300, averageHeartRate: 150, elapsedSeconds: 3600))
}

#endif
