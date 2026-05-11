// WorkoutSummaryView.swift — watchOS

import SwiftUI

struct WorkoutSummaryView: View {
    let plan: SessionPlan
    let completedExercises: [CompletedExercise]
    let activeCalories: Double
    let avgHeartRate: Double
    let elapsedSeconds: Int
    
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                
                Text("Done! 💪")
                    .font(.title3.bold())
                
                Text(plan.sessionType.displayName + " Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                // Stats
                statsRow(icon: "clock", label: "Duration", value: formatDuration(elapsedSeconds))
                statsRow(icon: "flame.fill", label: "Calories", value: "\(Int(activeCalories)) kcal", color: .orange)
                if avgHeartRate > 0 {
                    statsRow(icon: "heart.fill", label: "Avg HR", value: "\(Int(avgHeartRate)) bpm", color: .red)
                }
                
                Divider()
                
                Text("\(completedExercises.filter { !$0.sets.isEmpty }.count) / \(plan.steps.count) exercises logged")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                
                Button("Back to Home") {
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
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
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
    WorkoutSummaryView(
        plan: SessionPlan(
            sessionType: .morning,
            steps: WorkoutData.morningSteps,
            estimatedDurationMinutes: 60
        ),
        completedExercises: [],
        activeCalories: 300,
        avgHeartRate: 150,
        elapsedSeconds: 3600
    )
}

#endif
