//
//  EveningPreviewSheet.swift
//  Practice
//
//  Created by Steve Bryce on 05/05/2026.
//


// EveningPreviewSheet.swift — iOS
// Shows a read-only preview of tonight's evening session —
// exercises grouped by phase (warmup, skill, assistance, stretches),
// with the current progression level shown for skill exercises.

import SwiftUI

public struct EveningPreviewSheet: View {
    let rotationDay: Int
    let progressions: [SkillProgression]

    public init(rotationDay: Int, progressions: [SkillProgression]) {
        self.rotationDay = rotationDay
        self.progressions = progressions
    }

    @Environment(\.dismiss) private var dismiss

    private var plan: SessionPlan {
        SessionPlan(
            sessionType: .evening,
            steps: WorkoutData.eveningSteps(
                rotationDay: rotationDay,
                progressions: progressions
            ),
            estimatedDurationMinutes: 60
        )
    }

    private var skillNames = Skill.activeSkills.map { $0.rawValue }
    private var tonightSkill: String {
        skillNames[rotationDay % Skill.activeSkills.count]
    }
    private var tonightProgression: SkillProgression? {
        progressions.first { $0.skillName == tonightSkill }
    }

    // Group steps into named phases for display
    private var phases: [(title: String, steps: [WorkoutStep])] {
        let warmup   = plan.steps.filter { $0.exercise.category == .warmup }
        let skill    = plan.steps.filter { $0.exercise.category == .skillProgression }
        let assist   = plan.steps.filter { $0.exercise.category == .calisthenics }
        let stretch  = plan.steps.filter { $0.exercise.category == .stretch }

        return [
            ("Warm-Up",         warmup),
            ("Skill Work",      skill),
            ("Assistance",      assist),
            ("Stretching",      stretch),
        ].filter { !$0.steps.isEmpty }
    }

    public var body: some View {
        NavigationStack {
            List {
                // Skill context header
                if let prog = tonightProgression,
                   let level = prog.currentSkillLevel {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "figure.gymnastics")
                                    .foregroundStyle(.purple)
                                Text(tonightSkill)
                                    .font(.headline)
                                Spacer()
                                Text("Level \(prog.currentLevel) of \(prog.levels.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(level.name)
                                .font(.subheadline.bold())

                            Text(level.details)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let dur = level.targetDurationSeconds {
                                Label("Target: \(dur)s hold", systemImage: "timer")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                            if let reps = level.targetReps {
                                Label("Target: \(reps) reps", systemImage: "repeat")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }

                            // Advancement progress
                            let criteria = level.advanceCriteria
                            Label(
                                "Advance after \(criteria.consecutiveSessions) qualifying sessions",
                                systemImage: "flag.checkered"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            if let next = prog.nextSkillLevel {
                                HStack {
                                    Image(systemName: "arrow.up.circle")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text("Next: \(next.name)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Tonight's Skill")
                    }
                }

                // Exercise phases
                ForEach(phases, id: \.title) { phase in
                    Section {
                        ForEach(phase.steps) { (step: WorkoutStep) in
                            ExercisePreviewRow(step: step)
                        }
                    } header: {
                        Label(phase.title, systemImage: phaseIcon(phase.title))
                    }
                }

                // Estimated duration footer
                Section {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Estimated duration")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("~\(plan.estimatedDurationMinutes) min")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                }
            }
            .navigationTitle("🌙 Tonight's Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func phaseIcon(_ title: String) -> String {
        switch title {
        case "Warm-Up":    return "flame"
        case "Skill Work": return "figure.gymnastics"
        case "Assistance": return "dumbbell"
        case "Stretching": return "figure.cooldown"
        default:           return "list.bullet"
        }
    }
}

// MARK: - Exercise row

struct ExercisePreviewRow: View {
    let step: WorkoutStep

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(step.exercise.name)
                        .font(.subheadline)

                    // Sets/reps or duration target
                    Text(targetDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                categoryBadge
            }

            // Circuit indicator
            if step.circuitGroupID != nil {
                Label("Circuit", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            // Notes if present
            if let notes = step.exercise.notes {
                Text(notes)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private var targetDescription: String {
        if let reps = step.reps {
            return "\(step.sets) × \(reps) reps"
        } else if let dur = step.durationSeconds {
            return "\(step.sets) × \(dur)s"
        } else if let defReps = step.exercise.defaultReps {
            return "\(step.sets) × \(defReps) reps"
        } else if let defDur = step.exercise.defaultDuration {
            return "\(step.sets) × \(defDur)s"
        }
        return "\(step.sets) sets"
    }

    @ViewBuilder
    private var categoryBadge: some View {
        let (label, color): (String, Color) = switch step.exercise.category {
        case .warmup:           ("Warm-up",  .yellow)
        case .skillProgression: ("Skill",    .purple)
        case .calisthenics:     ("Assist",   .blue)
        case .stretch:          ("Stretch",  .green)
        case .kettlebell:       ("KB",       .orange)
        }
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    EveningPreviewSheet(
        rotationDay: 0,
        progressions: SkillProgressions.defaultSkillProgressions
    )
}
#endif

