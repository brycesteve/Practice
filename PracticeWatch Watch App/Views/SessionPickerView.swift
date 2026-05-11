// SessionPickerView.swift — watchOS (Refined UI Design)

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
                VStack(spacing: 12) {
                    
                    // MARK: - Session Tiles
                    ForEach(SessionType.allCases, id: \ .self) { type in
                        NavigationLink(value: type) {
                            sessionTile(for: type)
                        }
                        .buttonStyle(.plain)
                    }
                    
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
                WorkoutGuideView(plan: plan(for: type))
            }
            .onAppear {
                requestSyncIfNeeded()
            }
        }
    }
    
    // MARK: - Session Tile
    
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
}

#Preview {
    SessionPickerView()
        .environment(ErrorState())
}
