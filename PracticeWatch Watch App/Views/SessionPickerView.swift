// SessionPickerView.swift — watchOS (Refined UI Design)

import SwiftUI
import SwiftData

struct SessionPickerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var programmeDate = Date()
    @Environment(ErrorState.self) private var errorState
    @State private var settings = AppGroupDefaults.shared.loadAppContext()
    @State private var activeWorkout = WatchActiveWorkoutStore.shared
    @State private var sessionManager = WorkoutSessionManager.shared
    
    private var isRestDayToday: Bool {
        settings.restDays.contains { Calendar.current.isDateInToday($0) }
    }
    
    private var forcedRest: Bool {
        DailyPractice.requiresRest(history: settings.trainingHistory, on: programmeDate)
    }
    private var resting: Bool { forcedRest || isRestDayToday }
    private var scheduledSession: SessionType? {
        DailyPractice.suggestedSession(history: settings.trainingHistory, restDays: settings.restDays, on: programmeDate)
    }
    private var offeredSessions: [SessionType] {
        [scheduledSession, .jointStretches, .evening].compactMap { $0 }
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
                    if scheduledSession == nil {
                        Text(forcedRest ? "Recovery day" : "Rest day")
                            .font(.headline)
                        Text(forcedRest ? "Six training days in a row. Take today to recover." : "Gentle movement and stretching today.")
                            .font(.caption).foregroundStyle(WatchAppearance.supportingText)
                    }
                    ForEach(offeredSessions, id: \.self) { type in
                        NavigationLink(value: type) {
                            sessionTile(for: type)
                        }
                        .buttonStyle(.plain)
                        .disabled(sessionManager.isRunning)
                        .opacity(sessionManager.isRunning ? 0.65 : 1)
                    }
                    
                    if !resting {
                        NavigationLink {
                            List {
                                ForEach([SessionType.morning, .strengthA, .mobility, .strengthB], id: \.self) { type in
                                    NavigationLink(type.displayName) {
                                        WorkoutGuideView(plan: plan(for: type))
                                    }
                                }
                                Text("The next suggestion follows the session you log. Missed days leave it waiting.")
                                    .font(.footnote)
                                    .foregroundStyle(WatchAppearance.supportingText)
                            }
                            .navigationTitle("Choose session")
                        } label: {
                            Label("Choose another session", systemImage: "list.bullet")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(SecondaryTileStyle(isActive: false))
                        .disabled(sessionManager.isRunning)
                    }

                    NavigationLink(destination: ScaleMeasurementView()) {
                        HStack {
                            Image(systemName: "scalemass")
                            Text("Body Measurement")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(WatchAppearance.supportingText)
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
                                Text(forcedRest ? "Recovery day required" : isRestDayToday ? "Rest Day Active" : "Mark Rest Day")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(WatchAppearance.supportingText)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(SecondaryTileStyle(isActive: resting))
                        .disabled(forcedRest || sessionManager.isRunning)
                        
                        NavigationLink(destination: WatchRecoveryView()) {
                            HStack {
                                Image(systemName: "heart.text.square.fill")
                                Text("Recovery")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(WatchAppearance.supportingText)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(SecondaryTileStyle(isActive: false))
                    }
                    .padding(.top, 4)
                    
                    Spacer(minLength: 8)
                    
                    Text(resting ? "Evening: gentle stretching" : rotationLabel)
                        .font(.footnote)
                        .foregroundStyle(WatchAppearance.supportingText)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Practice")
            .navigationDestination(for: SessionType.self) { type in
                if type == .evening && resting {
                    WorkoutGuideView(plan: WorkoutData.restEveningPlan)
                } else if type == .evening {
                    EveningSessionSelectionView(settings: settings, programmeDate: programmeDate)
                } else {
                    WorkoutGuideView(plan: plan(for: type))
                }
            }
            .onAppear {
                programmeDate = .now
                settings = AppGroupDefaults.shared.loadAppContext()
                requestSyncIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { programmeDate = .now }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                programmeDate = .now
            }
            .onReceive(NotificationCenter.default.publisher(for: .syncPayloadReceived)) { _ in
                settings = AppGroupDefaults.shared.loadAppContext()
            }
        }
    }
    
    // MARK: - Session Tile
    
    @ViewBuilder
    private func resumeTile(for plan: SessionPlan) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "figure.run.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Resume Workout")
                    .font(.caption).fontWeight(.semibold)
                Text("\(plan.sessionType.displayName) · \(formatDuration(sessionManager.elapsedSeconds))")
                    .font(.caption)
                    .foregroundStyle(WatchAppearance.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
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
        
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: config.icon)
                .font(.title2)
                .foregroundStyle(config.tint)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(type == scheduledSession ? "Next: \(type.displayName)" : type == .evening && resting ? "Evening stretching" : type.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(config.subtitle)
                    .font(.caption)
                    .foregroundStyle(WatchAppearance.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
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
            return ("sunrise.fill", .yellow, "Warm-up · 100 swings · 10 get-ups")
        case .evening:
            return ("moon.stars", .cyan, resting ? "Gentle stretching · skill rotation waits" : "Skill & mobility")
        case .strengthA, .strengthB:
            return ("figure.strengthtraining.functional", .orange, "Controlled strength · 2–3 reps in reserve")
        case .mobility:
            return ("figure.flexibility", .green, "Full-body mobility · bridge holds")
        case .jointStretches:
            return ("figure.mind.and.body", .mint, "Morning mobility · at your own pace")
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
        WorkoutData.plan(for: type, rotationDay: settings.eveningRotationDay,
                         progressions: settings.skillProgressions, on: programmeDate)
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
    let programmeDate: Date
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
                WorkoutGuideView(plan: WorkoutData.eveningPlan(for: chosen,
                    progressions: settings.skillProgressions, on: programmeDate))
            }
            Text("Your next automatic suggestion follows the skill you actually complete.")
                .font(.footnote).foregroundStyle(WatchAppearance.supportingText)
        }
        .navigationTitle("Evening skill")
    }
}
