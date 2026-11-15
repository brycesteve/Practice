import Foundation
import Testing
@testable import PracticeWatch_Watch_App

@Suite("Swing set heart-rate capture")
struct SwingSetHeartRateLogicTests {
    private let origin = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test("Chooses the most recent valid pre-set sample")
    func mostRecentPreSetSample() {
        let samples = [
            sample(-10, 110),
            sample(-2, 120),
            sample(1, 130),
            sample(-1, 0)
        ]

        let result = SwingSetHeartRateLogic.mostRecentSample(
            atOrBefore: origin,
            samples: samples
        )

        #expect(result?.beatsPerMinute == 120)
    }

    @Test("Rejects stale pre-set samples")
    func rejectsStalePreSetSample() {
        let result = SwingSetHeartRateLogic.mostRecentSample(
            atOrBefore: origin,
            samples: [sample(-16, 110)]
        )

        #expect(result == nil)
    }

    @Test("Includes post-set samples in the peak window")
    func includesPostSetPeak() {
        let end = origin.addingTimeInterval(10)
        let result = SwingSetHeartRateLogic.peakHeartRate(
            setStartedAt: origin,
            setEndedAt: end,
            nextSetStartedAt: nil,
            samples: [
                sample(5, 145),
                sample(20, 170),
                sample(25, 190)
            ]
        )

        #expect(result == 170)
    }

    @Test("Stops the peak window when the next set begins")
    func peakDoesNotLeakIntoNextSet() {
        let end = origin.addingTimeInterval(10)
        let nextStart = origin.addingTimeInterval(18)
        let result = SwingSetHeartRateLogic.peakHeartRate(
            setStartedAt: origin,
            setEndedAt: end,
            nextSetStartedAt: nextStart,
            samples: [
                sample(17, 160),
                sample(18, 175),
                sample(19, 185)
            ]
        )

        #expect(result == 160)
    }

    @Test("Ignores samples before the set and invalid readings")
    func ignoresInvalidPeakSamples() {
        let end = origin.addingTimeInterval(10)
        let result = SwingSetHeartRateLogic.peakHeartRate(
            setStartedAt: origin,
            setEndedAt: end,
            nextSetStartedAt: nil,
            samples: [
                sample(-1, 190),
                sample(5, 0)
            ]
        )

        #expect(result == nil)
    }

    @Test("Finalization derives pre-set, peak, and recovery values")
    func finalizesSet() {
        let start = origin
        let end = origin.addingTimeInterval(10)
        let nextStart = origin.addingTimeInterval(30)
        let set = CompletedSet(startedAt: start, endedAt: end)

        let result = SwingSetHeartRateLogic.finalized(
            set,
            nextSetStartedAt: nextStart,
            samples: [
                sample(-3, 105),
                sample(5, 150),
                sample(20, 165),
                sample(29, 125)
            ]
        )

        #expect(result.preSetHeartRate == 105)
        #expect(result.peakHeartRate == 165)
        #expect(result.recoveryHeartRate == 125)
        #expect(result.recoveryStartedAt == nextStart)
        #expect(result.heartRateRecoveryDelta == 40)
    }

    @Test("Finalization preserves a captured pre-set reading")
    func preservesExistingPreSetReading() {
        let set = CompletedSet(
            startedAt: origin,
            endedAt: origin.addingTimeInterval(10),
            preSetHeartRate: 115
        )

        let result = SwingSetHeartRateLogic.finalized(
            set,
            nextSetStartedAt: nil,
            samples: [sample(-1, 100), sample(5, 150)]
        )

        #expect(result.preSetHeartRate == 115)
        #expect(result.peakHeartRate == 150)
        #expect(result.recoveryHeartRate == nil)
        #expect(result.recoveryStartedAt == nil)
    }

    private func sample(_ offset: TimeInterval, _ bpm: Double) -> HeartRateSample {
        HeartRateSample(
            timestamp: origin.addingTimeInterval(offset),
            beatsPerMinute: bpm
        )
    }
}

