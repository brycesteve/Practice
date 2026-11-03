// WatchConnectivityManager.swift — TrainingShared
// Manages bidirectional communication between iOS and watchOS.
// Architecture:
//   • Watch → Phone: completed workouts, skill session entries (after each session)
//   • Phone → Watch: settings, skill progression levels, rotation day
// The phone is the SwiftData write authority. The watch sends raw data packages;
// the phone inserts them into SwiftData and becomes source of truth.

import Foundation
import WatchConnectivity

import WidgetKit

// MARK: - Message keys

public enum WCMessageKey {
    // Watch → Phone
    public static let bodyMeasurement = "bodyMeasurement"
    public static let bodyAcknowledgement = "bodyAcknowledgement"
    public static let completedWorkout  = "completedWorkout"   // Data (JSON-encoded CompletedWorkout)
    public static let skillEntry        = "skillEntry"          // Data
    public static let kettlebellEntry   = "kettlebellEntry"     // Data
    public static let requestSync       = "requestSync"         // Bool — watch asking for full state
    
    // Watch → Phone
    public static let restDay           = "restDay"             // Bool (true = mark, false = unmark)
    // Phone → Watch
    public static let fullSync          = "fullSync"            // Data (JSON-encoded WCSyncPayload)
    public static let settingsUpdate    = "settingsUpdate"      // Data
    
    public static let updateRotationDay = "updateRotationDay" //Int
}

/// Everything the watch needs to know about the current training state
public struct WCSyncPayload: Codable, Sendable {
    public var skillProgressions: [SkillProgression]
    var lastEveningCompletion: EveningCompletion? = nil
    public var eveningRotationDay: Int
    public var targetSwingWeightKg: Double
    public var targetTGUWeightKg: Double
    public var currentSwingWeightKg: Double
    public var currentTGUWeightKg: Double
    public var swingProgressionWeightKg: Double
    public var tguProgressionWeightKg: Double
    public var swingProgressionSetCount: Int
    public var tguProgressionSetCount: Int
    public var lastSwingWeightKg: Double
    public var lastTGUWeightKg: Double
    public var recoveryData: RecoveryDataDTO?
    public var restDays: [Date]
    public var bodyConfiguration: BodyConfiguration?
    
    
    
    public init(
        skillProgressions: [SkillProgression] = [],
        eveningRotationDay: Int = 0,
        targetSwingWeightKg: Double = 24,
        targetTGUWeightKg: Double = 24,
        currentSwingWeightKg: Double = 24,
        currentTGUWeightKg: Double = 24,
        swingProgressionWeightKg: Double = 28,
        tguProgressionWeightKg: Double = 28,
        swingProgressionSetCount: Int = 0,
        tguProgressionSetCount: Int = 0,
        lastSwingWeightKg: Double = 24,
        lastTGUWeightKg: Double = 24,
        recoveryData: RecoveryDataDTO? = nil,
        restDays: [Date] = [],
        bodyConfiguration: BodyConfiguration? = nil
    ) {
        self.skillProgressions = skillProgressions
        self.eveningRotationDay = eveningRotationDay
        self.targetSwingWeightKg = targetSwingWeightKg
        self.targetTGUWeightKg = targetTGUWeightKg
        self.currentSwingWeightKg = currentSwingWeightKg
        self.currentTGUWeightKg = currentTGUWeightKg
        self.swingProgressionWeightKg = swingProgressionWeightKg
        self.tguProgressionWeightKg = tguProgressionWeightKg
        self.swingProgressionSetCount = swingProgressionSetCount
        self.tguProgressionSetCount = tguProgressionSetCount
        self.lastSwingWeightKg = lastSwingWeightKg
        self.lastTGUWeightKg = lastTGUWeightKg
        self.recoveryData = recoveryData
        self.restDays = restDays
        self.bodyConfiguration = bodyConfiguration
    }
    
