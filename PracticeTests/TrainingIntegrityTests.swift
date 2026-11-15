import Foundation
import Testing
@testable import Practice

@Suite("Training integrity")
struct TrainingIntegrityTests {
    private var programmeCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    private func programmeDate(_ day: Int) -> Date {
        programmeCalendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 18))!
    }

    @Test func eveningStretchSequenceMatchesTheVideoWithCorrectSidesAndTiming() {
        let steps = WorkoutData.eveningStretchSteps
        #expect(steps.map(\.exercise.name) == [
            "Hip Openers", "90/90 Glute Stretch — Left Leg", "90/90 Back Leg Lifts — Right Leg",
            "90/90 Seated Twist", "90/90 Good Mornings — Left Leg", "90/90 Glute Stretch — Right Leg",
            "90/90 Back Leg Lifts — Left Leg", "90/90 Seated Twist", "90/90 Good Mornings — Right Leg",
            "Cat/Cow", "Forearm Stretch", "Puppy Dog Stretch", "Shoulder Rolls", "Downward Dog Stretch",
            "Kneeling Quad Stretch — Left Leg Forward", "Lizard Stretch — Left Leg Forward",
            "Pigeon Stretch — Left Leg Forward", "Kneeling Quad Stretch — Right Leg Forward",
            "Lizard Stretch — Right Leg Forward", "Pigeon Stretch — Right Leg Forward", "Frog Stretch",
            "Seated Pancake Stretch", "Pancake Side Stretch — Left Foot", "Pancake Side Stretch — Right Foot",
            "Standing Pike Stretch", "Deep Squat Hold", "Seated Bicep Stretch",
            "Lying Twist — Left Leg Across", "Lying Twist — Right Leg Across", "Happy Baby Stretch"
        ])
        #expect(steps.allSatisfy {
            $0.sets == 1 && $0.durationSeconds == 30 && $0.restSeconds == 10 &&
            $0.reps == nil && $0.circuitGroupID == nil && !$0.isHRGated &&
            $0.exercise.category == .stretch && $0.exercise.setType == .timed && $0.strengthLoadKey == nil
        })
        #expect(steps[3].notes == "Left leg in front.")
        #expect(steps[7].notes == "Right leg in front.")
        #expect(steps[13].exercise.notes?.contains("calves") == true)
        #expect(Set(steps.map(\.id)).count == steps.count)
    }

    @Test func thursdayMobilityMatchesFirstVideoAndEndsWithAssistanceBridges() throws {
        let plan = WorkoutData.plan(for: .mobility)
        let steps = plan.steps
        #expect(steps.map(\.exercise.name) == [
            "Cat/Cow", "Kneeling T-Spine Rotation", "Hip Rocking — Feet Turned Out", "Down Dog Calf Pedal",
            "Spinal Waves", "Half Kneeling Adductor Rocks — Left Foot Out",
            "Half Frog Thread the Needle — Left Leg Straight", "Half Kneeling Adductor Rocks — Right Foot Out",
            "Half Frog Thread the Needle — Right Leg Straight", "Standing Pancake Walks",
            "Pancake Shoulder Stretch", "Toe Stand", "Camel Bridges", "Active Crab Bicep Stretch",
            "Prone Angels", "Prone Scorpions", "Bird Dog — Left Hand & Right Leg",
            "Kneeling Hip Flexor Rocks — Right Leg Forward", "Bird Dog — Right Hand & Left Leg",
            "Kneeling Hip Flexor Rocks — Left Leg Forward", "Kneeling Hip CARs — Left Leg",
            "Kneeling Hip CARs — Right Leg", "Deep Squat Hold", "Standing Pike Stretch — Hands Off Floor",
            "Lying Hip Circles — Right Leg", "Lying Leg Extensions — Right Leg", "Lying Twist — Right Leg Across",
            "Lying Hip Circles — Left Leg", "Lying Leg Extensions — Left Leg", "Lying Twist — Left Leg Across",
            "Bridge Hold"
        ])
        #expect(steps.allSatisfy {
            $0.durationSeconds == 45 && $0.restSeconds == 10 && $0.reps == nil &&
            $0.exercise.category == .stretch && $0.exercise.setType == .timed &&
            $0.circuitGroupID == nil && !$0.isHRGated && $0.strengthLoadKey == nil
        })
        #expect(steps.dropLast().allSatisfy { $0.sets == 1 })
        #expect(steps.last?.sets == 2)
        #expect(steps[3].exercise.notes?.contains("calves") == true)
        #expect(steps[0].exercise.id == Exercises.catCow.id)
        #expect(plan.estimatedDurationMinutes == 30)
        let restored = try JSONDecoder().decode(SessionPlan.self, from: JSONEncoder().encode(plan))
        #expect(restored.steps.map(\.durationSeconds) == steps.map(\.durationSeconds))
        #expect(restored.steps.map(\.exercise.name) == steps.map(\.exercise.name))
    }

    @Test func everySkillKeepsItsWorkAndFinalHangsButSkipsThursdayStretching() throws {
        let progressions = SkillProgressions.defaultSkillProgressions
        for (index, skill) in Skill.activeSkills.enumerated() {
            let full = WorkoutData.eveningPlan(for: skill, progressions: progressions,
                on: programmeDate(9), calendar: programmeCalendar)
            let baselineWork = full.steps.filter { $0.exercise.category != .stretch }
            #expect(baselineWork.filter { $0.exercise.category == .skillProgression }.count == 1)
            #expect(baselineWork.contains { $0.exercise.category == .warmup && $0.circuitGroupID != nil })
            #expect(full.steps.suffix(31).map(\.exercise.name) ==
                WorkoutData.eveningStretchSteps.map(\.exercise.name) + [Exercises.barHang.name])
            for day in 9...15 {
                let plan = WorkoutData.plan(for: .evening, rotationDay: index, progressions: progressions,
                    on: programmeDate(day), calendar: programmeCalendar)
                let work = plan.steps.filter { $0.exercise.category != .stretch }
                #expect(work.map(\.exercise.name) == baselineWork.map(\.exercise.name))
                #expect(work.map(\.sets) == baselineWork.map(\.sets))
                #expect(work.map(\.reps) == baselineWork.map(\.reps))
                #expect(work.map(\.durationSeconds) == baselineWork.map(\.durationSeconds))
                #expect(work.map(\.restSeconds) == baselineWork.map(\.restSeconds))
                let stretches = plan.steps.filter { $0.exercise.category == .stretch }
                #expect(stretches.count == (day == 12 ? 1 : 31))
                let hang = try #require(plan.steps.last)
                #expect(hang.exercise.id == Exercises.barHang.id)
                #expect(hang.sets == 2 && hang.durationSeconds == 60 && hang.restSeconds == 60)
                #expect(!plan.steps.contains { $0.exercise.name == "Bridge Hold" })
                let skillStep = try #require(work.first { $0.exercise.category == .skillProgression })
                let workout = CompletedWorkout(sessionType: .evening, startDate: programmeDate(day),
                    endDate: programmeDate(day).addingTimeInterval(300), exercises: [
                        .init(exerciseID: skillStep.exercise.id, exerciseName: skillStep.exercise.name,
                              sets: [.init(reps: 5, durationSeconds: 30)])
                    ])
                let completion = try #require(EveningRotation.completion(for: workout, progressions: progressions))
                #expect(completion.skillName == skill.rawValue)
                #expect(EveningRotation.nextIndex(after: completion, fallback: 0) == (index + 1) % Skill.activeSkills.count)
            }
            let thursday = WorkoutData.eveningPlan(for: skill, progressions: progressions,
                on: programmeDate(12), calendar: programmeCalendar)
            #expect(full.estimatedDurationMinutes > thursday.estimatedDurationMinutes)
        }
        #expect(WorkoutData.scheduledSession(on: programmeDate(12), calendar: programmeCalendar) == .mobility)
        #expect(WorkoutData.scheduledSession(on: programmeDate(15), calendar: programmeCalendar) == nil)
    }

    @Test func strengthWarmupsHaveExactOrderedPrescriptionsWithoutRestOrProgression() throws {
        let a = WorkoutData.plan(for: .strengthA)
        let b = WorkoutData.plan(for: .strengthB)
        let warmupA = Array(a.steps.prefix(5))
        let warmupB = Array(b.steps.prefix(6))
        #expect(warmupA.map(\.exercise.name) == ["Arm Circles", "Scapula Push-Up", "Bodyweight Squat", "Easy Ring Push-Up", "Easy Ring Row"])
        #expect(warmupA.map(\.sets) == [1, 1, 1, 1, 1])
        #expect(warmupA.compactMap(\.reps) == [20, 10, 10, 5, 5])
        #expect(warmupB.map(\.exercise.name) == ["Arm Circles", "Shoulder Rotations", "Halo", "Light Kettlebell Clean", "Light Kettlebell Press", "Scapula Pull-Up"])
        #expect(warmupB.map(\.sets) == [1, 1, 1, 2, 2, 1])
        #expect(warmupB.compactMap(\.reps) == [20, 20, 10, 3, 3, 5])
        #expect(warmupA[1].exercise.id == Exercises.scapPushUp.id)
        #expect(warmupB[2].exercise.id == Exercises.halo.id)
        #expect(warmupB[5].exercise.id == Exercises.scapPullUp.id)
        #expect(warmupA[0].exercise.notes == "10 forward, 10 backward.")
        #expect(warmupB[1].exercise.notes?.contains("10 each direction") == true)
        #expect(warmupB[2].notes?.contains("5 each direction") == true)
        for step in warmupA.suffix(2) {
            #expect(step.exercise.notes?.contains("easier angle than your working sets") == true)
        }
        for step in warmupB[3...4] {
            #expect(step.exercise.notes?.contains("first set left, second set right") == true)
            #expect(step.exercise.notes?.contains("comfortably light kettlebell") == true)
        }
        for step in warmupA + warmupB {
            #expect(step.exercise.category == .warmup)
            #expect(step.exercise.setType == .reps)
            #expect(step.durationSeconds == nil && step.restSeconds == 0 && !step.isHRGated)
            #expect(step.strengthLoadKey == nil && step.repUpperBound == nil)
            #expect(step.circuitGroupID == nil && step.exercise.simpleSinisterType == nil)
        }
        #expect(a.steps.count == 9 && b.steps.count == 11)
        #expect(a.steps.dropFirst(5).allSatisfy { $0.exercise.category != .warmup })
        #expect(b.steps.dropFirst(6).allSatisfy { $0.exercise.category != .warmup })
        #expect(a.estimatedDurationMinutes == 29 && b.estimatedDurationMinutes == 35)
        // Distinct warm-up names and IDs keep easy ring sets separate in history.
        #expect(Set(warmupA.map(\.exercise.name)).isDisjoint(with: a.steps.dropFirst(5).map(\.exercise.name)))
        #expect(Set(warmupA.map(\.exercise.id)).isDisjoint(with: a.steps.dropFirst(5).map(\.exercise.id)))
        for plan in [a, b] {
            let restored = try JSONDecoder().decode(SessionPlan.self, from: JSONEncoder().encode(plan))
            #expect(restored.steps.map(\.id) == plan.steps.map(\.id))
            #expect(restored.steps.map(\.exercise.category) == plan.steps.map(\.exercise.category))
            #expect(restored.steps.map(\.reps) == plan.steps.map(\.reps))
        }
    }

    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private var progressions: [SkillProgression] { SkillProgressions.defaultSkillProgressions }

    private func workout(_ skill: Skill = .rings, logged: Bool = true, offset: Double = 0) -> CompletedWorkout {
        let name = progressions.first { $0.skillName == skill.rawValue }?.levels.first?.name ?? skill.rawValue
        return .init(sessionType: .evening, startDate: date.addingTimeInterval(offset - 600),
            endDate: date.addingTimeInterval(offset), exercises: [
                .init(exerciseID: UUID(), exerciseName: name,
                    sets: logged ? [.init(reps: 3)] : [])
            ])
    }

    @Test func testHostIsIsolated() {
        #expect(PracticeExecution.isTesting)
        #expect(ProcessInfo.processInfo.environment["PracticeIsolatedTests"] == "1")
    }

    @Test func elapsedTimeCaloriesAndHeartRateAreNotCompletion() {
        var value = workout(logged: false)
        value.activeCalories = 100
        value.averageHeartRate = 90
        value.hkWorkoutUUID = UUID()
        #expect(!value.isMeaningfulTraining)
        value.exercises[0].sets = [.init(reps: 0, durationSeconds: 0)]
        #expect(!value.hasCompletedActivity)
        value.exercises[0].sets = [.init(durationSeconds: 15)]
        #expect(value.isMeaningfulTraining) // Real partial/timed sessions remain valid.
    }

    @Test func ringCompletionAdvancesToHandstandDespiteStaleCounter() throws {
        let last = try #require(EveningRotation.completion(for: workout(), progressions: progressions))
        let index = EveningRotation.nextIndex(after: last, fallback: 1)
        #expect(Skill.activeSkills[index] == .handstand)
    }

    @Test func emptyAndWarmupOnlyEveningsCannotAdvanceRotation() {
        #expect(EveningRotation.completion(for: workout(logged: false), progressions: progressions) == nil)
        var warmup = workout()
        warmup.exercises[0].exerciseName = "Wrist Stretches"
        #expect(EveningRotation.completion(for: warmup, progressions: progressions) == nil)
        let last = EveningRotation.latest(workouts: [workout(), workout(.planche, logged: false, offset: 900), warmup],
            progressions: progressions)
        #expect(last?.skillName == Skill.rings.rawValue)
    }

    @Test func manualCompletionAndOutOfOrderDeliveryUseActualLatestSkill() {
        let last = EveningRotation.latest(workouts: [workout(.frontLever, offset: 800), workout(.rings)],
            progressions: progressions)
        #expect(Skill.activeSkills[EveningRotation.nextIndex(after: last, fallback: 0)] == .compression)
        #expect(EveningRotation.normalized(-1) == Skill.activeSkills.count - 1)
    }

    @Test func legacySkillEntryIsDurableEvidenceButEmptyEntriesAreNot() throws {
        let values = progressions
        let rings = try #require(values.first { $0.skillName == Skill.rings.rawValue })
        let entry = SkillSessionEntry(date: date, skillProgressionID: rings.id, level: 1, sets: [.init(durationSeconds: 20)])
        let empty = SkillSessionEntry(date: date.addingTimeInterval(100), skillProgressionID: rings.id, level: 1, sets: [])
        let last = EveningRotation.latest(workouts: [], entries: [empty, entry], progressions: values)
        #expect(last?.id == entry.id)
        #expect(Skill.activeSkills[EveningRotation.nextIndex(after: last, fallback: 1)] == .handstand)
    }

    @Test func completionSyncRemainsBackwardsCompatible() throws {
        let legacy = try JSONDecoder().decode(WCSyncPayload.self, from: Data("{}".utf8))
        #expect(legacy.lastEveningCompletion == nil)
        var payload = WCSyncPayload()
        payload.lastEveningCompletion = EveningRotation.completion(for: workout(), progressions: progressions)
        let restored = try JSONDecoder().decode(WCSyncPayload.self, from: JSONEncoder().encode(payload))
        #expect(restored.lastEveningCompletion == payload.lastEveningCompletion)
    }

    @Test func artificialHundredIsNotAConsistentRecoveryCache() {
        var seed = RecoveryDataDTO()
        seed.overallScore = 100
        seed.hrvScore = 18
        seed.restingHRScore = 20
        seed.sleepDurationScore = 10
        seed.sleepQualityScore = 10
        seed.respiratoryRateScore = 20
        seed.trainingLoadScore = 30
        #expect(!RecoveryAggregation.isConsistent(seed))
        #expect(RecoveryAggregation.score([18, 20, 10, 10, 20, 30]) == 17)
        seed.overallScore = 17
        #expect(RecoveryAggregation.isConsistent(seed))
    }

    @Test func missingMetricsRemainNeutralAndLegitimateHundredRemainsPossible() {
        #expect(RecoveryAggregation.score([nil, nil, nil, nil, nil, nil]) == 50)
        var value = RecoveryDataDTO()
        value.overallScore = 100
        value.sleepDurationScore = 100
        #expect(RecoveryAggregation.isConsistent(value))
        value.hrvScore = .nan
        #expect(!RecoveryAggregation.isConsistent(value))
    }
}

