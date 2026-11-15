import Foundation

/// Reminders are local device preferences, matching the existing weekly weigh-in reminder.
/// Photo and waist data sync independently of notification permissions or these preferences.
@MainActor
enum ProgressReminderSettings {
    // Serialise edits per reminder. An older asynchronous add must finish before a newer
    // edit/cancellation, otherwise fast changes can restore a stale notification request.
    private static var pending: [String: Task<Void, Error>] = [:]
    private static var desiredMasterEnabled = true

    static func key(_ kind: NotificationManager.ProgressReminder, _ field: String) -> String {
        "progressReminder.\(kind.rawValue).\(field)"
    }
    static func integer(_ field: String, kind: NotificationManager.ProgressReminder,
                        fallback: Int, defaults: UserDefaults = .standard) -> Int {
        let key = key(kind, field)
        return defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
    }
    static func reschedule(_ kind: NotificationManager.ProgressReminder, masterEnabled: Bool,
                           defaults: UserDefaults = .standard) async throws {
        desiredMasterEnabled = masterEnabled
        try await enqueue(kind, defaults: defaults)
    }
    private static func enqueue(_ kind: NotificationManager.ProgressReminder, defaults: UserDefaults = .standard) async throws {
        let previous = pending[kind.rawValue]
        let next = Task { @MainActor in
            _ = try? await previous?.value
            let manager = NotificationManager.shared
            guard desiredMasterEnabled && defaults.bool(forKey: key(kind, "enabled")) else {
                manager.cancelProgressReminder(kind)
                return
            }
            guard await manager.isAuthorized else {
                manager.cancelProgressReminder(kind)
                throw NSError(domain: "PracticeReminders", code: 1, userInfo: [NSLocalizedDescriptionKey:
                    "Notifications are disabled. Allow notifications for Practice in Settings to receive this reminder."])
            }
            guard desiredMasterEnabled && defaults.bool(forKey: key(kind, "enabled")) else {
                manager.cancelProgressReminder(kind)
                return
            }
            try await manager.scheduleProgressReminder(kind,
                day: integer("day", kind: kind, fallback: 1, defaults: defaults),
                hour: integer("hour", kind: kind, fallback: 8, defaults: defaults),
                minute: integer("minute", kind: kind, fallback: 0, defaults: defaults))
        }
        pending[kind.rawValue] = next
        try await next.value
    }
    static func rescheduleAll(masterEnabled: Bool) async throws {
        desiredMasterEnabled = masterEnabled
        var firstError: Error?
        for kind in [NotificationManager.ProgressReminder.waist, .photos] {
            do { try await enqueue(kind) }
            catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
    }
}