    enum CodingKeys: String, CodingKey {
        case skillProgressions
        case eveningRotationDay
        case lastEveningCompletion
        case targetSwingWeightKg
        case targetTGUWeightKg
        case currentSwingWeightKg
        case currentTGUWeightKg
        case swingProgressionWeightKg
        case tguProgressionWeightKg
        case swingProgressionSetCount
        case tguProgressionSetCount
        case lastSwingWeightKg
        case lastTGUWeightKg
        case recoveryData
        case restDays
        case bodyConfiguration
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skillProgressions = try container.decodeIfPresent([SkillProgression].self, forKey: .skillProgressions) ?? []
        eveningRotationDay = try container.decodeIfPresent(Int.self, forKey: .eveningRotationDay) ?? 0
        lastEveningCompletion = try container.decodeIfPresent(EveningCompletion.self, forKey: .lastEveningCompletion)
        targetSwingWeightKg = try container.decodeIfPresent(Double.self, forKey: .targetSwingWeightKg) ?? 24
        targetTGUWeightKg = try container.decodeIfPresent(Double.self, forKey: .targetTGUWeightKg) ?? 24
        lastSwingWeightKg = try container.decodeIfPresent(Double.self, forKey: .lastSwingWeightKg) ?? 24
        lastTGUWeightKg = try container.decodeIfPresent(Double.self, forKey: .lastTGUWeightKg) ?? 24
        currentSwingWeightKg = try container.decodeIfPresent(Double.self, forKey: .currentSwingWeightKg) ?? lastSwingWeightKg
        currentTGUWeightKg = try container.decodeIfPresent(Double.self, forKey: .currentTGUWeightKg) ?? lastTGUWeightKg
        swingProgressionWeightKg = try container.decodeIfPresent(Double.self, forKey: .swingProgressionWeightKg) ?? currentSwingWeightKg
        tguProgressionWeightKg = try container.decodeIfPresent(Double.self, forKey: .tguProgressionWeightKg) ?? currentTGUWeightKg
        swingProgressionSetCount = try container.decodeIfPresent(Int.self, forKey: .swingProgressionSetCount) ?? 0
        tguProgressionSetCount = try container.decodeIfPresent(Int.self, forKey: .tguProgressionSetCount) ?? 0
        recoveryData = try container.decodeIfPresent(RecoveryDataDTO.self, forKey: .recoveryData)
        restDays = try container.decodeIfPresent([Date].self, forKey: .restDays) ?? []
        bodyConfiguration = try container.decodeIfPresent(BodyConfiguration.self, forKey: .bodyConfiguration)
    }
    
    public mutating func updateRestDays(_ days: [Date]) {
        self.restDays = days.sorted(by: { a, b in
            a < b
        }).suffix(5)
    }
    
    public mutating func addSkillProgression(_ progression: SkillProgression) {
        self.skillProgressions.append(progression)
    }
}



// MARK: - Delegate protocol (implemented separately on iOS and watchOS)

public protocol WatchConnectivityDelegate: AnyObject, Sendable {
    func didReceiveBodyMeasurement(_ measurement: RawBodyMeasurement) async -> Bool
    /// Phone received a completed workout from the watch
    func didReceiveCompletedWorkout(_ workout: CompletedWorkout) async
    /// Phone received a skill session entry from the watch
    func didReceiveSkillEntry(_ entry: SkillSessionEntry) async
    /// Phone received a kettlebell entry from the watch
    func didReceiveKettlebellEntry(_ entry: KettlebellEntryTransfer) async
    /// Watch received a full sync payload from the phone
    func didReceiveSyncPayload(_ payload: WCSyncPayload) async
    
}

public extension WatchConnectivityDelegate {
    func didReceiveBodyMeasurement(_ measurement: RawBodyMeasurement) async -> Bool { false }
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
    
    
    @MainActor
    func flushBodyMeasurements() {
#if os(watchOS)
        guard let session, session.activationState == .activated else { return }
        for measurement in BodyMeasurementOutbox.shared.pending {
            guard let data = try? JSONEncoder().encode(measurement) else { continue }
            let alreadyQueued = session.outstandingUserInfoTransfers.contains {
                guard let bytes = $0.userInfo[WCMessageKey.bodyMeasurement] as? Data,
                      let queued = try? JSONDecoder().decode(RawBodyMeasurement.self, from: bytes) else { return false }
                return queued.id == measurement.id
            }
            if !alreadyQueued { session.transferUserInfo([WCMessageKey.bodyMeasurement: data]) }
        }
#endif
    }

