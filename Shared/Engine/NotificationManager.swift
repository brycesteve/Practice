// NotificationManager.swift — TrainingShared

import Foundation
@preconcurrency import UserNotifications

public final class NotificationManager: Sendable {
    
    public static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    
    private enum ID {
        static let morningReminder  = "morning.reminder"
        static let eveningReminder  = "evening.reminder"
        static let weighInReminder  = "weighin.reminder"
        static let waistReminder = "progress.waist.reminder"
        static let photoReminder = "progress.photo.reminder"
        static func milestone(_ name: String) -> String { "milestone.\(name)" }
        static func progression(_ skill: String) -> String { "progression.\(skill)" }
    }
    
    // MARK: - Authorization
    
    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
    
    public var isAuthorized: Bool {
        get async {
            await center.notificationSettings().authorizationStatus == .authorized
        }
    }
    
    // MARK: - Training reminders
    
    public func scheduleMorningReminder(hour: Int, minute: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [ID.morningReminder] + morningScheduleIDs)
        let content = UNMutableNotificationContent()
        content.title = "Today's practice"
        content.body = "Open your Watch for your next session or recovery day. Your programme follows completed sessions."
        content.sound = .default
        schedule(content: content, id: ID.morningReminder, hour: hour, minute: minute, repeats: true)
    }

    private var morningScheduleIDs: [String] { (2...7).map { "\(ID.morningReminder).\($0)" } }
    
    public func scheduleEveningReminder(hour: Int, minute: Int, skillFocus: String) {
        let content = UNMutableNotificationContent()
        content.title = "🌙 Evening Session"
        content.body  = "Open your Watch for \(skillFocus), or gentle stretching on a rest day."
        content.sound = .default
        schedule(content: content, id: ID.eveningReminder, hour: hour, minute: minute, repeats: true)
    }
    
    // MARK: - Weigh-in reminder
    
    /// Schedule a weekly weigh-in notification.
    /// - Parameters:
    ///   - weekday: 1 = Sunday … 7 = Saturday (Calendar weekday convention)
    ///   - hour / minute: time of day
    public func scheduleWeighInReminder(weekday: Int, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "⚖️ Weekly Weigh-In"
        content.body  = "Time to log your weight. Consistent tracking = better insight."
        content.sound = .default
        
        var components      = DateComponents()
        components.weekday  = weekday
        components.hour     = hour
        components.minute   = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: ID.weighInReminder, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [ID.weighInReminder])
        center.add(request)
    }
    
    public func cancelWeighInReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [ID.weighInReminder])
    }
    
    // MARK: - Private progress reminders

    public enum ProgressReminder: String, Sendable {
        case waist, photos
        public var identifier: String {
            switch self {
            case .waist: return ID.waistReminder
            case .photos: return ID.photoReminder
            }
        }
    }

    public static func progressReminderComponents(_ reminder: ProgressReminder, day: Int,
                                                  hour: Int, minute: Int) throws -> DateComponents {
        guard (0...23).contains(hour), (0...59).contains(minute),
              (reminder == .waist ? (1...7).contains(day) : (1...28).contains(day)) else {
            throw CocoaError(.coderInvalidValue)
        }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        if reminder == .waist { components.weekday = day }
        else { components.day = day }
        return components
    }

    /// Stable identifiers replace pending requests, so edits never accumulate reminders.
    public func scheduleProgressReminder(_ reminder: ProgressReminder, day: Int, hour: Int, minute: Int) async throws {
        let components = try Self.progressReminderComponents(reminder, day: day, hour: hour, minute: minute)
        let content = UNMutableNotificationContent()
        content.title = reminder == .waist ? "Weekly Waist Measurement" : "Monthly Progress Photos"
        content.body = reminder == .waist
            ? "Take a waist measurement and log it in Practice."
            : "Your next photo session is ready in Practice."
        content.sound = .default
        let request = UNNotificationRequest(identifier: reminder.identifier, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
        try await center.add(request)
    }

    public func cancelProgressReminder(_ reminder: ProgressReminder) {
        center.removePendingNotificationRequests(withIdentifiers: [reminder.identifier])
    }

    // MARK: - Milestone notifications (immediate delivery)
    
    public func notifyKettlebellMilestone(exerciseType: KettlebellExerciseType, weightKg: Double, isFinalGoal: Bool) {
        let content = UNMutableNotificationContent()
        if isFinalGoal {
            content.title = "🏆 S&S Simple achieved!"
            content.body  = "You hit \(exerciseType.shortName) at \(formatWeight(weightKg)). That's the Simple standard. Incredible."
        } else {
            content.title = "💪 New kettlebell PB!"
            content.body  = "\(exerciseType.shortName) at \(formatWeight(weightKg)) — a new personal best."
        }
        content.sound = .default
        deliver(content: content, id: ID.milestone("\(exerciseType.rawValue).\(weightKg)"))
    }
    
    public func notifySkillAdvancement(skillName: String, newLevelName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🎉 \(skillName) — Level Up!"
        content.body  = "You're ready for: \(newLevelName). Open the app to confirm."
        content.sound = .default
        deliver(content: content, id: ID.progression(skillName))
    }
    
    public func notifyLowRecovery(score: Double) {
        let content = UNMutableNotificationContent()
        content.title = "🔴 Low Readiness: \(Int(score))/100"
        content.body  = "Consider a lighter session or extra rest today."
        content.sound = .default
        deliver(content: content, id: "recovery.low")
    }
    
    // MARK: - Cancel all
    
    public func cancelAllReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [
            ID.morningReminder, ID.eveningReminder, ID.weighInReminder, ID.waistReminder, ID.photoReminder
        ] + morningScheduleIDs)
    }
    
    // MARK: - Helpers
    
    private func schedule(content: UNNotificationContent, id: String, hour: Int, minute: Int, weekday: Int? = nil, repeats: Bool) {
        var components    = DateComponents()
        components.hour   = hour
        components.minute = minute
        if let wd = weekday { components.weekday = wd }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(request)
    }
    
    private func deliver(content: UNNotificationContent, id: String) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request)
    }
    
    private func formatWeight(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg))kg" : "\(kg)kg"
    }
}
