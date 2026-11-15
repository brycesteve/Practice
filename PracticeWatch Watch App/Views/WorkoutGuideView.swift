// WorkoutGuideView.swift — watchOS
// Additions in this version:
//   • Category background tints per exercise type
//   • Haptic feedback at set start, set logged, rest complete, workout end
//   • TGU L/R side auto-alternation in SetLoggerView
//   • ErrorState environment for surface-level error display

import SwiftUI
import SwiftData
import HealthKit
import WatchKit
import AVFoundation
import OSLog

// MARK: - Haptics + Audio

private enum TrainingHaptic {
    static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
    static func setStart()    { play(.start) }
    static func setLogged()   { play(.success) }
    static func restDone()    { play(.notification) }
    static func workoutEnd()  { play(.stop) }
}

@MainActor
private final class AudioCue: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = AudioCue()
    private let synth = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?
    private var audioSessionConfigured = false
    
    override init() {
        self.voice = Self.preferredVoice()
        super.init()
        synth.delegate = self
    }
    
    func speak(_ text: String) {
        configureAudioSessionIfNeeded()
        
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
        utterance.volume = 1.0
        Logger.default.info("Speaking workout cue: \(text, privacy: .public)")
        synth.speak(utterance)
    }
    
    private func configureAudioSessionIfNeeded() {
        guard !audioSessionConfigured else { return }
        audioSessionConfigured = true
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            synth.usesApplicationAudioSession = false
            audioSessionConfigured = false
            Logger.default.error("Speech audio session failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Logger.default.info("Speech cue started: \(utterance.speechString, privacy: .public)")
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Logger.default.info("Speech cue finished: \(utterance.speechString, privacy: .public)")
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Logger.default.info("Speech cue cancelled: \(utterance.speechString, privacy: .public)")
    }
    
    private static func preferredVoice() -> AVSpeechSynthesisVoice? {
        let englishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-") }
        guard !englishVoices.isEmpty else {
            return AVSpeechSynthesisVoice(language: "en-GB")
        }
        
        return englishVoices.max { voiceScore($0) < voiceScore($1) }
    }
    
    private static func voiceScore(_ voice: AVSpeechSynthesisVoice) -> Int {
        var score = 0
        
        if voice.language == "en-GB" { score += 300 }
        if voice.gender == .female { score += 1_000 }
        if likelyFemaleVoiceNames.contains(voice.name) { score += 900 }
        if voice.identifier.localizedCaseInsensitiveContains("female") { score += 900 }
        if voice.quality == .premium { score += 40 }
        if voice.quality == .enhanced { score += 20 }
        
        return score
    }
    
    private static let likelyFemaleVoiceNames: Set<String> = [
        "Ava", "Fiona", "Karen", "Kate", "Martha", "Moira", "Samantha", "Serena", "Tessa", "Victoria"
    ]
}

// MARK: - Category tint

private extension ExerciseCategory {
    var tintColor: Color {
        switch self {
        case .kettlebell:       return Color.orange.opacity(0.12)
        case .calisthenics:     return Color.blue.opacity(0.10)
        case .stretch:          return Color.green.opacity(0.10)
        case .skillProgression: return Color.purple.opacity(0.12)
        case .warmup:           return Color.yellow.opacity(0.08)
        }
    }
}

// MARK: - Navigation state machine

struct WorkoutPosition: Equatable {
    var stepIndex: Int
    var round: Int
    var phase: Phase
    
    enum Phase: Equatable {
        case exercise
        case hrRest
        case timedRest
        case done
    }
    
    static func start() -> WorkoutPosition {
        WorkoutPosition(stepIndex: 0, round: 1, phase: .exercise)
    }
}

/// Pure navigation shared by normal completion and confirmed exercise skipping.
enum WorkoutNavigation {
    static func nextPosition(in plan: SessionPlan, from position: WorkoutPosition,
                             skipped: Set<UUID> = []) -> WorkoutPosition {
        guard plan.steps.indices.contains(position.stepIndex) else {
            return WorkoutPosition(stepIndex: plan.steps.count, round: 1, phase: .done)
        }
        let step = plan.steps[position.stepIndex]
        if let group = step.circuitGroupID {
            let remaining = plan.steps.indices.filter {
                plan.steps[$0].circuitGroupID == group && !skipped.contains(plan.steps[$0].id)
            }
            if let next = remaining.first(where: { $0 > position.stepIndex && plan.steps[$0].sets >= position.round }) {
                return WorkoutPosition(stepIndex: next, round: position.round, phase: .exercise)
            }
            if let first = remaining.first(where: { plan.steps[$0].sets > position.round }) {
                return WorkoutPosition(stepIndex: first, round: position.round + 1, phase: .exercise)
            }
        } else if !skipped.contains(step.id), position.round < step.sets {
            return WorkoutPosition(stepIndex: position.stepIndex, round: position.round + 1, phase: .exercise)
        }
        let groupEnd = step.circuitGroupID.flatMap { group in
            plan.steps.lastIndex { $0.circuitGroupID == group }
        } ?? position.stepIndex
        let next = plan.steps.indices.first { $0 > groupEnd && !skipped.contains(plan.steps[$0].id) }
        return WorkoutPosition(stepIndex: next ?? plan.steps.count, round: 1, phase: next == nil ? .done : .exercise)
    }
}

enum WorkoutLogging {
    static func kettlebellLoad(for step: WorkoutStep, settings: WCSyncPayload,
                              setNumber: Int) -> (weight: Double, isProgression: Bool)? {
        guard let type = step.exercise.simpleSinisterType else { return nil }
        let isTGU = type == .tgu
        let count = isTGU ? settings.tguProgressionSetCount : settings.swingProgressionSetCount
        let bounded = min(max(count, 0), step.sets) / 2 * 2
        let middle = step.sets >= 4 ? Array(3...step.sets) : []
        let first = step.sets > 0 ? Array(1...min(step.sets, 2)) : []
        let progression = (middle + first).prefix(bounded).contains(setNumber)
        let weight = progression
            ? (isTGU ? settings.tguProgressionWeightKg : settings.swingProgressionWeightKg)
            : (isTGU ? settings.currentTGUWeightKg : settings.currentSwingWeightKg)
        return (weight, progression)
    }