@Suite("Flexible daily practice")
struct DailyPracticeTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/London")!
        return value
    }
    private func day(_ number: Int, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: number, hour: 18))!
    }
    private func workout(_ type: SessionType, _ date: Date, name: String? = nil) -> CompletedWorkout {
        let exercise = WorkoutData.plan(for: type).steps.first { $0.exercise.category != .warmup }!.exercise
        return CompletedWorkout(sessionType: type, startDate: date.addingTimeInterval(-600), endDate: date,
            exercises: [.init(exerciseID: exercise.id, exerciseName: name ?? exercise.name, sets: [.init(reps: 5)])])
    }
    private func history(_ workouts: [CompletedWorkout]) -> [TrainingCompletion] {
        DailyPractice.history(workouts: workouts, progressions: SkillProgressions.defaultSkillProgressions)
    }

    @Test func sparseSaturdaysAdvanceInsteadOfRepeatingStrengthB() {
        let first = workout(.strengthB, day(7))
        let firstHistory = history([first])
        #expect(DailyPractice.suggestedSession(history: firstHistory, on: day(14)) == .morning)
        let second = workout(.morning, day(14), name: Exercises.kbSwing.name)
        #expect(DailyPractice.suggestedSession(history: history([second, first]), on: day(21)) == .strengthA)
    }

    @Test func exactSixSessionSequenceSurvivesMissedWeeks() {
        var records: [CompletedWorkout] = []
        for (index, expected) in WorkoutData.mainSequence.enumerated() {
            let date = day(1 + index * 3)
            #expect(DailyPractice.suggestedSession(history: history(records), on: date) == expected)
            records.append(workout(expected, date, name: expected == .morning ? Exercises.kbSwing.name : nil))
        }
        #expect(DailyPractice.suggestedSession(history: history(records), on: day(30)) == .morning)
    }

    @Test func emptyHistoryAndSundayHaveTheSameStartingSession() {
        for date in [day(14), day(15), day(16)] {
            #expect(DailyPractice.suggestedSession(history: [], on: date, calendar: calendar) == .morning)
        }
    }

    @Test func manualChoiceSetsTheFollowingSuggestionAndDuplicatesDoNotAdvance() {
        let record = workout(.strengthA, day(7))
        let value = history([record, record])
        #expect(value.count == 1)
        #expect(DailyPractice.suggestedSession(history: value, on: day(8)) == .morning)
        let mobility = workout(.mobility, day(8))
        #expect(DailyPractice.nextIndex(history: history([record, mobility]), on: day(9)) == 4)
    }

    @Test func sixConsecutiveTrainingDaysRequireAFullCalendarDayOfRest() {
        let records = (1...6).map { workout(.strengthA, day($0)) }
        let value = history(records)
        #expect(DailyPractice.suggestedSession(history: value, on: day(6), calendar: calendar) != nil)
        #expect(DailyPractice.suggestedSession(history: value, on: day(7), calendar: calendar) == nil)
        #expect(DailyPractice.requiresRest(history: value, on: day(7), calendar: calendar))
        #expect(!DailyPractice.requiresRest(history: value, on: day(8), calendar: calendar))
        #expect(DailyPractice.nextIndex(history: value, on: day(7)) == DailyPractice.nextIndex(history: value, on: day(8)))
    }

    @Test func multipleSessionsOnOneDayDoNotMakeAStreakAndGapsBreakIt() {
        let sameDay = (0..<6).map { workout(.strengthA, day(6).addingTimeInterval(Double($0))) }
        #expect(!DailyPractice.requiresRest(history: history(sameDay), on: day(7), calendar: calendar))
        let gap = [1, 2, 3, 5, 6, 7].map { workout(.strengthA, day($0)) }
        #expect(!DailyPractice.requiresRest(history: history(gap), on: day(8), calendar: calendar))
    }

    @Test func mobilityAndStretchingDoNotCreateTrainingDaysOrAdvanceSkills() {
        let mobility = workout(.mobility, day(1))
        let stretches = workout(.jointStretches, day(2))
        let evening = workout(.evening, day(3), name: WorkoutData.eveningStretchSteps[0].exercise.name)
        let value = history([mobility, stretches, evening])
        #expect(value.count == 1)
        #expect(value.first?.countsAsTraining == false)
        #expect(EveningRotation.latest(workouts: [evening], progressions: SkillProgressions.defaultSkillProgressions) == nil)
    }

    @Test func eveningSkillsCountTowardsRestButLeaveMainSequenceWaiting() {
        let records = (1...6).map { workout(.evening, day($0), name: Skill.rings.rawValue) }
        let value = history(records)
        #expect(DailyPractice.nextIndex(history: value, on: day(7)) == 0)
        #expect(DailyPractice.requiresRest(history: value, on: day(7), calendar: calendar))
    }

    @Test func warmupsAndEmptyAttemptsLeavePracticeWaiting() {
        let warmup = workout(.strengthA, day(1), name: Exercises.armCircles.name)
        let morningWarmup = workout(.morning, day(2), name: Exercises.halo.name)
        var empty = workout(.strengthB, day(3))
        empty.exercises = []
        #expect(history([warmup, morningWarmup, empty]).isEmpty)
    }

    @Test func restGuardAllowsOnlyGentlePlansAndHonoursManualRest() {
        let value = history((1...6).map { workout(.strengthA, day($0)) })
        for type in [SessionType.morning, .strengthA, .strengthB, .mobility, .evening] {
            #expect(!DailyPractice.permitsStart(plan: WorkoutData.plan(for: type), history: value, restDays: [], on: day(7), calendar: calendar))
        }
        for plan in [WorkoutData.plan(for: .jointStretches), WorkoutData.restEveningPlan] {
            #expect(DailyPractice.permitsStart(plan: plan, history: value, restDays: [], on: day(7), calendar: calendar))
        }
        #expect(DailyPractice.suggestedSession(history: [], restDays: [day(7)], on: day(7), calendar: calendar) == nil)
        #expect(WorkoutData.restEveningPlan.steps.map(\.exercise.name) == WorkoutData.eveningStretchSteps.map(\.exercise.name))
    }

    @Test func calendarDaysHandleTheClockChangeAndFutureRecordsAreIgnored() {
        let dates = (20...25).map { day($0, month: 10) }
        let value = history(dates.map { workout(.strengthA, $0) })
        #expect(DailyPractice.requiresRest(history: value, on: day(26, month: 10), calendar: calendar))
        #expect(DailyPractice.suggestedSession(history: value, on: day(19, month: 10), calendar: calendar) == .morning)
    }

    @Test func legacyPayloadDefaultsAndNewProjectionRoundTrip() throws {
        let legacy = try JSONDecoder().decode(WCSyncPayload.self, from: Data("{}".utf8))
        #expect(legacy.trainingHistory.isEmpty)
        #expect(legacy.trainingHistoryUpdatedAt == nil)
        var payload = WCSyncPayload()
        payload.trainingHistory = history([workout(.strengthB, day(1))])
        payload.trainingHistoryUpdatedAt = day(2)
        let restored = try JSONDecoder().decode(WCSyncPayload.self, from: JSONEncoder().encode(payload))
        #expect(restored.trainingHistory == payload.trainingHistory)
        #expect(restored.trainingHistoryUpdatedAt == payload.trainingHistoryUpdatedAt)
    }
}
