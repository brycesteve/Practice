// WatchConnectivityManager.swift — TrainingShared
// Manages bidirectional communication between iOS and watchOS.
// Architecture:
//   • Watch → Phone: completed workouts, skill session entries (after each session)
//   • Phone → Watch: settings, skill progression levels, rotation day
// The phone is the SwiftData write authority. The watch sends raw data packages;
// the phone inserts them into SwiftData and becomes source of truth.

import Foundation
import WatchConnectivity
import SwiftData
import WidgetKit

// MARK: - Message keys

public enum WCMessageKey {
    // Watch → Phone
    public static let completedWorkout  = "completedWorkout"   // Data (JSON-encoded CompletedWorkout)
    public static let skillEntry        = "skillEntry"          // Data
    public static let kettlebellEntry   = "kettlebellEntry"     // Data
    public static let requestSync       = "requestSync"         // Bool — watch asking for full state
    
    // Watch → Phone
    public static let restDay           = "restDay"             // Bool (true = mark, false = unmark)
    // Phone → Watch
    public static let fullSync          = "fullSync"            // Data (JSON-encoded WCSyncPayload)
    public static let settingsUpdate    = "settingsUpdate"      // Data
}

/// Everything the watch needs to know about the current training state
public struct WCSyncPayload: Codable, Sendable {
    public var skillProgressions: [SkillProgression]
    public var eveningRotationDay: Int
    public var targetSwingWeightKg: Double
    public var targetTGUWeightKg: Double
    public var recentWorkoutCount: Int
    public var todayRecoveryScore: Double?
    
    public init(
        skillProgressions: [SkillProgression],
        eveningRotationDay: Int,
        targetSwingWeightKg: Double,
        targetTGUWeightKg: Double,
        recentWorkoutCount: Int,
        todayRecoveryScore: Double? = nil
    ) {
        self.skillProgressions = skillProgressions
        self.eveningRotationDay = eveningRotationDay
        self.targetSwingWeightKg = targetSwingWeightKg
        self.targetTGUWeightKg = targetTGUWeightKg
        self.recentWorkoutCount = recentWorkoutCount
        self.todayRecoveryScore = todayRecoveryScore
    }
}

// MARK: - Sendable transfer type for kettlebell entries
// KettlebellWeightRecord is a SwiftData @Model and therefore not Sendable.
// We pass this value type across actor boundaries instead, and construct
// the @Model object only once safely on the main actor in the delegate.

public struct KettlebellEntryTransfer: Sendable {
    public let id: UUID
    public let date: Date
    public let exerciseType: KettlebellExerciseType
    public let weightKg: Double
    public let sets: Int
    public let reps: Int
    
    public init(id: UUID = UUID(), date: Date = .now,
                exerciseType: KettlebellExerciseType,
                weightKg: Double, sets: Int, reps: Int) {
        self.id          = id
        self.date        = date
        self.exerciseType = exerciseType
        self.weightKg    = weightKg
        self.sets        = sets
        self.reps        = reps
    }
    
    /// Construct the SwiftData model — call only on the main actor.
    @MainActor
    func toRecord() -> KettlebellWeightRecord {
        KettlebellWeightRecord(
            id: id, date: date,
            exerciseType: exerciseType,
            weightKg: weightKg, sets: sets, reps: reps
        )
    }
}

// MARK: - Delegate protocol (implemented separately on iOS and watchOS)

public protocol WatchConnectivityDelegate: AnyObject, Sendable {
    /// Phone received a completed workout from the watch
    func didReceiveCompletedWorkout(_ workout: CompletedWorkout) async
    /// Phone received a skill session entry from the watch
    func didReceiveSkillEntry(_ entry: SkillSessionEntry) async
    /// Phone received a kettlebell entry from the watch
    func didReceiveKettlebellEntry(_ entry: KettlebellEntryTransfer) async
    /// Watch received a full sync payload from the phone
    func didReceiveSyncPayload(_ payload: WCSyncPayload) async
}

// MARK: - Manager

@Observable
public final class WatchConnectivityManager: NSObject, @unchecked Sendable {
    
    public static let shared = WatchConnectivityManager()
    
    public var isReachable: Bool = false
    public var lastSyncDate: Date?
    
    public weak var delegate: (any WatchConnectivityDelegate)?
    
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    
    // MARK: - Activation
    
