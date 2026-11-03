// SettingsView.swift — iOS

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsResults: [AppSettings]
    @Query private var progressionRecords: [SkillProgressionRecord]
    
    private var settings: AppSettings {
        if let s = settingsResults.first { return s }
        let s = AppSettings()
        modelContext.insert(s)
        return s
    }
    
    @State private var notificationsGranted = false
    @State private var showingMilestoneSheet = false
    
    var body: some View {
        NavigationStack {
            Form {
                
                // MARK: S&S Target
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current milestone target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Swing target")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(formatWeight(settings.targetSwingWeightKg))
                                    .font(.headline)
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TGU target")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(formatWeight(settings.targetTGUWeightKg))
                                    .font(.headline)
                            }
                        }
                        
                        Picker("Milestone preset", selection: milestoneBinding) {
                            Text("S&S Simple (Men)").tag("men")
                            Text("S&S Simple (Women)").tag("women")
                            Text("Custom").tag("custom")
                        }
                        .pickerStyle(.segmented)
                        
                        if milestonePreset == "custom" {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Swing (kg)").font(.caption2)
                                    Picker("", selection: Binding(
                                        get: { settings.targetSwingWeightKg },
                                        set: { settings.targetSwingWeightKg = $0; persistSettings(pushSync: true) }
                                    )) {
                                        ForEach(
                                            WorkoutData.kbWeights,
                                            id: \.self
                                        ) {
                                            w in Text(formatWeight(w)).tag(w)
                                        }
                                    }
                                    .labelsHidden()
                                }
                                Spacer()
                                VStack(alignment: .leading) {
                                    Text("TGU (kg)").font(.caption2)
                                    Picker("", selection: Binding(
                                        get: { settings.targetTGUWeightKg },
                                        set: { settings.targetTGUWeightKg = $0; persistSettings(pushSync: true) }
                                    )) {
                                        ForEach(
                                            WorkoutData.kbWeights,
                                            id: \.self
                                        ) {
                                            w in Text(formatWeight(w)).tag(w)
                                        }
                                    }
                                    .labelsHidden()
                                }
                            }
                        }
                    }
                } header: {
                    Label("S&S Targets", systemImage: "flag.checkered")
                }
                
                Section {
                    kettlebellPlanRow(
                        title: "Swings",
                        currentWeight: Binding(
                            get: { settings.currentSwingWeightKg },
                            set: { settings.currentSwingWeightKg = $0; persistSettings(pushSync: true) }
                        ),
                        progressionWeight: Binding(
                            get: { settings.swingProgressionWeightKg },
                            set: { settings.swingProgressionWeightKg = $0; persistSettings(pushSync: true) }
                        ),
                        progressionSets: Binding(
                            get: { evenProgressionSetCount(settings.swingProgressionSetCount) },
                            set: { settings.swingProgressionSetCount = evenProgressionSetCount($0); persistSettings(pushSync: true) }
                        )
                    )
                    
                    kettlebellPlanRow(
                        title: "Turkish Get-Ups",
                        currentWeight: Binding(
                            get: { settings.currentTGUWeightKg },
                            set: { settings.currentTGUWeightKg = $0; persistSettings(pushSync: true) }
                        ),
                        progressionWeight: Binding(
                            get: { settings.tguProgressionWeightKg },
                            set: { settings.tguProgressionWeightKg = $0; persistSettings(pushSync: true) }
                        ),
                        progressionSets: Binding(
                            get: { evenProgressionSetCount(settings.tguProgressionSetCount) },
                            set: { settings.tguProgressionSetCount = evenProgressionSetCount($0); persistSettings(pushSync: true) }
                        )
                    )
                } header: {
                    Label("Kettlebell Working Weights", systemImage: "scalemass")
                }
                
                // MARK: Notifications
                Section {
                    Toggle("Enable Reminders", isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: { settings.notificationsEnabled = $0; persistSettings(); updateNotifications() }
                    ))
                    
                    if settings.notificationsEnabled && notificationsGranted {
                        timePicker("Morning reminder", hour: Binding(get: { settings.morningReminderHour }, set: { settings.morningReminderHour = $0 }),
                                   minute: Binding(get: { settings.morningReminderMinute }, set: { settings.morningReminderMinute = $0 }))
                        timePicker("Evening reminder", hour: Binding(get: { settings.eveningReminderHour }, set: { settings.eveningReminderHour = $0 }),
                                   minute: Binding(get: { settings.eveningReminderMinute }, set: { settings.eveningReminderMinute = $0 }))
                    }
                    
                    if settings.notificationsEnabled && !notificationsGranted {
                        Label("Notification permission required. Enable in Settings.", systemImage: "bell.slash")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Label("Notifications", systemImage: "bell.badge")
                }
                
                Section("Body measurements") {
                    NavigationLink("Body profile & scale") { BodyProfileSettingsView() }
                }

                // MARK: Weigh-in reminder
                Section {
                    WeighInReminderRow()
                } header: {
                    Label("Weekly Weigh-In", systemImage: "scalemass")
                }
                

            }
            .navigationTitle("Settings")
            .task {
                notificationsGranted = (try? await NotificationManager.shared.requestAuthorization()) ?? false
            }
            .onChange(of: settings.morningReminderHour)   { updateNotifications() }
            .onChange(of: settings.morningReminderMinute) { updateNotifications() }
            .onChange(of: settings.eveningReminderHour)   { updateNotifications() }
            .onChange(of: settings.eveningReminderMinute) { updateNotifications() }
        }
    }
    
    // MARK: Helpers
    
    private var milestonePreset: String {
        if settings.targetSwingWeightKg == AppSettings.menSimple.swing &&
            settings.targetTGUWeightKg   == AppSettings.menSimple.tgu { return "men" }
        if settings.targetSwingWeightKg == AppSettings.womenSimple.swing &&
            settings.targetTGUWeightKg   == AppSettings.womenSimple.tgu { return "women" }
        return "custom"
    }
    
    private var milestoneBinding: Binding<String> {
        Binding(
            get: { milestonePreset },
            set: { preset in
                switch preset {
                case "men":
                    settings.targetSwingWeightKg = AppSettings.menSimple.swing
                    settings.targetTGUWeightKg   = AppSettings.menSimple.tgu
                    persistSettings(pushSync: true)
                case "women":
                    settings.targetSwingWeightKg = AppSettings.womenSimple.swing
                    settings.targetTGUWeightKg   = AppSettings.womenSimple.tgu
                    persistSettings(pushSync: true)
                default: break
                }
            }
        )
    }
    
    private func persistSettings(pushSync: Bool = false) {
        settings.swingProgressionSetCount = evenProgressionSetCount(settings.swingProgressionSetCount)
        settings.tguProgressionSetCount = evenProgressionSetCount(settings.tguProgressionSetCount)
        try? modelContext.save()
        AppGroupDefaults.shared.updateKettlebellTargets(
            swing: settings.targetSwingWeightKg,
            tgu: settings.targetTGUWeightKg
        )
        AppGroupDefaults.shared.updateKettlebellPlan(
            currentSwing: settings.currentSwingWeightKg,
            currentTGU: settings.currentTGUWeightKg,
            progressionSwing: settings.swingProgressionWeightKg,
            progressionTGU: settings.tguProgressionWeightKg,
            swingProgressionSets: settings.swingProgressionSetCount,
            tguProgressionSets: settings.tguProgressionSetCount
        )
        
        if pushSync {
            var payload = AppGroupDefaults.shared.loadAppContext()
            payload.skillProgressions = progressionRecords.map { $0.toSkillProgression() }
            payload.targetSwingWeightKg = settings.targetSwingWeightKg
            payload.targetTGUWeightKg = settings.targetTGUWeightKg
            payload.currentSwingWeightKg = settings.currentSwingWeightKg
            payload.currentTGUWeightKg = settings.currentTGUWeightKg
            payload.swingProgressionWeightKg = settings.swingProgressionWeightKg
            payload.tguProgressionWeightKg = settings.tguProgressionWeightKg
            payload.swingProgressionSetCount = settings.swingProgressionSetCount
            payload.tguProgressionSetCount = settings.tguProgressionSetCount
            AppGroupDefaults.shared.saveAppContext(payload)
            WatchConnectivityManager.shared.sendFullSync(payload: payload)
        }
    }
    
    private func updateNotifications() {
        persistSettings()
        guard settings.notificationsEnabled else {
            NotificationManager.shared.cancelAllReminders()
            return
        }
        NotificationManager.shared.scheduleMorningReminder(hour: settings.morningReminderHour, minute: settings.morningReminderMinute)
        NotificationManager.shared.scheduleEveningReminder(hour: settings.eveningReminderHour, minute: settings.eveningReminderMinute, skillFocus: "tonight's skill")
    }
    
    @ViewBuilder
    private func kettlebellPlanRow(
        title: String,
        currentWeight: Binding<Double>,
        progressionWeight: Binding<Double>,
        progressionSets: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Picker("Normal", selection: currentWeight) {
                ForEach(WorkoutData.kbWeights, id: \.self) { weight in
                    Text(formatWeight(weight)).tag(weight)
                }
            }
            Picker("Progression", selection: progressionWeight) {
                ForEach(WorkoutData.kbWeights, id: \.self) { weight in
                    Text(formatWeight(weight)).tag(weight)
                }
            }
            Stepper("Progression sets: \(progressionSets.wrappedValue)", value: progressionSets, in: 0...10, step: 2)
                .font(.subheadline)
            Text(progressionDescription(for: progressionSets.wrappedValue))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func timePicker(_ label: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        DatePicker(label, selection: Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: hour.wrappedValue, minute: minute.wrappedValue)) ?? Date()
            },
            set: { d in
                hour.wrappedValue   = Calendar.current.component(.hour, from: d)
                minute.wrappedValue = Calendar.current.component(.minute, from: d)
            }
        ), displayedComponents: .hourAndMinute)
    }
    
    
    private func evenProgressionSetCount(_ value: Int) -> Int {
        min(max(value, 0), 10) / 2 * 2
    }
    
    private func progressionDescription(for setCount: Int) -> String {
        let slots = progressionSetSlots(totalSets: 10, progressionSetCount: setCount)
        guard !slots.isEmpty else { return "All sets use the normal weight." }
        return "Progression weight on sets \(slots.map(String.init).joined(separator: ", "))."
    }
    
    private func progressionSetSlots(totalSets: Int, progressionSetCount: Int) -> [Int] {
        let middleSlots = totalSets >= 4 ? Array(3...totalSets) : []
        let startingSlots = min(totalSets, 2) >= 1 ? Array(1...min(totalSets, 2)) : []
        return Array((middleSlots + startingSlots).prefix(evenProgressionSetCount(progressionSetCount)))
    }
    
    private func formatWeight(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg)) kg" : "\(kg) kg"
    }
}

