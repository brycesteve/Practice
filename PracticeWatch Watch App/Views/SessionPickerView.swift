// SessionPickerView.swift — watchOS

import SwiftUI
import SwiftData

struct SessionPickerView: View {
    @Environment(ErrorState.self) private var errorState
    
    @State private var settings = AppGroupDefaults.shared.loadAppContext()
    
    private var isRestDayToday: Bool {
        settings.restDays.contains { Calendar.current.isDateInToday($0) }
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
                
                requestSyncIfNeeded()
            }
            .navigationTitle("Practice")
        }
    }
    
    // MARK: - Rest day
    
    private func toggleRestDay() {
        let isCurrentlyRest = isRestDayToday
        
        var newRestDays = settings.restDays
        if isCurrentlyRest {
            newRestDays = settings.restDays.filter { !Calendar.current.isDateInToday($0)}
        } else {
            newRestDays.append(Date())
        }
    
        AppGroupDefaults.shared.updateRestDays(newRestDays)
        settings = AppGroupDefaults.shared.loadAppContext()
        // Sync rest day state to iOS so its consistency score stays accurate
        WatchConnectivityManager.shared.sendRestDay(isRestDay: !isCurrentlyRest)
    }
    
    // MARK: - Session plan
    
    private func plan(for type: SessionType) -> SessionPlan {
        let valueProgressions = settings.skillProgressions
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
        let existingNames = Set(settings.skillProgressions.map { $0.skillName })
        for def in SkillProgressions.defaultSkillProgressions where !existingNames.contains(def.skillName) {
            settings.addSkillProgression(def)
        }
        settings = AppGroupDefaults.shared.loadAppContext()
    }
    
    /// Silently request a full sync from iOS on first launch (no settings yet)
    /// so the watch has current progressions, rotation day, and recovery score.
    private func requestSyncIfNeeded() {
        WatchConnectivityManager.shared.requestFullSync()
    }
}