    public func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }
    
    // MARK: - Watch → Phone: send completed workout
    
    public func sendWorkout(_ workout: CompletedWorkout) {
        guard let data = try? JSONEncoder().encode(workout) else { return }
        send(message: [WCMessageKey.completedWorkout: data])
    }
    
    public func sendSkillEntry(_ entry: SkillSessionEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        send(message: [WCMessageKey.skillEntry: data])
    }
    
    public func sendKettlebellEntry(exerciseType: KettlebellExerciseType, weightKg: Double, sets: Int, reps: Int) {
        // Build dict directly from parameters — avoids constructing a non-Sendable @Model
        let dict: [String: Any] = [
            "id":            UUID().uuidString,
            "date":          Date().timeIntervalSince1970,
            "exerciseTypeRaw": exerciseType.rawValue,
            "weightKg":      weightKg,
            "sets":          sets,
            "reps":          reps,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        send(message: [WCMessageKey.kettlebellEntry: data])
    }
    
    public func sendRestDay(isRestDay: Bool) {
        send(message: [WCMessageKey.restDay: isRestDay])
    }
    
    public func requestFullSync() {
        send(message: [WCMessageKey.requestSync: true])
    }
    
    // MARK: - Phone → Watch: send full sync
    
    public func sendFullSync(payload: WCSyncPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        // Use updateApplicationContext for background delivery (survives disconnection)
        transferApplicationContext([WCMessageKey.fullSync: data])
        // Also try real-time if reachable
        send(message: [WCMessageKey.fullSync: data])
    }
    
    // MARK: - Internal send helpers
    
    private func send(message: [String: Any]) {
        guard let session, session.activationState == .activated else { return }
        
#if os(iOS)
        guard session.isPaired && session.isWatchAppInstalled else { return }
#endif
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                // If real-time fails, fall back to transferUserInfo (queued delivery)
                self.session?.transferUserInfo(message.compactMapValues { $0 })
            })
        } else {
            // Queue for delivery when reachable
            session.transferUserInfo(message)
        }
    }
    
    private func transferApplicationContext(_ context: [String: Any]) {
        try? session?.updateApplicationContext(context)
    }
    
    // MARK: - Receive
    
    private func handle(message: [String: Any]) {
        Task {
            if let data = message[WCMessageKey.completedWorkout] as? Data,
               let workout = try? JSONDecoder().decode(CompletedWorkout.self, from: data) {
                await delegate?.didReceiveCompletedWorkout(workout)
            }
            
            if let data = message[WCMessageKey.skillEntry] as? Data,
               let entry = try? JSONDecoder().decode(SkillSessionEntry.self, from: data) {
                await delegate?.didReceiveSkillEntry(entry)
            }
            
            if let data = message[WCMessageKey.kettlebellEntry] as? Data,
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let typeRaw = dict["exerciseTypeRaw"] as? String,
               let exType = KettlebellExerciseType(rawValue: typeRaw),
               let weightKg = dict["weightKg"] as? Double,
               let sets = dict["sets"] as? Int,
               let reps = dict["reps"] as? Int {
                // Pass Sendable transfer type — delegate constructs the @Model on main actor
                let transfer = KettlebellEntryTransfer(
                    exerciseType: exType, weightKg: weightKg, sets: sets, reps: reps
                )
                await delegate?.didReceiveKettlebellEntry(transfer)
            }
            
            if let data = message[WCMessageKey.fullSync] as? Data,
               let payload = try? JSONDecoder().decode(WCSyncPayload.self, from: data) {
                await delegate?.didReceiveSyncPayload(payload)
                
                // Post notification so WatchRecoveryView updates reactively
                // without needing to be the delegate itself
                if let score = payload.todayRecoveryScore {
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .recoveryScoreReceived,
                            object: nil,
                            userInfo: ["score": score]
                        )
                        
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    
                }
            }
            
            if message[WCMessageKey.requestSync] != nil {
                NotificationCenter.default.post(name: .watchRequestedSync, object: nil)
            }
            
            if let isRestDay = message[WCMessageKey.restDay] as? Bool {
                NotificationCenter.default.post(
                    name: .restDayReceived,
                    object: nil,
                    userInfo: ["isRestDay": isRestDay]
                )
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }
    
    public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message: message)
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handle(message: message)
        replyHandler([:])
    }
    
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(message: userInfo)
    }
    
    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(message: applicationContext)
    }
    
    // iOS-only required delegate methods
#if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()   // re-activate after Apple Watch switch
    }
#endif
}

// MARK: - Notification names

public extension Notification.Name {
    static let watchRequestedSync    = Notification.Name("watchRequestedSync")
    static let syncPayloadReceived   = Notification.Name("syncPayloadReceived")
    static let recoveryScoreReceived = Notification.Name("recoveryScoreReceived")
    static let restDayReceived       = Notification.Name("restDayReceived")
}