@Suite("Trial programme on Watch", .serialized)
@MainActor
struct WatchTrialProgrammeTests {
    @Test func resumingEveningAcrossThursdayKeepsTheOriginalStretchPlan() throws {
        let store = WatchActiveWorkoutStore.shared
        store.markFinished()
        defer { store.markFinished() }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let wednesday = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 23)))
        let thursday = wednesday.addingTimeInterval(3600)
        let original = WorkoutData.eveningPlan(for: .handstand, progressions: [], on: wednesday, calendar: calendar)
        store.begin(plan: original)
        let stretchIndex = try #require(original.steps.firstIndex { $0.exercise.id == Exercises.hipOpeners.id })
        store.position = WorkoutPosition(stepIndex: stretchIndex, round: 1, phase: .exercise)
        let step = original.steps[stretchIndex]
        store.completedExercises[step.id] = .init(exerciseID: step.exercise.id,
            exerciseName: step.exercise.name, sets: [.init(durationSeconds: 30)])
        let newPlan = WorkoutData.eveningPlan(for: .handstand, progressions: [], on: thursday, calendar: calendar)
        #expect(!newPlan.steps.contains { $0.exercise.id == Exercises.hipOpeners.id })
        store.begin(plan: newPlan)
        #expect(store.activePlan?.id == original.id)
        #expect(store.position.stepIndex == stretchIndex)
        #expect(store.completedExercises[step.id]?.sets.first?.durationSeconds == 30)
        #expect(store.activePlan?.steps.last?.exercise.id == Exercises.barHang.id)
    }

    @Test func resumeKeepsTheChosenPlanAndRecordedSets() throws {
        let store = WatchActiveWorkoutStore.shared
        store.markFinished()
        defer { store.markFinished() }
        let plan = WorkoutData.plan(for: .strengthB)
        store.begin(plan: plan)
        let workingIndex = try #require(plan.steps.firstIndex { $0.strengthLoadKey == "cleanPress" })
        store.position = WorkoutPosition(stepIndex: workingIndex, round: 2, phase: .hrRest)
        let warmup = CompletedExercise(exerciseID: plan.steps[0].exercise.id,
            exerciseName: plan.steps[0].exercise.name, sets: [.init(reps: 20)])
        store.completedExercises[plan.steps[0].id] = warmup
        store.completedExercises[plan.steps[workingIndex].id] = CompletedExercise(
            exerciseID: plan.steps[workingIndex].exercise.id, exerciseName: plan.steps[workingIndex].exercise.name,
            sets: [CompletedSet(reps: 5, weightKg: 8)])
        store.begin(plan: plan)
        #expect(store.activePlan?.id == plan.id)
        #expect(store.position == WorkoutPosition(stepIndex: workingIndex, round: 2, phase: .hrRest))
        #expect(store.completedExercises[plan.steps[workingIndex].id]?.sets.first?.weightKg == 8)
        #expect(store.completedExercises[plan.steps[0].id]?.id == warmup.id)
        #expect(store.workoutStarted)
    }

    @Test func independentLoadsSurviveRelaunchAndPhoneSync() throws {
        let suite = "PracticeTrialLoadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = AppGroupDefaults(defaults: defaults)
        #expect(cache.strengthLoad(for: "cleanPress") == nil)
        cache.saveStrengthLoad(8, for: "cleanPress")
        cache.saveStrengthLoad(16, for: "gobletSquat")
        cache.saveAppContext(WCSyncPayload(currentSwingWeightKg: 24, currentTGUWeightKg: 24))
        let relaunched = AppGroupDefaults(defaults: defaults)
        #expect(relaunched.strengthLoad(for: "cleanPress") == 8)
        #expect(relaunched.strengthLoad(for: "gobletSquat") == 16)
        #expect(relaunched.loadAppContext().currentSwingWeightKg == 24)
        #expect(relaunched.loadAppContext().currentTGUWeightKg == 24)
        relaunched.saveStrengthLoad(.nan, for: "cleanPress")
        relaunched.saveStrengthLoad(-1, for: "cleanPress")
        #expect(relaunched.strengthLoad(for: "cleanPress") == 8)
    }

    @Test func onlySwingsAndGetUpsUseSimpleSinisterProgression() {
        for step in WorkoutData.strengthASteps + WorkoutData.strengthBSteps {
            #expect(step.exercise.simpleSinisterType == nil)
            #expect(step.isHRGated == (step.exercise.category != .warmup))
        }
        #expect(Exercises.kbSwing.simpleSinisterType == .swing)
        #expect(Exercises.tgu.simpleSinisterType == .tgu)
        #expect(WorkoutData.plan(for: .jointStretches).steps.count == 1)
    }
}

