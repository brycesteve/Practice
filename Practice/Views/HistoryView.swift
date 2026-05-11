// HistoryView.swift — iOS
// All @Relationship arrays are optional in the CloudKit-compatible schema,
// so every access uses nil-coalescing (?? []) or optional chaining.

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Binding var path: NavigationPath
    @Query(sort: \WorkoutRecord.startDate, order: .reverse) private var allWorkouts: [WorkoutRecord]
    @State private var filterType: SessionType? = nil
    
    private var filtered: [WorkoutRecord] {
        guard let f = filterType else { return allWorkouts }
        return allWorkouts.filter { $0.sessionTypeRaw == f.rawValue }
    }
    
    var body: some View {

        List {
            Section {
                Picker("Filter", selection: $filterType) {
                    Text("All").tag(Optional<SessionType>.none)
                    ForEach(SessionType.allCases, id: \.self) { t in
                        Text(t.displayName).tag(Optional(t))
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            
            ForEach(groupedByMonth(filtered), id: \.key) { section in
                Section(section.key) {
                    ForEach(section.workouts) { workout in
                        NavigationLink(value: workout) {
                            WorkoutRowView(workout: workout)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationDestination(for: WorkoutRecord.self) { workout in
            WorkoutDetailView(workout: workout)
        }
    }
    
    private struct MonthSection: Identifiable {
        let key: String; let workouts: [WorkoutRecord]; var id: String { key }
    }
    
    private func groupedByMonth(_ workouts: [WorkoutRecord]) -> [MonthSection] {
        let fmt = DateFormatter(); fmt.dateFormat = "MMMM yyyy"
        var dict: [String: [WorkoutRecord]] = [:]
        for w in workouts { dict[fmt.string(from: w.startDate), default: []].append(w) }
        return dict.keys.sorted().reversed().map { key in
            MonthSection(key: key, workouts: dict[key]!.sorted { $0.startDate > $1.startDate })
        }
    }
}

// MARK: - Row

struct WorkoutRowView: View {
    let workout: WorkoutRecord
    
    // exercises is [ExerciseRecord]? in the CloudKit schema — unwrap safely
    private var exerciseCount: Int { workout.exercises?.count ?? 0 }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(workout.sessionType.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.sessionType.displayName).font(.headline)
                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(workout.durationMinutes) min").font(.subheadline.bold())
                if let cal = workout.activeCalories {
                    Text("\(Int(cal)) kcal").font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

struct WorkoutDetailView: View {
    let workout: WorkoutRecord
    
    // Unwrap optional relationship arrays once, reuse throughout the view
    private var exercises: [ExerciseRecord] { workout.exercisesSorted }
    
    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Session",  value: workout.sessionType.displayName)
                LabeledContent("Date",     value: workout.startDate.formatted(date: .complete, time: .shortened))
                LabeledContent("Duration", value: "\(workout.durationMinutes) min")
                if let cal = workout.activeCalories {
                    LabeledContent("Calories") {
                        Label("\(Int(cal)) kcal", systemImage: "flame.fill").foregroundStyle(.orange)
                    }
                }
                if let hr = workout.averageHeartRate {
                    LabeledContent("Avg HR") {
                        Label("\(Int(hr)) bpm", systemImage: "heart.fill").foregroundStyle(.red)
                    }
                }
                if let peak = workout.peakHeartRate {
                    LabeledContent("Peak HR", value: "\(Int(peak)) bpm")
                }
                if let notes = workout.notes, !notes.isEmpty {
                    LabeledContent("Notes", value: notes)
                }
            }
            
            if exercises.isEmpty {
                Section("Exercises") {
                    Text("No exercises logged.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Section("Exercises") {
                    ForEach(exercises) { ex in
                        ExerciseDisclosureRow(exercise: ex)
                    }
                }
            }
        }
        .navigationTitle(workout.sessionType.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Exercise disclosure row
// Extracted to its own view so each row independently unwraps its optional sets array

struct ExerciseDisclosureRow: View {
    let exercise: ExerciseRecord
    
    // sets is [SetRecord]? — unwrap once via the helper on ExerciseRecord
    private var sets: [SetRecord] { exercise.setsSorted }
    
    var body: some View {
        DisclosureGroup {
            if sets.isEmpty {
                Text("No sets logged.")
                    .font(.caption2).foregroundStyle(.tertiary)
            } else {
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, s in
                    SetRow(index: index, set: s)
                }
            }
        } label: {
            HStack {
                Text(exercise.exerciseName).font(.subheadline)
                Spacer()
                Text(sets.isEmpty ? "Skipped" : "\(sets.count) sets")
                    .font(.caption)
                    .foregroundStyle(sets.isEmpty ? .tertiary : .secondary)
            }
        }
    }
}

// MARK: - Set row (with edit on long press)

struct SetRow: View {
    let index: Int
    let set: SetRecord
    
    @Environment(\.modelContext) private var modelContext
    @State private var showEdit = false
    
    var body: some View {
        HStack {
            if let side = set.tguSide {
                Text("Set \(index + 1) · \(side.label)")
                    .font(.caption)
                    .foregroundStyle(side == .left ? .blue : .orange)
            } else {
                Text("Set \(index + 1)").font(.caption)
            }
            Spacer()
            if let r = set.reps            { Text("\(r) reps").font(.caption) }
            if let d = set.durationSeconds { Text("\(d)s").font(.caption)     }
            Text(set.feltDifficulty.emoji)
            
            Image(systemName: "pencil")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { showEdit = true }
        .sheet(isPresented: $showEdit) {
            EditSetSheet(set: set)
        }
    }
}

// MARK: - Edit Set Sheet

struct EditSetSheet: View {
    let set: SetRecord
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var reps: Int
    @State private var duration: Int
    @State private var difficulty: DifficultyRating
    
    private var isTimed: Bool { self.set.durationSeconds != nil }
    
    init(set: SetRecord) {
        self.set = set
        _reps     = State(initialValue: set.reps ?? 0)
        _duration = State(initialValue: set.durationSeconds ?? 0)
        _difficulty = State(initialValue: set.feltDifficulty)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Performance") {
                    if isTimed {
                        Stepper("Duration: \(duration)s", value: $duration, in: 0...600, step: 1)
                    } else {
                        Stepper("Reps: \(reps)", value: $reps, in: 0...200, step: 1)
                    }
                }
                Section("Effort") {
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(DifficultyRating.allCases, id: \.self) { d in
                            Label("\(d.emoji) \(d.label)", systemImage: "").tag(d)
                        }
                    }
                }
            }
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        set.reps            = isTimed ? nil : reps
                        set.durationSeconds = isTimed ? duration : nil
                        set.difficultyRaw   = difficulty.rawValue
                        try? modelContext.save()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
