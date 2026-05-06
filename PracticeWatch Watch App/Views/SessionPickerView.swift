// SessionPickerView.swift — watchOS

import SwiftUI
import SwiftData

struct SessionPickerView: View {
    @Query private var settingsResults: [AppSettings]
    @Query private var progressions: [SkillProgressionRecord]
    @Query private var restDays: [RestDayRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorState.self) private var errorState
    
    private var settings: AppSettings {
        if let s = settingsResults.first { return s }
        let s = AppSettings()
        modelContext.insert(s)
        try? modelContext.save()
        return s
    }
    
    private var isRestDayToday: Bool {
        restDays.contains { Calendar.current.isDateInToday($0.date) }
    }
    
    private var rotationLabel: String {
        let names = Skill.activeSkills.map { $0.rawValue }
        return "Evening: \(names[settings.eveningRotationDay % Skill.activeSkills.count])"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                ForEach(SessionType.allCases, id: \.self) { type in
                    NavigationLink(value: type) {
                        Label(type.displayName,
                              systemImage: type == .morning ? "sun.max.fill" : "moon.stars.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            type == .morning
                            ? Color.orange.opacity(0.3)
                            : Color.indigo.opacity(0.3)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                
                // Rest day toggle
                Button {
                    toggleRestDay()
                } label: {
                    Label(
                        isRestDayToday ? "Rest Day ✓" : "Mark Rest Day",
                        systemImage: isRestDayToday ? "bed.double.fill" : "bed.double"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isRestDayToday ? Color.gray.opacity(0.35) : Color.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: WatchRecoveryView()) {
                    Label("Recovery", systemImage: "heart.text.square.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(rotationLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .navigationDestination(for: SessionType.self) { type in
                WorkoutGuideView(plan: plan(for: type))
            }
            .onAppear {
                ensureDefaultProgressions()
                requestSyncIfNeeded()
            }
            .navigationTitle("Practice")
        }
    }
    
    // MARK: - Rest day
    
    private func toggleRestDay() {
        let isCurrentlyRest = restDays.contains { Calendar.current.isDateInToday($0.date) }
        
        if isCurrentlyRest {
            restDays
                .filter { Calendar.current.isDateInToday($0.date) }
                .forEach { modelContext.delete($0) }
        } else {
            modelContext.insert(RestDayRecord())
        }
        
        do {
            try modelContext.save()
            // Sync rest day state to iOS so its consistency score stays accurate
            WatchConnectivityManager.shared.sendRestDay(isRestDay: !isCurrentlyRest)
        } catch {
            errorState.post("Could not save rest day.")
        }
    }
    
    // MARK: - Session plan
    
    private func plan(for type: SessionType) -> SessionPlan {
        let valueProgressions = progressions.map { $0.toSkillProgression() }
        switch type {
        case .morning:
            return SessionPlan(sessionType: .morning, steps: WorkoutData.morningSteps, estimatedDurationMinutes: 60)
        case .evening:
            return SessionPlan(
                sessionType: .evening,
                steps: WorkoutData.eveningSteps(
                    rotationDay: settings.eveningRotationDay,
                    progressions: valueProgressions
                ),
                estimatedDurationMinutes: 30
            )
        }
    }
    
    // MARK: - First-launch setup
    
    private func ensureDefaultProgressions() {
        let existingNames = Set(progressions.map { $0.skillName })
        for def in SkillProgressions.defaultSkillProgressions where !existingNames.contains(def.skillName) {
            modelContext.insert(SkillProgressionRecord(from: def))
        }
        try? modelContext.save()
    }
    
    /// Silently request a full sync from iOS on first launch (no settings yet)
    /// so the watch has current progressions, rotation day, and recovery score.
    private func requestSyncIfNeeded() {
        WatchConnectivityManager.shared.requestFullSync()
    }
}
