// SessionPickerView.swift — watchOS (Refined UI Design)

import SwiftUI
import SwiftData

struct SessionPickerView: View {
    @Environment(ErrorState.self) private var errorState
    @State private var settings = AppGroupDefaults.shared.loadAppContext()
    @State private var activeWorkout = WatchActiveWorkoutStore.shared
    @State private var sessionManager = WorkoutSessionManager.shared
    
    private var isRestDayToday: Bool {
        settings.restDays.contains { Calendar.current.isDateInToday($0) }
    }
    
    private var rotationLabel: String {
        let names = Skill.activeSkills.map { $0.rawValue }
        return "Evening: \(names[EveningRotation.normalized(settings.eveningRotationDay)])"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if sessionManager.isRunning, let activePlan = activeWorkout.activePlan {
                        NavigationLink(destination: WorkoutGuideView(plan: activePlan)) {
                            resumeTile(for: activePlan)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - Session Tiles
                    ForEach(SessionType.allCases, id: \ .self) { type in
                        NavigationLink(value: type) {
                            sessionTile(for: type)
                        }
                        .buttonStyle(.plain)
                        .disabled(sessionManager.isRunning)
                        .opacity(sessionManager.isRunning ? 0.45 : 1)
                    }
                    
                    NavigationLink(destination: ScaleMeasurementView()) {
                        HStack {
                            Image(systemName: "scalemass")
                            Text("Body Measurement")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(SecondaryTileStyle(isActive: false))
                    .disabled(sessionManager.isRunning)

                    // MARK: - Secondary Actions
                    VStack(spacing: 10) {
                        
                        Button {
                            toggleRestDay()
                        } label: {
                            HStack {
                                Image(systemName: isRestDayToday ? "bed.double.fill" : "bed.double")
                                Text(isRestDayToday ? "Rest Day Active" : "Mark Rest Day")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(SecondaryTileStyle(isActive: isRestDayToday))
                        
                        NavigationLink(destination: WatchRecoveryView()) {
                            HStack {
                                Image(systemName: "heart.text.square.fill")
                                Text("Recovery")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(SecondaryTileStyle(isActive: false))
                    }
                    .padding(.top, 4)
                    
                    Spacer(minLength: 8)
                    
                    Text(rotationLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Practice")
            .navigationDestination(for: SessionType.self) { type in
                if type == .evening {
                    EveningSessionSelectionView(settings: settings)
                } else {
                    WorkoutGuideView(plan: plan(for: type))
                }
            }
            .onAppear {
                settings = AppGroupDefaults.shared.loadAppContext()
                requestSyncIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .syncPayloadReceived)) { _ in
                settings = AppGroupDefaults.shared.loadAppContext()
            }
        }
    }
    
    // MARK: - Session Tile
    
    @ViewBuilder
    private func resumeTile(for plan: SessionPlan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Resume Workout")
                    .font(.caption).fontWeight(.semibold)
                Text("\(plan.sessionType.displayName) · \(formatDuration(sessionManager.elapsedSeconds))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.green.opacity(0.24))
        )
    }
    
    @ViewBuilder
    private func sessionTile(for type: SessionType) -> some View {
        let config = sessionConfig(for: type)
        
        HStack(spacing: 12) {
            Image(systemName: config.icon)
                .font(.title2)
                .foregroundStyle(config.tint)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.caption).fontWeight(.semibold)
                Text(config.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
        }
        
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(config.tint.opacity(0.22))
            
        )
    }
    
    private func sessionConfig(for type: SessionType) -> (icon: String, tint: Color, subtitle: String) {
        switch type {
        case .morning:
            return ("sunrise.fill", .yellow, "Strength & conditioning")
        case .evening:
            return ("moon.stars", .indigo, "Skill & mobility")
        }
    }
    
    // MARK: - Secondary Tile Style
    
    struct SecondaryTileStyle: ButtonStyle {
        let isActive: Bool
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.caption)
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isActive ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .opacity(configuration.isPressed ? 0.85 : 1.0)
        }
    }
    
    // MARK: - Rest Day
    
    private func toggleRestDay() {
        let isCurrentlyRest = isRestDayToday
        
        var newRestDays = settings.restDays
        if isCurrentlyRest {
            newRestDays = settings.restDays.filter { !Calendar.current.isDateInToday($0) }
        } else {
            newRestDays.append(Date())
        }
        
        AppGroupDefaults.shared.updateRestDays(newRestDays)
        settings = AppGroupDefaults.shared.loadAppContext()
        
        WatchConnectivityManager.shared.sendRestDay(isRestDay: !isCurrentlyRest)
    }
    
    // MARK: - Session Plan
    
    private func plan(for type: SessionType) -> SessionPlan {
        let valueProgressions = settings.skillProgressions
        
        switch type {
        case .morning:
            return SessionPlan(
                sessionType: .morning,
                steps: WorkoutData.morningSteps,
                estimatedDurationMinutes: 60
            )
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
    
    // MARK: - Sync
    
    private func requestSyncIfNeeded() {
        WatchConnectivityManager.shared.requestFullSync()
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    SessionPickerView()
        .environment(ErrorState())
}

/// Selection changes only this plan. Automatic rotation changes only after logged skill completion.
private struct EveningSessionSelectionView: View {
    let settings: WCSyncPayload
    @State private var selectedSkill = ""

    private var automatic: Skill { Skill.activeSkills[EveningRotation.normalized(settings.eveningRotationDay)] }
    private var chosen: Skill { Skill(rawValue: selectedSkill) ?? automatic }

    var body: some View {
        List {
            Picker("Tonight's skill", selection: $selectedSkill) {
                Text("Automatic: \(automatic.rawValue)").tag("")
                ForEach(Skill.activeSkills, id: \.rawValue) { skill in
                    Text(skill.rawValue).tag(skill.rawValue)
                }
            }
            NavigationLink("Prepare \(chosen.rawValue)") {
                WorkoutGuideView(plan: SessionPlan(sessionType: .evening,
                    steps: chosen.routine(from: settings.skillProgressions), estimatedDurationMinutes: 30))
            }
            Text("Your next automatic suggestion follows the skill you actually complete.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Evening skill")
    }
}