@Suite("Workout logging UX")
struct WorkoutLoggingUXTests {
    @Test func effortIsOnlyRequestedForProgressionSkills() {
        let ordinary = [.morning, .strengthA, .strengthB, .mobility, .jointStretches] as [SessionType]
        for type in ordinary {
            #expect(WorkoutData.plan(for: type).steps.allSatisfy { !$0.recordsDifficulty })
        }
        let evening = WorkoutData.plan(for: .evening)
        #expect(evening.steps.contains { $0.recordsDifficulty })
        #expect(evening.steps.allSatisfy { $0.recordsDifficulty == ($0.exercise.category == .skillProgression) })
    }

    @Test func strengthChoicesUseEightKgIncrementsWithoutChangingSinisterSettings() {
        #expect(WorkoutData.strengthWeights == [8, 16, 24, 32, 40, 48])
        #expect(WorkoutData.kbWeights.contains(28))
        let settings = WCSyncPayload(currentSwingWeightKg: 24, swingProgressionWeightKg: 28,
                                     swingProgressionSetCount: 2)
        let swing = WorkoutData.morningSteps.first { $0.exercise.simpleSinisterType == .swing }!
        #expect(WorkoutLogging.kettlebellLoad(for: swing, settings: settings, setNumber: 1)?.weight == 24)
        #expect(WorkoutLogging.kettlebellLoad(for: swing, settings: settings, setNumber: 3)?.weight == 28)
    }