    // MARK: - Watch → Phone: send completed workout
    
    public func sendWorkout(_ workout: CompletedWorkout) {
        guard workout.isMeaningfulTraining, let data = try? JSONEncoder().encode(workout) else { return }
        send(message: [WCMessageKey.completedWorkout: data])
    }
    
    public func sendSkillEntry(_ entry: SkillSessionEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        send(message: [WCMessageKey.skillEntry: data])
    }
    
    public func sendRotationDay(_ newDay: Int) {
        send(message: [WCMessageKey.updateRotationDay: newDay])
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
        let message = [WCMessageKey.fullSync: data]
        // Use updateApplicationContext for background delivery (survives disconnection)
        transferApplicationContext(message)
        transferComplicationUserInfoIfNeeded(message)
        // Also try real-time if reachable
        send(message: message)
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
        guard let session, session.activationState == .activated else { return }
        try? session.updateApplicationContext(context)
    }
    
    private func transferComplicationUserInfoIfNeeded(_ userInfo: [String: Any]) {
#if os(iOS)
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled,
              session.remainingComplicationUserInfoTransfers > 0 else { return }
        session.transferCurrentComplicationUserInfo(userInfo)
#endif
    }
    
    // MARK: - Receive
    
    private func handle(message: [String: Any]) {
        Task {
            if let data = message[WCMessageKey.bodyMeasurement] as? Data,
               let measurement = try? JSONDecoder().decode(RawBodyMeasurement.self, from: data),
               await delegate?.didReceiveBodyMeasurement(measurement) == true {
                send(message: [WCMessageKey.bodyAcknowledgement: measurement.id.uuidString])
            }
#if os(watchOS)
            if let text = message[WCMessageKey.bodyAcknowledgement] as? String, let id = UUID(uuidString: text) {
                await MainActor.run {
                    do { try BodyMeasurementOutbox.shared.acknowledge(id) }
                    catch { print("Body acknowledgement could not be saved: \(error)") }
                }
            }
#endif
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
                let id = (dict["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
                let date = (dict["date"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date()
                // Pass Sendable transfer type — delegate constructs the @Model on main actor
                let transfer = KettlebellEntryTransfer(
                    id: id, date: date, exerciseType: exType, weightKg: weightKg, sets: sets, reps: reps
                )
                await delegate?.didReceiveKettlebellEntry(transfer)
            }
            
            if let data = message[WCMessageKey.fullSync] as? Data,
                let payload = try? JSONDecoder().decode(WCSyncPayload.self, from: data) {
                await delegate?.didReceiveSyncPayload(payload)
                
                AppGroupDefaults.shared.saveAppContext(payload)
                
                await MainActor.run {
                    self.lastSyncDate = Date()
                    self.flushBodyMeasurements()
                    
                    NotificationCenter.default.post(
                        name: .syncPayloadReceived,
                        object: nil
                    )
                }
                
                // Post notification so WatchRecoveryView updates reactively
                // without needing to be the delegate itself
                if let score = payload.recoveryData?.overallScore {
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
            
            if let rotationDay = message[WCMessageKey.updateRotationDay] as? Int {
                AppGroupDefaults.shared.updateRotationDay(rotationDay)
                NotificationCenter.default
                    .post(
                        name:.rotationDayReceived,
                        object: nil,
                        userInfo: ["rotationDay": rotationDay]
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
            self.flushBodyMeasurements()
        }
    }
    
    public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.flushBodyMeasurements()
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
    static let rotationDayReceived = Notification.Name("rotationDayReceived")
}