    static func quickSet(for step: WorkoutStep, duration: Int?, strengthWeight: Double?,
                         settings: WCSyncPayload, setNumber: Int, side: TGUSide?) -> CompletedSet? {
        guard !step.recordsDifficulty else { return nil }
        let isTimed = step.exercise.setType == .timed
        let reps = step.reps ?? step.exercise.defaultReps ?? 10
        guard isTimed ? (duration ?? 0) > 0 : reps > 0 else { return nil }
        if step.strengthLoadKey != nil {
            guard let strengthWeight, WorkoutData.strengthWeights.contains(strengthWeight) else { return nil }
        }
        let weight = kettlebellLoad(for: step, settings: settings, setNumber: setNumber)?.weight
            ?? (step.strengthLoadKey != nil ? strengthWeight : nil)
        return CompletedSet(reps: isTimed ? nil : reps, durationSeconds: isTimed ? duration : nil,
                            tguSide: side, weightKg: weight)
    }
}

@MainActor
@Observable
final class WatchActiveWorkoutStore {
    static let shared = WatchActiveWorkoutStore()
    
    var activePlan: SessionPlan?
    var position = WorkoutPosition.start()
    var completedExercises: [UUID: CompletedExercise] = [:]
    var skippedStepIDs: Set<UUID> = []
    var nextTGUSide: TGUSide = .left
    var currentSetStartedAt: Date?
    var currentPreSetHeartRate: Double?
    var recoveryStartedAt: Date?
    var workoutStarted = false
    
    private init() {}
    
    func begin(plan: SessionPlan) {
        if activePlan?.sessionType != plan.sessionType || !workoutStarted {
            activePlan = plan
            position = .start()
            completedExercises = [:]
            skippedStepIDs = []
            nextTGUSide = .left
            currentSetStartedAt = nil
            currentPreSetHeartRate = nil
            recoveryStartedAt = nil
        }
        workoutStarted = true
    }
    
    func markFinished() {
        activePlan = nil
        position = .start()
        completedExercises = [:]
        skippedStepIDs = []
        nextTGUSide = .left
        currentSetStartedAt = nil
        currentPreSetHeartRate = nil
        recoveryStartedAt = nil
        workoutStarted = false
    }
}

// MARK: - Main View

