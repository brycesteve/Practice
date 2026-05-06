// iOSWatchConnectivityDelegate.swift — iOS only
// Implements WatchConnectivityDelegate so the iOS app can:
//   • Persist workouts (with full child tree) received from the watch
//   • Persist skill session entries (with SkillSetRecord children)
//   • Persist kettlebell weight records and check for PBs
//   • Persist rest days marked on the watch
//   • Respond to watch sync requests with a full WCSyncPayload

import Foundation
import SwiftData

@MainActor
public final class iOSWatchConnectivityDelegate: WatchConnectivityDelegate {
    
    private let modelContainer: ModelContainer
    
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        
        // Respond whenever the watch requests a full sync
        NotificationCenter.default.addObserver(
            forName: .watchRequestedSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.sendFullSyncToWatch() }
        }
        
        // Persist rest days marked/unmarked on the watch
        NotificationCenter.default.addObserver(
            forName: .restDayReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let isRestDay = notification.userInfo?["isRestDay"] as? Bool else { return }
            Task { await self?.handleRestDay(isRestDay: isRestDay) }
        }
    }
    
    // MARK: - WatchConnectivityDelegate
    
    /// Watch finished a workout — persist the full WorkoutRecord tree.
    public func didReceiveCompletedWorkout(_ workout: CompletedWorkout) async {
        let context = modelContainer.mainContext
        
        // Avoid duplicates
        let id = workout.id
        guard (try? context.fetch(
            FetchDescriptor<WorkoutRecord>(predicate: #Predicate { $0.id == id })
        ))?.isEmpty != false else { return }
        
        // WorkoutRecord.init builds the full ExerciseRecord/SetRecord tree
        let record = WorkoutRecord(from: workout)
        context.insert(record)
        
        // Explicitly insert children so this context tracks them
        for exRecord in record.exercises ?? [] {
            context.insert(exRecord)
            for setRecord in exRecord.sets ?? [] {
                context.insert(setRecord)
            }
        }
        
        do { try context.save() }
        catch { print("didReceiveCompletedWorkout save error: \(error)") }
    }
    
    /// Watch finished a skill progression set — persist entry and re-evaluate.
    public func didReceiveSkillEntry(_ entry: SkillSessionEntry) async {
        let context = modelContainer.mainContext
        
        // Avoid duplicates
        let id = entry.id
        guard (try? context.fetch(
            FetchDescriptor<SkillSessionRecord>(predicate: #Predicate { $0.id == id })
        ))?.isEmpty != false else { return }
        
        // Insert session record
        let sessionRecord = SkillSessionRecord(from: entry)
        context.insert(sessionRecord)
        
        // Explicitly insert SkillSetRecord children
        for setRecord in sessionRecord.sets ?? [] {
            context.insert(setRecord)
        }
        
        // Re-evaluate progression and persist updated level + dateAchieved
        if let progRecord = try? context.fetch(
            FetchDescriptor<SkillProgressionRecord>(
                predicate: #Predicate { $0.id == entry.skillProgressionID }
            )
        ).first {
            let allHistory = ((try? context.fetch(
                FetchDescriptor<SkillSessionRecord>(
                    predicate: #Predicate { $0.skillProgressionID == entry.skillProgressionID }
                )
            )) ?? []).map { $0.toSkillSessionEntry() }
            
            let engine         = ProgressionEngine()
            let progression    = progRecord.toSkillProgression()
            let recommendation = engine.evaluate(progression: progression, history: allHistory)
            let updated        = engine.apply(recommendation: recommendation, to: progression)
            
            let wasLevel = progRecord.currentLevel
            progRecord.currentLevel = updated.currentLevel
            progRecord.levels       = updated.levels   // preserves dateAchieved stamps
            
            if updated.currentLevel > wasLevel, let nextName = progRecord.nextSkillLevel?.name {
                NotificationManager.shared.notifySkillAdvancement(
                    skillName: progRecord.skillName,
                    newLevelName: nextName
                )
            }
        }
        
        do { try context.save() }
        catch { print("didReceiveSkillEntry save error: \(error)") }
        
        // Send refreshed sync back so watch has updated progression level
        await sendFullSyncToWatch()
    }
    
    /// Watch logged a kettlebell set — persist weight record and check for PB.
    public func didReceiveKettlebellEntry(_ transfer: KettlebellEntryTransfer) async {
        let context = modelContainer.mainContext
        
        let record = transfer.toRecord()
        context.insert(record)
        
        let typeRaw      = transfer.exerciseType.rawValue
        let allRecords   = (try? context.fetch(
            FetchDescriptor<KettlebellWeightRecord>(
                predicate: #Predicate { $0.exerciseTypeRaw == typeRaw }
            )
        )) ?? []
        
        let previousBest = allRecords
            .filter { $0.id != record.id }
            .map(\.weightKg)
            .max() ?? 0
        
        if transfer.weightKg > previousBest {
            let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first
            let target   = transfer.exerciseType == .swing
            ? (settings?.targetSwingWeightKg ?? 32)
            : (settings?.targetTGUWeightKg   ?? 32)
            
            NotificationManager.shared.notifyKettlebellMilestone(
                exerciseType: transfer.exerciseType,
                weightKg:     transfer.weightKg,
                isFinalGoal:  transfer.weightKg >= target
            )
        }
        
        do { try context.save() }
        catch { print("didReceiveKettlebellEntry save error: \(error)") }
    }
    
    /// Watch marked a rest day — persist it to iOS so consistency score stays accurate.
    public func didReceiveSyncPayload(_ payload: WCSyncPayload) async {
        // iOS is the data authority for everything except rest days marked on watch.
        // The payload carries the watch's rotation day — we trust iOS settings as master,
        // so we only use this payload to update the watch's view of things, not the other
        // way around. A dedicated rest-day sync message would be cleaner; for now the
        // watch SessionPickerView also sends a requestSync on appear which triggers
        // sendFullSyncToWatch(), keeping both sides current.
    }
    
    // MARK: - Rest day handling
    
    private func handleRestDay(isRestDay: Bool) async {
        let context = modelContainer.mainContext
        let today   = Calendar.current.startOfDay(for: Date())
        
        do {
            let existing = try context.fetch(
                FetchDescriptor<RestDayRecord>(predicate: #Predicate { $0.date >= today })
            )
            if isRestDay {
                if existing.isEmpty {
                    context.insert(RestDayRecord(date: today))
                    try context.save()
                }
            } else {
                existing.forEach { context.delete($0) }
                try context.save()
            }
        } catch {
            print("handleRestDay error: \(error)")
        }
    }
    
    // MARK: - Build and send full sync payload to watch
    
    func sendFullSyncToWatch() async {
        let context = modelContainer.mainContext
        
        do {
            let progressionRecords = try context.fetch(FetchDescriptor<SkillProgressionRecord>())
            let progressions       = progressionRecords.map { $0.toSkillProgression() }
            
            let settings     = try context.fetch(FetchDescriptor<AppSettings>()).first ?? AppSettings()
            let workoutCount = try context.fetchCount(FetchDescriptor<WorkoutRecord>())
            
            let today       = Calendar.current.startOfDay(for: Date())
            let scoreRecord = try context.fetch(
                FetchDescriptor<RecoveryScoreRecord>(
                    predicate: #Predicate { $0.date >= today },
                    sortBy: [SortDescriptor(\RecoveryScoreRecord.date, order: .reverse)]
                )
            ).first
            
            let payload = WCSyncPayload(
                skillProgressions:    progressions,
                eveningRotationDay:   settings.eveningRotationDay,
                targetSwingWeightKg:  settings.targetSwingWeightKg,
                targetTGUWeightKg:    settings.targetTGUWeightKg,
                recentWorkoutCount:   workoutCount,
                todayRecoveryScore:   scoreRecord?.overallScore
            )
            
            WatchConnectivityManager.shared.sendFullSync(payload: payload)
        } catch {
            print("sendFullSyncToWatch error: \(error)")
        }
    }
}