// MARK: - Weigh-in reminder sub-row

private struct WeighInReminderRow: View {
    @AppStorage("weighInEnabled")  private var enabled  = false
    @AppStorage("weighInWeekday")  private var weekday  = 1   // Sunday
    @AppStorage("weighInHour")     private var hour     = 8
    @AppStorage("weighInMinute")   private var minute   = 0
    
    private let weekdayNames = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    
    var body: some View {
        Toggle("Weekly reminder", isOn: $enabled)
            .onChange(of: enabled) { updateReminder() }
        
        if enabled {
            Picker("Day", selection: $weekday) {
                ForEach(1...7, id: \.self) { d in
                    Text(weekdayNames[d - 1]).tag(d)
                }
            }
            .onChange(of: weekday) { updateReminder() }
            
            DatePicker("Time", selection: Binding(
                get: { Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date() },
                set: { d in
                    hour   = Calendar.current.component(.hour, from: d)
                    minute = Calendar.current.component(.minute, from: d)
                    updateReminder()
                }
            ), displayedComponents: .hourAndMinute)
        }
    }
    
    private func updateReminder() {
        if enabled {
            NotificationManager.shared.scheduleWeighInReminder(weekday: weekday, hour: hour, minute: minute)
        } else {
            NotificationManager.shared.cancelWeighInReminder()
        }
    }
}