struct WorkoutGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ErrorState.self) var errorState
    
    let initialPlan: SessionPlan
    
    init(plan: SessionPlan) {
        self.initialPlan = plan
    }
    
    @State private var settings = AppGroupDefaults.shared.loadAppContext()
    @State private var activeWorkout = WatchActiveWorkoutStore.shared
    
    @State private var strengthLoad: Double?
    @State private var showSetLogger  = false
    @State private var showGuidance = false
    @State private var showLoggedSets = false
    @State private var showPauseMenu  = false
    @State private var showEndConfirm = false
    @State private var showSkipConfirm = false
    @State private var showSkipRestConfirm = false
    @State private var showResetTimerConfirm = false
    @State private var restartTimerAfterConfirm = false
    @State private var summary: WorkoutSummarySnapshot?
    @State private var isStarting     = false
    @State private var isFinishing = false
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var restSecondsRemaining = 0
    @State private var restTimer: Timer? = nil
    @State private var setLoggerSuggestedDuration: Int? = nil
    @State private var sessionManager = WorkoutSessionManager.shared
    // Exercise timer for timed sets
    @State private var exerciseTimerSeconds: Int = 0
    @State private var exerciseTimerRunning: Bool = false
    @State private var exerciseTimer: Timer? = nil
    @State private var prepCountdownSeconds: Int = 0
    @State private var prepTimer: Timer? = nil
    @State private var frozenExerciseTimerSeconds: Int? = nil
    
    private var plan: SessionPlan {
        activeWorkout.activePlan ?? initialPlan
    }
    
    private var position: WorkoutPosition {
        get { activeWorkout.position }
        nonmutating set { activeWorkout.position = newValue }
    }
    
    private var completedExercises: [UUID: CompletedExercise] {
        get { activeWorkout.completedExercises }
        nonmutating set { activeWorkout.completedExercises = newValue }
    }
    
    private var nextTGUSide: TGUSide {
        get { activeWorkout.nextTGUSide }
        nonmutating set { activeWorkout.nextTGUSide = newValue }
    }
    
    private var workoutStarted: Bool {
        activeWorkout.workoutStarted || sessionManager.isRunning
    }

    private var hasLoggedActivity: Bool {
        completedExercises.values.contains { $0.sets.contains(where: \.hasCompletedActivity) }
    }
    
    // MARK: Helpers
    
    private var currentStep: WorkoutStep? {
        guard position.stepIndex < plan.steps.count else { return nil }
        return plan.steps[position.stepIndex]
    }
    
    private var progressFraction: Double {
        Double(position.stepIndex) / Double(max(plan.steps.count, 1))
    }
    
    private func circuitSteps(for step: WorkoutStep) -> [WorkoutStep] {
        guard let gid = step.circuitGroupID else { return [step] }
        return plan.steps.filter { $0.circuitGroupID == gid }
    }
    
    private func lastKBWeight(for step: WorkoutStep) -> Double? {
        let isSwing = step.exercise.name.contains("Swing")
        let isTGUEx = step.exercise.name.contains("Get-Up")
        guard isSwing || isTGUEx else { return nil }
        if isSwing {
            return settings.lastSwingWeightKg
        }
        else {
            return settings.lastTGUWeightKg
        }
    }
    
    private var isJointStretches: Bool { plan.sessionType == .jointStretches }

    private var isTGU: Bool {
        currentStep?.exercise.name.contains("Get-Up") ?? false
    }
    
    // MARK: Body
    
    var body: some View {
        Group {
            if let summary {
                WorkoutSummaryView(summary: summary)
            } else {
                mainBody
            }
        }
    }
    
    @ViewBuilder
    private var mainBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Color.clear.frame(height: 0).id("top")
                    
                    if position.phase == .done {
                        finishingView
                    } else if sessionManager.isPaused {
                        Text("Workout paused").font(.headline)
                        Button("Resume workout") { sessionManager.resumeWorkout() }
                            .buttonStyle(.borderedProminent)
                        Button("End workout") { showEndConfirm = true }
                            .buttonStyle(.bordered)
                    } else {
                        switch position.phase {
                        case .exercise:
                            if let step = currentStep { exercisePhase(step: step) }
                        case .hrRest:
                            if let step = currentStep { hrRestPhase(step: step) }
                        case .timedRest:
                            if let step = currentStep { timedRestPhase(step: step) }
                        case .done:
                            finishingView
                        }
                    }
                }
                .padding()
            }
            .background(currentStep.map { $0.exercise.category.tintColor } ?? Color.clear)
            .animation(.easeInOut(duration: 0.3), value: currentStep?.exercise.category)
            .onAppear { scrollProxy = proxy }
        }
        .sheet(isPresented: $showSetLogger) {
            if let step = currentStep {
                SetLoggerView(
                    step: step,
                    round: position.round,
                    existingSets: completedExercises[step.id]?.sets ?? [],
                    tguSide: isTGU ? nextTGUSide : nil,
                    suggestedDurationSeconds: setLoggerSuggestedDuration
                ) { loggedSet in
                    handleSetLogged(set: loggedSet, for: step)
                }
            }
        }
        .confirmationDialog("Workout", isPresented: $showPauseMenu) {
            if sessionManager.isPaused {
                Button("Resume") { sessionManager.resumeWorkout() }
            } else {
                Button("Pause")  { sessionManager.pauseWorkout()  }
            }
            Button("End Workout", role: .destructive) { showEndConfirm = true }
            Button("Cancel", role: .cancel) {}
        }
        .alert(isJointStretches ? "Finish mobility?" : "End workout early?", isPresented: $showEndConfirm) {
            Button("Keep going", role: .cancel) {}
            Button(isJointStretches || hasLoggedActivity ? "End & Save" : "Discard workout", role: .destructive) {
                if isJointStretches, let step = currentStep {
                    handleSetLogged(set: CompletedSet(durationSeconds: max(1, sessionManager.elapsedSeconds)), for: step)
                } else { finishWorkout() }
            }
        } message: {
            Text(isJointStretches || hasLoggedActivity
                 ? "Your logged activity will be saved. Any unfinished exercises will remain unlogged."
                 : "No activity has been logged. This workout will be discarded.")
        }
        .alert("Skip this exercise?", isPresented: $showSkipConfirm) {
            Button("Keep going", role: .cancel) {}
            Button("Skip exercise", role: .destructive) { skipStep() }
        } message: {
            Text("Skip the remaining sets of \(currentStep?.exercise.name ?? "this exercise")? Sets already logged are kept. Other circuit exercises will stay in the workout.")
        }
        .alert("Skip this rest?", isPresented: $showSkipRestConfirm) {
            Button("Keep resting", role: .cancel) {}
            Button("Skip rest", role: .destructive) {
                guard position.phase == .timedRest, let step = currentStep else { return }
                stopRestTimer()
                advanceAfterRest(step: step)
            }
        } message: {
            Text("Move to the next set now? Only continue when recovered.")
        }
        .alert(restartTimerAfterConfirm ? "Start a new attempt?" : "Reset this timer?", isPresented: $showResetTimerConfirm) {
            Button("Keep timer", role: .cancel) { restartTimerAfterConfirm = false }
            Button(restartTimerAfterConfirm ? "Start new attempt" : "Reset timer", role: .destructive) {
                let restart = restartTimerAfterConfirm
                restartTimerAfterConfirm = false
                resetExerciseTimer()
                if restart, let step = currentStep {
                    startPrepCountdown(target: step.durationSeconds ?? step.exercise.defaultDuration ?? 30)
                }
            }
        } message: {
            Text("The elapsed time for this set will be cleared. Log the current attempt first if you want to keep it. Logged sets are kept.")
        }
        .onChange(of: currentStep?.id, initial: true) { _, _ in
            showGuidance = false
            showLoggedSets = false
            strengthLoad = currentStep?.strengthLoadKey.flatMap { AppGroupDefaults.shared.strengthLoad(for: $0) }
                .flatMap { WorkoutData.strengthWeights.contains($0) ? $0 : nil }
        }
        .onChange(of: sessionManager.isPaused) { _, paused in
            if paused && (exerciseTimerRunning || prepCountdownSeconds > 0) { freezeExerciseTimer() }
        }
        .navigationBarBackButtonHidden(workoutStarted)
        .toolbar {
            if workoutStarted {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPauseMenu = true } label: {
                        Image(systemName: sessionManager.isPaused ? "play.circle" : "pause.circle")
                    }
                }
            }
        }
    }
    
    // MARK: - Exercise phase
    
    @ViewBuilder
    private func exercisePhase(step: WorkoutStep) -> some View {
        let circuit    = circuitSteps(for: step)
        let isCircuit  = circuit.count > 1
        
        if !isJointStretches { progressBar }
        workoutElapsed
        
        if isCircuit {
            let posInCircuit = (circuit.firstIndex(where: { $0.id == step.id }) ?? 0) + 1
            Label("Round \(position.round)/\(step.sets) · Ex \(posInCircuit)/\(circuit.count)",
                  systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
            .font(.caption2).foregroundStyle(WatchAppearance.supportingText)
        } else if !isJointStretches {
            Text("Set \(position.round) of \(step.sets)")
                .font(.caption2).foregroundStyle(WatchAppearance.supportingText)
        }
        
        if !isJointStretches { categoryBadge(step.exercise.category) }
        
        // TGU shows next side
        if step.exercise.name.contains("Get-Up") {
            HStack(spacing: 6) {
                Text(step.exercise.name).font(.headline)
                Text("· \(nextTGUSide.label)")
                    .font(.headline)
                    .foregroundStyle(nextTGUSide == .left ? .cyan : .orange)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(step.exercise.name)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        
        Text(step.displayTarget)
            .font(.headline).foregroundStyle(.white)
        
        if let kettlebellSetDescription = kettlebellSetDescription(
            for: step,
            setNumber: position.round
        ) {
            Label(kettlebellSetDescription, systemImage: "scalemass")
                .font(.caption.bold())
                .foregroundStyle(.orange)
        }
        
        if step.strengthLoadKey != nil {
            Picker("Load", selection: $strengthLoad) {
                Text("Choose load").tag(Optional<Double>.none)
                ForEach(WorkoutData.strengthWeights, id: \.self) { weight in
                    Text(formatWeight(weight)).tag(Optional(weight))
                }
            }
            .font(.caption)
            .pickerStyle(.wheel)
            .frame(height: 80)
            .onChange(of: strengthLoad) { _, weight in
                if let key = step.strengthLoadKey, let weight {
                    AppGroupDefaults.shared.saveStrengthLoad(weight, for: key)
                }
            }
        }

        if step.exercise.setType == .timed && !isJointStretches {
            exerciseTimerView(step: step)
        }
        
        VStack(spacing: 8) {
            if !workoutStarted {
                Button {
                    startWorkout()
                } label: {
                    Label(isStarting ? "Starting…" : "Start Workout", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isStarting)
                .buttonStyle(.borderedProminent).tint(.green)
            }
            else {
                Button {
                    if isJointStretches {
                        showEndConfirm = true
                    } else if let set = WorkoutLogging.quickSet(for: step,
                        duration: timedLogDuration(for: step), strengthWeight: strengthLoad,
                        settings: settings, setNumber: position.round, side: isTGU ? nextTGUSide : nil) {
                        if step.exercise.setType == .timed { freezeExerciseTimer() }
                        handleSetLogged(set: set, for: step)
                    } else {
                        presentSetLogger(for: step)
                    }
                } label: {
                    Label(isJointStretches ? "Finish" : logButtonTitle(for: step), systemImage: "checkmark.circle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                if !isJointStretches {
                    if !step.recordsDifficulty {
                        Button("Adjust set") { presentSetLogger(for: step) }
                            .buttonStyle(.bordered)
                    }
                    Button { showSkipConfirm = true } label: {
                        Label("Skip exercise", systemImage: "forward.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }

        if step.exercise.category == .kettlebell, let last = lastKBWeight(for: step) {
            Label("Last: \(formatWeight(last))", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.caption2)
                .foregroundStyle(WatchAppearance.supportingText)
        }

        if (!isJointStretches && step.exercise.notes != nil) || step.notes != nil {
            Button { showGuidance.toggle() } label: {
                Label(showGuidance ? "Hide guidance" : "Guidance", systemImage: showGuidance ? "chevron.up" : "chevron.down")
            }.font(.caption).buttonStyle(.bordered)
            if showGuidance {
                VStack(alignment: .leading, spacing: 6) {
                    if let notes = step.exercise.notes, !isJointStretches {
                        Text(notes).fixedSize(horizontal: false, vertical: true)
                    }
                    if let notes = step.notes {
                        Text(notes).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.caption)
                .foregroundStyle(WatchAppearance.supportingText)
            }
        }

        // Logged sets this exercise
        let logged = completedExercises[step.id]?.sets ?? []
        if !logged.isEmpty {
            Button { showLoggedSets.toggle() } label: {
                Label("Logged sets (\(logged.count))", systemImage: showLoggedSets ? "chevron.up" : "chevron.down")
            }.font(.caption).buttonStyle(.bordered)
            if showLoggedSets {
                VStack {
                    ForEach(logged.indices, id: \.self) { i in
                        HStack {
                            if let side = logged[i].tguSide {
                                Text("Set \(i+1) \(side.label)").font(.caption2).foregroundStyle(WatchAppearance.supportingText)
                            } else {
                                Text("Set \(i+1)").font(.caption2).foregroundStyle(WatchAppearance.supportingText)
                            }
                            Spacer()
                            if let r = logged[i].reps            { Text("\(r) reps").font(.caption2) }
                            if let d = logged[i].durationSeconds { Text("\(d)s").font(.caption2)     }
                            if recordsDifficulty(for: step) {
                                Text(logged[i].feltDifficulty.emoji).font(.caption2)
                            }
                        }
                    }
                }
                .font(.caption)
            }
        }


        if workoutStarted { Divider(); liveMetrics }
    }
    
    // MARK: - HR rest phase
    
    @ViewBuilder
    private func hrRestPhase(step: WorkoutStep) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let completedSet = completedExercises[step.id]?.sets.last
            let peak: Double? = completedSet.flatMap {
                guard let startedAt = $0.startedAt, let endedAt = $0.endedAt else { return nil }
                return SwingSetHeartRateLogic.peakHeartRate(
                    setStartedAt: startedAt,
                    setEndedAt: endedAt,
                    nextSetStartedAt: nil,
                    samples: sessionManager.heartRateSamples
                )
            }
            let recoverySeconds = activeWorkout.recoveryStartedAt.map {
                max(0, Int(context.date.timeIntervalSince($0)))
            } ?? 0

            VStack(spacing: 8) {
                workoutElapsed
                Text("Recover").font(.headline)
                HStack(alignment: .firstTextBaseline) {
                    metricColumn("Current", value: formatHeartRate(sessionManager.heartRate))
                    metricColumn("Peak", value: peak.map { "\(Int($0))" } ?? "—")
                }
                HStack {
                    Label(formatWorkoutDuration(recoverySeconds), systemImage: "timer")
                    Spacer()
                    Text("Set \(position.round) / \(step.sets)")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(WatchAppearance.supportingText)

                if let pre = completedSet?.preSetHeartRate,
                   let peak {
                    Text("Pre \(Int(pre)) · excursion +\(Int(max(0, peak - pre))) bpm")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(WatchAppearance.supportingText)
                }
                
                nextExerciseView(after: step)

                Button {
                    declareReadyAndAdvance(step: step)
                } label: {
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 6)
        }
    }

    private func metricColumn(_ label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Label {
                Text(label).foregroundStyle(WatchAppearance.supportingText)
            } icon: {
                Image(systemName: "heart.fill").foregroundStyle(.red)
            }
            .font(.caption2)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatHeartRate(_ heartRate: Double) -> String {
        heartRate > 0 ? "\(Int(heartRate))" : "—"
    }
    
    // MARK: - Timed rest phase
    
    @ViewBuilder
    private func timedRestPhase(step: WorkoutStep) -> some View {
        VStack(spacing: 12) {
            workoutElapsed
            Text("Rest").font(.title3.bold())
            Text("\(restSecondsRemaining)s")
                .font(.title.monospacedDigit().bold())
                .foregroundStyle(restSecondsRemaining <= 5 ? .green : .primary)
            nextExerciseView(after: step)
            if workoutStarted { liveMetrics }
            Button {
                showSkipRestConfirm = true
            } label: {
                Label("Skip Rest", systemImage: "forward.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }
    
    private var finishingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Saving…").font(.caption).foregroundStyle(WatchAppearance.supportingText)
        }
        .onAppear { finishWorkout() }
    }
    
    // MARK: - Sub-views
    
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.25))
                Capsule().fill(Color.accentColor)
                    .frame(width: geo.size.width * progressFraction)
            }
            .frame(height: 4)
        }
        .frame(height: 4)
    }
    
    private var workoutElapsed: some View {
        Label {
            Text(formatWorkoutDuration(sessionManager.elapsedSeconds))
                .foregroundStyle(WatchAppearance.supportingText)
        } icon: {
            Image(systemName: "clock").foregroundStyle(.cyan)
        }
        .font(.caption.monospacedDigit())
    }
    
    private var liveMetrics: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label {
                    Text("\(Int(sessionManager.heartRate)) bpm").foregroundStyle(.white)
                } icon: {
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                }
                Spacer()
                Label {
                    Text("\(Int(sessionManager.activeCalories)) kcal").foregroundStyle(.white)
                } icon: {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                }
            }
        }
        .font(.caption2.monospacedDigit())
    }
    
    @ViewBuilder
    private func categoryBadge(_ category: ExerciseCategory) -> some View {
        let (label, color): (String, Color) = switch category {
        case .kettlebell:       ("Kettlebell",   .orange)
        case .calisthenics:     ("Calisthenics", .blue)
        case .stretch:          ("Stretch",      .green)
        case .skillProgression: ("Skill",        .purple)
        case .warmup:           ("Warm-up",      .yellow)
        }
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.25)).foregroundStyle(.white)
            .clipShape(Capsule())
    }
    
    private func logButtonTitle(for step: WorkoutStep) -> String {
        if step.recordsDifficulty { return "Log set & effort" }
        if step.exercise.setType == .timed {
            return timedLogDuration(for: step).map { "Log \($0)s" } ?? "Log duration"
        }
        return "Log \(step.reps ?? step.exercise.defaultReps ?? 10) reps"
    }
    
    private func timedLogDuration(for step: WorkoutStep) -> Int? {
        guard step.exercise.setType == .timed else { return nil }
        return frozenExerciseTimerSeconds ?? (exerciseTimerSeconds > 0 ? exerciseTimerSeconds : nil)
    }
    
    private func recordsDifficulty(for step: WorkoutStep) -> Bool {
        step.recordsDifficulty
    }
    
    @ViewBuilder
    private func nextExerciseView(after step: WorkoutStep) -> some View {
        let next = computeNextPosition(after: step, completing: position.round)
        
        if next.stepIndex < plan.steps.count {
            let nextStep = plan.steps[next.stepIndex]
            VStack(spacing: 2) {
                Text("Next: \(nextStep.exercise.name)")
                if let description = kettlebellSetDescription(
                    for: nextStep,
                    setNumber: next.round
                ) {
                    Text(description)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption2)
            .foregroundStyle(WatchAppearance.supportingText)
            .multilineTextAlignment(.center)
        } else {
            Text("Next: Done")
                .font(.caption2)
                .foregroundStyle(WatchAppearance.supportingText)
        }
    }
    
    private func kettlebellSetDescription(for step: WorkoutStep, setNumber: Int) -> String? {
        guard let load = WorkoutLogging.kettlebellLoad(for: step, settings: settings, setNumber: setNumber) else { return nil }
        return load.isProgression ? "\(formatWeight(load.weight)) · Progression" : formatWeight(load.weight)
    }

    // MARK: - Navigation
    
    private func presentSetLogger(for step: WorkoutStep) {
        setLoggerSuggestedDuration = timedLogDuration(for: step)
        if step.exercise.setType == .timed { freezeExerciseTimer() }
        showSetLogger = true
    }

    private func handleSetLogged(set: CompletedSet, for step: WorkoutStep) {
        guard workoutStarted, position.phase == .exercise, currentStep?.id == step.id else { return }
        TrainingHaptic.setLogged()
        if let type = step.exercise.simpleSinisterType, let weight = set.weightKg {
            WatchConnectivityManager.shared.sendKettlebellEntry(exerciseType: type, weightKg: weight,
                                                               sets: 1, reps: set.reps ?? 0)
        }
        if let key = step.strengthLoadKey, let weight = set.weightKg {
            strengthLoad = weight
            AppGroupDefaults.shared.saveStrengthLoad(weight, for: key)
        }
        var loggedSet = set
        let endDate = Date()
        let startDate = activeWorkout.currentSetStartedAt ?? endDate
        loggedSet.startedAt = startDate
        loggedSet.endedAt = endDate
        loggedSet.preSetHeartRate = activeWorkout.currentPreSetHeartRate ??
            SwingSetHeartRateLogic.mostRecentSample(
                atOrBefore: startDate,
                samples: sessionManager.heartRateSamples
            )?.beatsPerMinute
        
        if completedExercises[step.id] == nil {
            completedExercises[step.id] = CompletedExercise(
                exerciseID: step.exercise.id,
                exerciseName: step.exercise.name,
                sets: [],
                skillLevel: skillLevel(for: step)
            )
        }
        completedExercises[step.id]?.sets.append(loggedSet)
        activeWorkout.currentSetStartedAt = nil
        activeWorkout.currentPreSetHeartRate = nil
        activeWorkout.recoveryStartedAt = endDate
        
        // Advance TGU side after each TGU set
        if step.exercise.name.contains("Get-Up") {
            nextTGUSide = nextTGUSide.next
        }
        
        scrollToTop()
        
        let completedRound = position.round
        let nextPosition = computeNextPosition(after: step, completing: completedRound)
        let hasNextExercise = nextPosition.phase != .done
        
        if step.isHRGated {
            if hasNextExercise { position.phase = .hrRest }
            else               { advancePosition(completedRound: completedRound, step: step) }
        } else if isLastRoundOfCircuit(step: step, round: completedRound) {
            let rest = circuitEndRest(for: step)
            if rest > 0 && hasNextExercise { startRestTimer(seconds: rest, step: step) }
            else                           { advancePosition(completedRound: completedRound, step: step) }
        } else if step.restSeconds > 0 && hasNextExercise {
            startRestTimer(seconds: step.restSeconds, step: step)
        } else {
            advancePosition(completedRound: completedRound, step: step)
        }
    }
    
    private func isLastRoundOfCircuit(step: WorkoutStep, round: Int) -> Bool {
        guard let gid = step.circuitGroupID else { return false }
        return plan.steps.filter { $0.circuitGroupID == gid && !activeWorkout.skippedStepIDs.contains($0.id) }.last?.id == step.id
    }
    
    private func circuitEndRest(for step: WorkoutStep) -> Int {
        guard let gid = step.circuitGroupID else { return step.restSeconds }
        return plan.steps.filter { $0.circuitGroupID == gid }.last?.restSeconds ?? step.restSeconds
    }
    
    private func declareReadyAndAdvance(step: WorkoutStep) {
        guard position.phase == .hrRest else { return }
        let nextSetStart = Date()
        if var exercise = completedExercises[step.id], !exercise.sets.isEmpty {
            let index = exercise.sets.index(before: exercise.sets.endIndex)
            exercise.sets[index] = SwingSetHeartRateLogic.finalized(
                exercise.sets[index],
                nextSetStartedAt: nextSetStart,
                samples: sessionManager.heartRateSamples
            )
            completedExercises[step.id] = exercise
        }
        activeWorkout.currentSetStartedAt = nextSetStart
        activeWorkout.currentPreSetHeartRate = SwingSetHeartRateLogic.mostRecentSample(
            atOrBefore: nextSetStart,
            samples: sessionManager.heartRateSamples
        )?.beatsPerMinute
        activeWorkout.recoveryStartedAt = nil
        TrainingHaptic.setStart()
        advanceAfterRest(step: step)
    }

    private func advanceAfterRest(step: WorkoutStep) {
        advancePosition(completedRound: position.round, step: step)
    }
    
    private func advancePosition(completedRound: Int, step: WorkoutStep) {
        resetExerciseTimer()
        position = computeNextPosition(after: step, completing: completedRound)
        scrollToTop()
    }
    
    private func computeNextPosition(after step: WorkoutStep, completing round: Int) -> WorkoutPosition {
        WorkoutNavigation.nextPosition(in: plan, from: WorkoutPosition(stepIndex: position.stepIndex,
            round: round, phase: .exercise), skipped: activeWorkout.skippedStepIDs)
    }

    private func skipStep() {
        guard let step = currentStep else { return }
        activeWorkout.skippedStepIDs.insert(step.id)
        stopRestTimer()
        resetExerciseTimer()
        activeWorkout.currentSetStartedAt = nil
        activeWorkout.currentPreSetHeartRate = nil
        activeWorkout.recoveryStartedAt = nil
        position = WorkoutNavigation.nextPosition(in: plan, from: position, skipped: activeWorkout.skippedStepIDs)
        scrollToTop()
    }
    
    // MARK: - Rest timer
    
    private func startRestTimer(seconds: Int, step: WorkoutStep) {
        restSecondsRemaining = seconds
        position.phase = .timedRest
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                guard self.position.phase == .timedRest, !self.sessionManager.isPaused else { return }
                if self.restSecondsRemaining > 1 {
                    self.restSecondsRemaining -= 1
                } else {
                    self.stopRestTimer()
                    TrainingHaptic.restDone()
                    AudioCue.shared.speak("Ready")
                    self.advanceAfterRest(step: step)
                }
            }
        }
    }
    
    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
    }
    
    // MARK: - Scroll
    
    private func formatWeight(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg))kg" : "\(kg)kg"
    }
    
    private func formatWorkoutDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func scrollToTop() {
        Task { @MainActor in
            withAnimation { scrollProxy?.scrollTo("top", anchor: .top) }
        }
    }
    
    // MARK: - Exercise timer
    
    @ViewBuilder
    private func exerciseTimerView(step: WorkoutStep) -> some View {
        let target = step.durationSeconds ?? step.exercise.defaultDuration ?? 30
        let isPreparing = prepCountdownSeconds > 0
        let displaySeconds = frozenExerciseTimerSeconds ?? exerciseTimerSeconds
        
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: min(Double(displaySeconds) / Double(target), 1.0))
                    .stroke(
                        displaySeconds >= target ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: displaySeconds)
                VStack(spacing: 0) {
                    if isPreparing {
                        Text("\(prepCountdownSeconds)")
                            .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.orange)
                        Text("prep")
                            .font(.caption2)
                            .foregroundStyle(WatchAppearance.supportingText)
                    } else {
                        Text(formatTimerDisplay(displaySeconds))
                            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(displaySeconds >= target ? .green : .primary)
                        Text("/ \(target)s")
                            .font(.caption2)
                            .foregroundStyle(WatchAppearance.supportingText)
                    }
                }
            }
            .frame(width: 96, height: 96)
            
            HStack(spacing: 10) {
                Button {
                    if exerciseTimerRunning || isPreparing {
                        freezeExerciseTimer()
                    } else if displaySeconds > 0 {
                        restartTimerAfterConfirm = true
                        showResetTimerConfirm = true
                    } else {
                        startPrepCountdown(target: target)
                    }
                } label: {
                    Image(systemName: exerciseTimerRunning || isPreparing ? "stop.fill" : "play.fill")
                        .font(.caption.bold())
                        .frame(width: 36, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .tint(exerciseTimerRunning || isPreparing ? .orange : .accentColor)
                .accessibilityLabel(exerciseTimerRunning || isPreparing ? "Stop timer" : displaySeconds > 0 ? "Start new attempt" : "Start timer")
                
                Button {
                    restartTimerAfterConfirm = false
                    showResetTimerConfirm = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.bold())
                        .frame(width: 36, height: 28)
                }
                .buttonStyle(.bordered)
                .disabled(displaySeconds == 0 && !exerciseTimerRunning && !isPreparing)
                .accessibilityLabel("Reset timer")
            }
            
            if isPreparing {
                Text("Get into position")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            } else if let frozen = frozenExerciseTimerSeconds {
                Label("Stopped at \(frozen)s", systemImage: "pause.circle.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            } else if displaySeconds >= target {
                Label("Target reached", systemImage: "checkmark.circle.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func startPrepCountdown(target: Int) {
        resetExerciseTimer()
        prepCountdownSeconds = 3
        TrainingHaptic.setStart()
        prepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                guard self.prepCountdownSeconds > 0, !self.sessionManager.isPaused else { return }
                if self.prepCountdownSeconds > 1 {
                    self.prepCountdownSeconds -= 1
                    TrainingHaptic.setStart()
                } else {
                    self.stopPrepTimer()
                    self.startExerciseTimer(target: target)
                }
            }
        }
    }
    
    private func startExerciseTimer(target: Int) {
        frozenExerciseTimerSeconds = nil
        exerciseTimerRunning = true
        TrainingHaptic.setStart()
        exerciseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                guard self.exerciseTimerRunning, !self.sessionManager.isPaused else { return }
                self.exerciseTimerSeconds += 1
                if self.exerciseTimerSeconds == target {
                    TrainingHaptic.restDone()
                    AudioCue.shared.speak("Time")
                }
            }
        }
    }
    
    private func freezeExerciseTimer() {
        stopPrepTimer()
        stopExerciseTimer()
        if exerciseTimerSeconds > 0 {
            frozenExerciseTimerSeconds = exerciseTimerSeconds
        }
    }
    
    private func stopPrepTimer() {
        prepCountdownSeconds = 0
        prepTimer?.invalidate()
        prepTimer = nil
    }
    
    private func stopExerciseTimer() {
        exerciseTimerRunning = false
        exerciseTimer?.invalidate()
        exerciseTimer = nil
    }
    
    private func resetExerciseTimer() {
        stopPrepTimer()
        stopExerciseTimer()
        exerciseTimerSeconds = 0
        frozenExerciseTimerSeconds = nil
    }
    
    private func formatTimerDisplay(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "%02d", s)
    }
    
    // MARK: - Workout lifecycle
    
    private func startWorkout() {
        let current = AppGroupDefaults.shared.loadAppContext()
        guard DailyPractice.permitsStart(plan: plan, history: current.trainingHistory, restDays: current.restDays) else {
            errorState.post("Today is a rest day. Choose Joint Stretches or Evening stretching from home.")
            return
        }
        isStarting = true
        Task {
            do {
                try await sessionManager.startWorkout(activityType: plan.sessionType.workoutActivityType)
                activeWorkout.begin(plan: plan)
                let setStart = Date()
                activeWorkout.currentSetStartedAt = setStart
                activeWorkout.currentPreSetHeartRate = SwingSetHeartRateLogic.mostRecentSample(
                    atOrBefore: setStart,
                    samples: sessionManager.heartRateSamples
                )?.beatsPerMinute
                TrainingHaptic.setStart()
            } catch {
                errorState.post("Could not start workout session: \(error.localizedDescription)")
            }
            isStarting = false
        }
    }
    
    private func finishWorkout() {
        guard !isFinishing else { return }
        guard workoutStarted else { return }
        isFinishing = true
        finalizeHeartRateMetrics()
        let finishedPlan = plan
        let finishedLogs = completedExercises
        let exercises = finishedPlan.steps.compactMap { finishedLogs[$0.id] }
        guard exercises.contains(where: { $0.sets.contains(where: \.hasCompletedActivity) }) else {
            sessionManager.discardWorkout()
            activeWorkout.markFinished()
            isFinishing = false
            dismiss()
            return
        }
        let startedAt = sessionManager.sessionStartDate ?? Date().addingTimeInterval(-Double(sessionManager.elapsedSeconds))
        Task {
            defer { isFinishing = false }
            var hkUUID: UUID?
            do { hkUUID = try await sessionManager.endWorkout() }
            catch { errorState.post("Error saving HealthKit workout: \(error.localizedDescription)") }
            TrainingHaptic.workoutEnd()
            let finishedSummary = WorkoutSummarySnapshot(plan: finishedPlan, loggedExercises: finishedLogs,
                activeCalories: sessionManager.activeCalories, averageHeartRate: sessionManager.averageHeartRate,
                elapsedSeconds: sessionManager.elapsedSeconds)
            let workout = CompletedWorkout(
                sessionType: finishedPlan.sessionType, startDate: startedAt, endDate: Date(), exercises: exercises,
                activeCalories: sessionManager.activeCalories > 0 ? sessionManager.activeCalories : nil,
                averageHeartRate: sessionManager.averageHeartRate > 0 ? sessionManager.averageHeartRate : nil,
                peakHeartRate: sessionManager.peakHeartRate > 0 ? sessionManager.peakHeartRate : nil,
                hkWorkoutUUID: hkUUID)
            if let completion = EveningRotation.completion(for: workout,
                progressions: settings.skillProgressions + SkillProgressions.defaultSkillProgressions) {
                var cached = AppGroupDefaults.shared.loadAppContext()
                cached.lastEveningCompletion = completion
                cached.eveningRotationDay = EveningRotation.nextIndex(after: completion, fallback: cached.eveningRotationDay)
                AppGroupDefaults.shared.saveAppContext(cached)
            }
            AppGroupDefaults.shared.recordTrainingCompletion(workout)
            saveSkillEntries(plan: finishedPlan, loggedExercises: finishedLogs)
            WatchConnectivityManager.shared.sendWorkout(workout)
            summary = finishedSummary
            activeWorkout.markFinished()
        }
    }

    private func finalizeHeartRateMetrics() {
        for step in plan.steps {
            guard var exercise = completedExercises[step.id] else { continue }
            for index in exercise.sets.indices {
                let nextStart = exercise.sets.indices.contains(index + 1)
                    ? exercise.sets[index + 1].startedAt
                    : exercise.sets[index].recoveryStartedAt
                exercise.sets[index] = SwingSetHeartRateLogic.finalized(
                    exercise.sets[index],
                    nextSetStartedAt: nextStart,
                    samples: sessionManager.heartRateSamples
                )
            }
            completedExercises[step.id] = exercise
        }
    }

    private func skillLevel(for step: WorkoutStep) -> Int? {
        guard step.exercise.category == .skillProgression else { return nil }
        return settings.skillProgressions.first {
            $0.currentSkillLevel?.name == step.exercise.name
        }?.currentLevel
    }
    
    private func saveSkillEntries(plan: SessionPlan, loggedExercises: [UUID: CompletedExercise]) {
        for step in plan.steps where step.exercise.category == .skillProgression {
            guard let ex = loggedExercises[step.id], ex.sets.contains(where: \.hasCompletedActivity) else { continue }
            guard let progRecord = settings.skillProgressions.first(where: {
                $0.currentSkillLevel?.name == step.exercise.name
            }) else { continue }
            
            let entry = SkillSessionEntry(
                skillProgressionID: progRecord.id,
                level: progRecord.currentLevel,
                sets: ex.sets
            )
            
            WatchConnectivityManager.shared.sendSkillEntry(entry)
        }
    }
}