    @Test func ordinaryStrengthLogsActualIndependentLoadAndNeedsAChoiceFirst() throws {
        let press = try #require(WorkoutData.strengthBSteps.first { $0.strengthLoadKey == "cleanPress" })
        let settings = WCSyncPayload(currentSwingWeightKg: 40, currentTGUWeightKg: 32)
        #expect(WorkoutLogging.quickSet(for: press, duration: nil, strengthWeight: nil,
            settings: settings, setNumber: 1, side: nil) == nil)
        #expect(WorkoutLogging.quickSet(for: press, duration: nil, strengthWeight: 12,
            settings: settings, setNumber: 1, side: nil) == nil)
        let set = try #require(WorkoutLogging.quickSet(for: press, duration: nil, strengthWeight: 8,
            settings: settings, setNumber: 1, side: nil))
        #expect(set.reps == 5)
        #expect(set.weightKg == 8)
        #expect(set.durationSeconds == nil)
    }

    @Test func skillAlwaysOpensTheEffortLoggerAndWarmupsDoNotAskForEffort() throws {
        let skill = try #require(WorkoutData.plan(for: .evening).steps.first { $0.recordsDifficulty })
        #expect(WorkoutLogging.quickSet(for: skill, duration: 30, strengthWeight: nil,
            settings: WCSyncPayload(), setNumber: 1, side: nil) == nil)
        let warmup = WorkoutData.strengthASteps[0]
        let set = try #require(WorkoutLogging.quickSet(for: warmup, duration: nil, strengthWeight: nil,
            settings: WCSyncPayload(), setNumber: 1, side: nil))
        #expect(set.reps == warmup.reps)
        #expect(set.weightKg == nil)
    }

    @Test func timedLoggingUsesMeasuredTimeAndDoesNotInventACompletedHold() throws {
        let step = try #require(WorkoutData.mobilitySteps.first { $0.exercise.setType == .timed })
        for duration in [nil, 0] as [Int?] {
            #expect(WorkoutLogging.quickSet(for: step, duration: duration, strengthWeight: nil,
                settings: WCSyncPayload(), setNumber: 1, side: nil) == nil)
        }
        let set = try #require(WorkoutLogging.quickSet(for: step, duration: 47, strengthWeight: nil,
            settings: WCSyncPayload(), setNumber: 1, side: nil))
        #expect(set.durationSeconds == 47)
        #expect(set.reps == nil)
    }

    @Test func quickLoggingKeepsSinisterProgressionSlotsAndGetUpSide() throws {
        let step = try #require(WorkoutData.morningSteps.first { $0.exercise.simpleSinisterType == .tgu })
        let settings = WCSyncPayload(currentTGUWeightKg: 16, tguProgressionWeightKg: 24,
                                     tguProgressionSetCount: 2)
        let set = try #require(WorkoutLogging.quickSet(for: step, duration: nil, strengthWeight: 48,
            settings: settings, setNumber: 3, side: .right))
        #expect(set.reps == 1)
        #expect(set.tguSide == .right)
        #expect(set.weightKg == 24)
    }

    @Test func ordinaryNavigationKeepsAllPrescriptionsAndCircuits() {
        for type in [SessionType.morning, .strengthA, .strengthB, .mobility] {
            let plan = WorkoutData.plan(for: type)
            var position = WorkoutPosition.start()
            var counts: [UUID: Int] = [:]
            for _ in 0..<300 {
                if position.phase == .done { break }
                counts[plan.steps[position.stepIndex].id, default: 0] += 1
                position = WorkoutNavigation.nextPosition(in: plan, from: position)
            }
            #expect(position.phase == .done)
            for step in plan.steps { #expect(counts[step.id] == step.sets) }
        }
    }

    @Test func skippingOneCircuitExerciseKeepsOtherExercisesAndLaterRounds() {
        let plan = WorkoutData.plan(for: .morning)
        let skipped = Set([plan.steps[1].id])
        var position = WorkoutPosition(stepIndex: 1, round: 1, phase: .exercise)
        var visited: [(Int, Int)] = []
        for _ in 0..<30 {
            position = WorkoutNavigation.nextPosition(in: plan, from: position, skipped: skipped)
            if position.stepIndex >= 3 { break }
            visited.append((position.stepIndex, position.round))
        }
        #expect(visited.map { $0.0 } == [2, 0, 2, 0, 2])
        #expect(visited.map { $0.1 } == [1, 2, 2, 3, 3])
        #expect(position.stepIndex == 3)
    }

    @Test func skippingLastCircuitMemberRestartsRemainingMembersAndSkippingAllLeavesCircuit() {
        let plan = WorkoutData.plan(for: .morning)
        let position = WorkoutPosition(stepIndex: 2, round: 1, phase: .exercise)
        #expect(WorkoutNavigation.nextPosition(in: plan, from: position, skipped: [plan.steps[2].id])
            == WorkoutPosition(stepIndex: 0, round: 2, phase: .exercise))
        let all = Set(plan.steps.prefix(3).map(\.id))
        #expect(WorkoutNavigation.nextPosition(in: plan, from: position, skipped: all)
            == WorkoutPosition(stepIndex: 3, round: 1, phase: .exercise))
    }

    @Test func skippingOnePressSideDoesNotSkipTheOtherSide() throws {
        let plan = WorkoutData.plan(for: .strengthB)
        let left = try #require(plan.steps.firstIndex { $0.exercise.name == Exercises.cleanPressLeft.name })
        let right = try #require(plan.steps.firstIndex { $0.exercise.name == Exercises.cleanPressRight.name })
        let skipped = Set([plan.steps[left].id])
        var position = WorkoutPosition(stepIndex: left, round: 1, phase: .exercise)
        for round in 1...3 {
            position = WorkoutNavigation.nextPosition(in: plan, from: position, skipped: skipped)
            #expect(position == WorkoutPosition(stepIndex: right, round: round, phase: .exercise))
        }
        position = WorkoutNavigation.nextPosition(in: plan, from: position, skipped: skipped)
        #expect(position.stepIndex == right + 1)
    }
}

@Suite("Resume skipped exercises")
@MainActor
struct SkippedExerciseResumeTests {
    @Test func resumeKeepsSkippedExercisesAndFinishClearsOnlySessionState() {
        let store = WatchActiveWorkoutStore.shared
        store.markFinished()
        defer { store.markFinished() }
        let plan = WorkoutData.plan(for: .morning)
        store.begin(plan: plan)
        store.skippedStepIDs = [plan.steps[1].id]
        store.position = WorkoutPosition(stepIndex: 2, round: 2, phase: .exercise)
        store.begin(plan: plan)
        #expect(store.skippedStepIDs == [plan.steps[1].id])
        #expect(store.position.round == 2)
        store.markFinished()
        #expect(store.skippedStepIDs.isEmpty)
    }
}

