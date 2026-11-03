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
    @Test func resumeKeepsTheChosenPlanAndRecordedSets() throws {
        let store = WatchActiveWorkoutStore.shared
        store.markFinished()
        defer { store.markFinished() }
        let plan = WorkoutData.plan(for: .strengthB)
        store.begin(plan: plan)
        store.position = WorkoutPosition(stepIndex: 1, round: 2, phase: .hrRest)
        store.completedExercises[plan.steps[0].id] = CompletedExercise(
            exerciseID: plan.steps[0].exercise.id, exerciseName: plan.steps[0].exercise.name,
            sets: [CompletedSet(reps: 5, weightKg: 8)])
        store.begin(plan: plan)
        #expect(store.activePlan?.id == plan.id)
        #expect(store.position == WorkoutPosition(stepIndex: 1, round: 2, phase: .hrRest))
        #expect(store.completedExercises[plan.steps[0].id]?.sets.first?.weightKg == 8)
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
            #expect(step.isHRGated)
        }
        #expect(Exercises.kbSwing.simpleSinisterType == .swing)
        #expect(Exercises.tgu.simpleSinisterType == .tgu)
        #expect(WorkoutData.plan(for: .jointStretches).steps.count == 1)
    }
}