// MARK: - Set Logger Sheet

struct SetLoggerView: View {
    let step: WorkoutStep
    let round: Int
    let existingSets: [CompletedSet]
    let tguSide: TGUSide?           // nil for non-TGU exercises
    let suggestedDurationSeconds: Int?
    let onComplete: (CompletedSet) -> Void
    
    @State private var selectedStrengthWeight: Double?
    @State private var currentReps: Int = 0
    @State private var currentDuration: Int = 0
    @State private var currentDifficulty: DifficultyRating = .moderate
    @State private var isSubmitting = false
    @State private var settings = AppGroupDefaults.shared.loadAppContext()
    @Environment(\.dismiss) private var dismiss
    
    private var isTimed: Bool { step.exercise.setType == .timed }
    private var isKB: Bool { step.exercise.simpleSinisterType != nil }
    private var recordsDifficulty: Bool {
        step.recordsDifficulty
    }
    private var kettlebellExerciseType: KettlebellExerciseType {
        step.exercise.simpleSinisterType ?? .swing
    }
    private var usesProgressionWeight: Bool {
        WorkoutLogging.kettlebellLoad(for: step, settings: settings, setNumber: existingSets.count + 1)?.isProgression ?? false
    }

    private var kettlebellWeightKg: Double {
        WorkoutLogging.kettlebellLoad(for: step, settings: settings, setNumber: existingSets.count + 1)?.weight ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Title — show TGU side if applicable
                if let side = tguSide {
                    HStack(spacing: 6) {
                        Text(step.exercise.name)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("· \(side.label)")
                            .font(.headline)
                            .foregroundStyle(side == .left ? .cyan : .orange)
                    }
                } else {
                    Text(step.exercise.name)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Text("Set \(existingSets.count + 1) of \(step.sets)")
                    .font(.caption).foregroundStyle(WatchAppearance.supportingText)
                
                if step.strengthLoadKey != nil {
                    Picker("Load", selection: $selectedStrengthWeight) {
                        Text("Choose load").tag(Optional<Double>.none)
                        ForEach(WorkoutData.strengthWeights, id: \.self) { weight in
                            Text(formatWeight(weight)).tag(Optional(weight))
                        }
                    }
                    .font(.caption)
                    .pickerStyle(.wheel)
                    .frame(height: 80)
                }
                if isKB {
                    HStack {
                        Label("Weight", systemImage: "scalemass")
                            .font(.caption2)
                            .foregroundStyle(WatchAppearance.supportingText)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatWeight(kettlebellWeightKg))
                                .font(.caption.bold())
                            if usesProgressionWeight {
                                Text("Progression")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                
                if isTimed {
                    Stepper(value: $currentDuration, in: 0...600, step: 1) {
                        Text("Duration: \(currentDuration)s").font(.caption)
                    }
                    .onAppear {
                        currentDuration = suggestedDurationSeconds ?? step.durationSeconds ?? step.exercise.defaultDuration ?? 30
                    }
                } else {
                    Stepper(value: $currentReps, in: 0...200, step: 1) {
                        Text("Reps: \(currentReps)").font(.caption)
                    }
                    .onAppear { currentReps = step.reps ?? step.exercise.defaultReps ?? 10 }
                }
                
                if recordsDifficulty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Effort").font(.caption2).foregroundStyle(WatchAppearance.supportingText)
                        Picker("", selection: $currentDifficulty) {
                            ForEach(DifficultyRating.allCases, id: \.self) { d in
                                Text("\(d.emoji) \(d.label)").tag(d)
                            }
                        }
                        .pickerStyle(.wheel).frame(height: 80)
                    }
                }
                
                Button("Log Set") {
                    guard !isSubmitting else { return }
                    isSubmitting = true
                    let s = CompletedSet(
                        reps: isTimed ? nil : currentReps,
                        durationSeconds: isTimed ? currentDuration : nil,
                        feltDifficulty: currentDifficulty,
                        tguSide: tguSide,
                        weightKg: isKB ? kettlebellWeightKg : (step.strengthLoadKey != nil ? selectedStrengthWeight : nil)
                    )
                    onComplete(s)
                    dismiss()
                }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                .disabled(isSubmitting || (step.strengthLoadKey != nil && selectedStrengthWeight == nil) || (isTimed ? currentDuration <= 0 : currentReps <= 0))

                if !existingSets.isEmpty {
                    Divider()
                    ForEach(existingSets.indices, id: \.self) { i in
                        let s = existingSets[i]
                        HStack {
                            Text(s.tguSide.map { "Set \(i+1) \($0.label)" } ?? "Set \(i+1)")
                                .font(.caption2)
                            Spacer()
                            if let r = s.reps            { Text("\(r)r").font(.caption2) }
                            if let d = s.durationSeconds { Text("\(d)s").font(.caption2) }
                            if recordsDifficulty {
                                Text(s.feltDifficulty.emoji).font(.caption2)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            settings = AppGroupDefaults.shared.loadAppContext()
            selectedStrengthWeight = step.strengthLoadKey.flatMap { AppGroupDefaults.shared.strengthLoad(for: $0) }
                .flatMap { WorkoutData.strengthWeights.contains($0) ? $0 : nil }
        }
    }
    
    private func formatWeight(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg)) kg" : "\(kg) kg"
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WorkoutGuideView(plan: SessionPlan(
            sessionType: .morning,
            steps: WorkoutData.morningSteps,
            estimatedDurationMinutes: 60
        ))
    }
        .environment(ErrorState())
}

#endif

#Preview("Strength A") {
    NavigationStack {
        WorkoutGuideView(plan: WorkoutData.plan(for: .strengthA))
            .environment(ErrorState())
    }
}

#Preview("Joint Stretches") {
    NavigationStack {
        WorkoutGuideView(plan: WorkoutData.plan(for: .jointStretches))
            .environment(ErrorState())
    }
}

#if DEBUG
#Preview("Strength set adjustment") {
    SetLoggerView(step: WorkoutData.strengthBSteps.first { $0.strengthLoadKey == "cleanPress" }!,
                  round: 1, existingSets: [], tguSide: nil, suggestedDurationSeconds: nil) { _ in }
}

#Preview("Skill effort") {
    SetLoggerView(step: WorkoutData.plan(for: .evening).steps.first { $0.recordsDifficulty }!,
                  round: 1, existingSets: [], tguSide: nil, suggestedDurationSeconds: 20) { _ in }
}
#endif