@Suite("Finished workout summary", .serialized)
@MainActor
struct WorkoutSummarySnapshotTests {
    private var sunday: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 18))!
    }

    private func logs(for plan: SessionPlan) -> [UUID: CompletedExercise] {
        Dictionary(uniqueKeysWithValues: plan.steps.map { step in
            let sets = (0..<step.sets).map { _ in
                CompletedSet(reps: step.exercise.setType == .timed ? nil : (step.reps ?? 5),
                    durationSeconds: step.exercise.setType == .timed ? (step.durationSeconds ?? 30) : nil)
            }
            return (step.id, CompletedExercise(exerciseID: step.exercise.id, exerciseName: step.exercise.name, sets: sets))
        })
    }

    @Test func rotationFromThirtyFourToThirtyFiveExercisesCannotChangeFinishedSummary() {
        let store = WatchActiveWorkoutStore.shared
        store.markFinished()
        defer { store.markFinished() }
        let completedPlan = WorkoutData.eveningPlan(for: .planche, progressions: [], on: sunday)
        let nextPlan = WorkoutData.eveningPlan(for: .rings, progressions: [], on: sunday)
        #expect(completedPlan.steps.count == 34)
        #expect(nextPlan.steps.count == 35)
        store.begin(plan: completedPlan)
        store.completedExercises = logs(for: completedPlan)
        let summary = WorkoutSummarySnapshot(plan: store.activePlan!, loggedExercises: store.completedExercises,
            activeCalories: 120, averageHeartRate: 105, elapsedSeconds: 1800)
        store.markFinished()
        store.begin(plan: nextPlan)
        #expect(store.activePlan?.steps.count == 35)
        #expect(summary.plan.id == completedPlan.id)
        #expect(summary.plan.steps.count == 34)
        #expect(summary.loggedExerciseCount == 34)
        #expect(summary.activeCalories == 120)
        #expect(summary.averageHeartRate == 105)
        #expect(summary.elapsedSeconds == 1800)
    }

    @Test func everyFinishedSkillKeepsItsOwnCompleteCountAndExerciseOrder() {
        for skill in Skill.activeSkills {
            let plan = WorkoutData.eveningPlan(for: skill, progressions: SkillProgressions.defaultSkillProgressions, on: sunday)
            let summary = WorkoutSummarySnapshot(plan: plan, loggedExercises: logs(for: plan),
                activeCalories: 0, averageHeartRate: 0, elapsedSeconds: 600)
            #expect(summary.loggedExerciseCount == plan.steps.count)
            #expect(summary.completedExercises.map(\.exerciseName) == plan.steps.map { $0.exercise.name })
            #expect(zip(summary.completedExercises, plan.steps).allSatisfy { $0.sets.count == $1.sets })
        }
    }

    @Test func unfinishedAndZeroActivityExercisesRemainUnlogged() {
        let plan = WorkoutData.eveningPlan(for: .planche, progressions: [], on: sunday)
        var logged = logs(for: plan)
        logged.removeValue(forKey: plan.steps.last!.id)
        logged[plan.steps[0].id]?.sets = [CompletedSet(reps: 0, durationSeconds: 0)]
        let summary = WorkoutSummarySnapshot(plan: plan, loggedExercises: logged,
            activeCalories: 100, averageHeartRate: 100, elapsedSeconds: 600)
        #expect(summary.loggedExerciseCount == plan.steps.count - 2)
        #expect(summary.plan.steps.count == plan.steps.count)
    }

    @Test func unrelatedPickerPlanCannotSupplyExercisesForTheSummary() {
        let original = WorkoutData.eveningPlan(for: .planche, progressions: [], on: sunday)
        let regenerated = WorkoutData.eveningPlan(for: .planche, progressions: [], on: sunday)
        let summary = WorkoutSummarySnapshot(plan: original, loggedExercises: logs(for: regenerated),
            activeCalories: 0, averageHeartRate: 0, elapsedSeconds: 0)
        #expect(summary.completedExercises.isEmpty)
        #expect(summary.loggedExerciseCount == 0)
    }
}
