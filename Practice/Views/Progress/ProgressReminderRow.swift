import SwiftUI
import UIKit

struct ProgressReminderRow: View {
    let kind: NotificationManager.ProgressReminder
    let masterEnabled: Bool
    @AppStorage private var enabled: Bool
    @AppStorage private var day: Int
    @AppStorage private var hour: Int
    @AppStorage private var minute: Int
    @State private var errorMessage: String?

    init(kind: NotificationManager.ProgressReminder, masterEnabled: Bool) {
        self.kind = kind
        self.masterEnabled = masterEnabled
        _enabled = AppStorage(wrappedValue: false, ProgressReminderSettings.key(kind, "enabled"))
        _day = AppStorage(wrappedValue: 1, ProgressReminderSettings.key(kind, "day"))
        _hour = AppStorage(wrappedValue: 8, ProgressReminderSettings.key(kind, "hour"))
        _minute = AppStorage(wrappedValue: 0, ProgressReminderSettings.key(kind, "minute"))
    }
    private var scheduleIdentity: String { "\(masterEnabled)-\(enabled)-\(day)-\(hour)-\(minute)" }
    var body: some View {
        Group {
            Toggle(kind == .waist ? "Weekly waist reminder" : "Monthly photo reminder", isOn: $enabled)
                .disabled(!masterEnabled)
            if enabled {
                if kind == .waist {
                    Picker("Day", selection: $day) {
                        ForEach(1...7, id: \.self) { day in Text(Calendar.current.weekdaySymbols[day - 1]).tag(day) }
                    }.disabled(!masterEnabled)
                } else {
                    Picker("Day of month", selection: $day) {
                        ForEach(1...28, id: \.self) { day in Text("\(day)").tag(day) }
                    }.disabled(!masterEnabled)
                    Text("Days 1–28 occur every month.").font(.caption).foregroundStyle(.secondary)
                }
                DatePicker("Time", selection: Binding(
                    get: { Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now },
                    set: { value in
                        hour = Calendar.current.component(.hour, from: value)
                        minute = Calendar.current.component(.minute, from: value)
                    }), displayedComponents: .hourAndMinute).disabled(!masterEnabled)
            }
            if !masterEnabled {
                Text("Enable Reminders above to receive this reminder.").font(.caption).foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.orange)
                HStack {
                    Button("Retry") { Task { await update() } }
                    Spacer()
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            }
        }
        .task(id: scheduleIdentity) { await update() }
    }
    @MainActor private func update() async {
        do {
            try await ProgressReminderSettings.reschedule(kind, masterEnabled: masterEnabled)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}
