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
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
        utterance.volume = 1.0
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
            audioSessionConfigured = false
        }
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

private struct WorkoutPosition: Equatable {
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

// MARK: - Main View

struct WorkoutGuideView: View {
    @Environment(ErrorState.self) var errorState
    
    let plan: SessionPlan
    
    @State private var settings = AppGroupDefaults.shared.loadAppContext()
    
    @State private var position = WorkoutPosition.start()
    @State private var completedExercises: [UUID: CompletedExercise] = [:]
    @State private var showSetLogger  = false
    @State private var showPauseMenu  = false
    @State private var showEndConfirm = false
    @State private var showSummary    = false
    @State private var workoutStarted = false
    @State private var isStarting     = false
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var restSecondsRemaining = 0
    @State private var restTimer: Timer? = nil
    @State private var sessionManager = WorkoutSessionManager.shared
    @State private var restCuePlayed = false
    
    // TGU side tracking — persists across sets within the exercise
    @State private var nextTGUSide: TGUSide = .left
    // HR threshold — user can adjust on the rest screen
    @State private var hrThresholdOverride: Double? = nil
    // Exercise timer for timed sets
    @State private var exerciseTimerSeconds: Int = 0
    @State private var exerciseTimerRunning: Bool = false
    @State private var exerciseTimer: Timer? = nil
    
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
    
    private var isTGU: Bool {
        currentStep?.exercise.name.contains("Get-Up") ?? false
    }
    
    // MARK: Body
    
    var body: some View {
        Group {
            if showSummary {
                WorkoutSummaryView(
                    plan: plan,
                    completedExercises: Array(completedExercises.values),
                    activeCalories: sessionManager.activeCalories,
                    avgHeartRate: sessionManager.heartRate,
                    elapsedSeconds: sessionManager.elapsedSeconds
                )
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
                    tguSide: isTGU ? nextTGUSide : nil
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
        .alert("End workout?", isPresented: $showEndConfirm) {
            Button("End & Save", role: .destructive) { finishWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Progress so far will be saved.")
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
        
        progressBar
        
        if isCircuit {
            let posInCircuit = (circuit.firstIndex(where: { $0.id == step.id }) ?? 0) + 1
            Label("Round \(position.round)/\(step.sets) · Ex \(posInCircuit)/\(circuit.count)",
                  systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
            .font(.caption2).foregroundStyle(.secondary)
        } else {
            Text("Set \(position.round) of \(step.sets)")
                .font(.caption2).foregroundStyle(.secondary)
        }
        
        categoryBadge(step.exercise.category)
        
        // TGU shows next side
        if step.exercise.name.contains("Get-Up") {
            HStack(spacing: 6) {
                Text(step.exercise.name).font(.headline)
                Text("· \(nextTGUSide.label)")
                    .font(.headline)
                    .foregroundStyle(nextTGUSide == .left ? .blue : .orange)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(step.exercise.name)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        
        Text(step.displayTarget)
            .font(.subheadline).foregroundStyle(Color.accentColor)
        
        if step.exercise.setType == .timed {
            exerciseTimerView(step: step)
        }
        
        if step.exercise.category == .kettlebell, let last = lastKBWeight(for: step) {
            Label("Last: \(formatWeight(last))", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        
        if let notes = step.exercise.notes {
            Text(notes)
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        
        // Logged sets this exercise
        let logged = completedExercises[step.id]?.sets ?? []
        if !logged.isEmpty {
            Divider()
            ForEach(logged.indices, id: \.self) { i in
                HStack {
                    if let side = logged[i].tguSide {
                        Text("Set \(i+1) \(side.label)").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Set \(i+1)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let r = logged[i].reps            { Text("\(r) reps").font(.caption2) }
                    if let d = logged[i].durationSeconds { Text("\(d)s").font(.caption2)     }
                    Text(logged[i].feltDifficulty.emoji).font(.caption2)
                }
            }
        }
        
        if workoutStarted { Divider(); liveMetrics }
        
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
                    TrainingHaptic.setStart()
                    showSetLogger = true
                } label: {
                    Label("Log Set", systemImage: "checkmark.circle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button { skipStep() } label: {
                    Label("Skip", systemImage: "forward.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - HR rest phase
    
    @ViewBuilder
    private func hrRestPhase(step: WorkoutStep) -> some View {
        let threshold = hrThresholdOverride ?? step.hrRestThresholdBPM
        
        VStack(spacing: 12) {
            Text("Rest").font(.title3.bold())
            Image(systemName: "heart.fill")
                .font(.largeTitle).foregroundStyle(.red).symbolEffect(.pulse)
            Text("\(Int(sessionManager.heartRate)) bpm")
                .font(.title.monospacedDigit())
                .foregroundStyle(heartRateColor(sessionManager.heartRate, threshold: step.hrRestThresholdBPM))
            HStack {
                Text("Target: \(Int(threshold)) bpm")
                    .font(.caption).foregroundStyle(.secondary)
                Stepper("", value: Binding(
                    get: { hrThresholdOverride ?? step.hrRestThresholdBPM },
                    set: { hrThresholdOverride = $0 }
                ), in: 80...170, step: 5)
                .labelsHidden()
                .frame(width: 60)
            }
            
            let ready = sessionManager.heartRate > 0 && sessionManager.heartRate <= threshold
            Button {
                if ready { TrainingHaptic.restDone() }
                advanceAfterRest(step: step)
            } label: {
                Label(ready ? "Next Set" : "Skip Rest",
                      systemImage: ready ? "checkmark.circle.fill" : "forward.fill")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(ready ? .green : .orange)
        }
        .padding(.vertical, 8)
        .onAppear {
            restCuePlayed = false
        }
        .onChange(of: sessionManager.heartRate) { _, newHR in
            let t = hrThresholdOverride ?? step.hrRestThresholdBPM
            if newHR <= t && newHR > 0 {
                TrainingHaptic.restDone()
                if !restCuePlayed {
                    restCuePlayed = true
                    AudioCue.shared.speak("Ready")
                }
            }
        }
    }
    
    // MARK: - Timed rest phase
    
    @ViewBuilder
    private func timedRestPhase(step: WorkoutStep) -> some View {
        VStack(spacing: 12) {
            Text("Rest").font(.title3.bold())
            Text("\(restSecondsRemaining)s")
                .font(.title.monospacedDigit().bold())
                .foregroundStyle(restSecondsRemaining <= 5 ? .green : .primary)
            Text("Next: \(nextExerciseName(after: step))")
                .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if workoutStarted { liveMetrics }
            Button {
                stopRestTimer()
                advanceAfterRest(step: step)
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
            Text("Saving…").font(.caption).foregroundStyle(.secondary)
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
    
    private var liveMetrics: some View {
        HStack {
            Label("\(Int(sessionManager.heartRate)) bpm", systemImage: "heart.fill").foregroundStyle(.red)
            Spacer()
            Label("\(Int(sessionManager.activeCalories)) kcal", systemImage: "flame.fill").foregroundStyle(.orange)
        }
        .font(.caption2)
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
            .background(color.opacity(0.25)).foregroundStyle(color)
            .clipShape(Capsule())
    }
    
    private func heartRateColor(_ hr: Double, threshold: Double) -> Color {
        hr <= threshold && hr > 0 ? .green : hr > threshold * 1.1 ? .red : .orange
    }
    
    private func nextExerciseName(after step: WorkoutStep) -> String {
        let next = computeNextPosition(after: step, completing: position.round)
        guard next.stepIndex < plan.steps.count else { return "Done" }
        return plan.steps[next.stepIndex].exercise.name
    }
    
    // MARK: - Navigation
    
    private func handleSetLogged(set: CompletedSet, for step: WorkoutStep) {
        TrainingHaptic.setLogged()
        
        if completedExercises[step.id] == nil {
            completedExercises[step.id] = CompletedExercise(
                exerciseID: step.exercise.id,
                exerciseName: step.exercise.name,
                sets: [],
                skillLevel: step.exercise.category == .skillProgression ? step.sets : nil
            )
        }
        completedExercises[step.id]?.sets.append(set)
        
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
        return plan.steps.filter { $0.circuitGroupID == gid }.last?.id == step.id
    }
    
    private func circuitEndRest(for step: WorkoutStep) -> Int {
        guard let gid = step.circuitGroupID else { return step.restSeconds }
        return plan.steps.filter { $0.circuitGroupID == gid }.last?.restSeconds ?? step.restSeconds
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
        if let gid = step.circuitGroupID {
            let circuit         = plan.steps.filter { $0.circuitGroupID == gid }
            let posInCircuit    = circuit.firstIndex(where: { $0.id == step.id }) ?? 0
            let isLastInCircuit = posInCircuit == circuit.count - 1
            let totalRounds     = step.sets
            
            if !isLastInCircuit {
                let nextIdx = plan.steps.firstIndex(where: { $0.id == circuit[posInCircuit + 1].id }) ?? (position.stepIndex + 1)
                return WorkoutPosition(stepIndex: nextIdx, round: round, phase: .exercise)
            } else if round < totalRounds {
                let firstIdx = plan.steps.firstIndex(where: { $0.id == circuit[0].id }) ?? position.stepIndex
                return WorkoutPosition(stepIndex: firstIdx, round: round + 1, phase: .exercise)
            } else {
                return advanceToNextGroup(after: step)
            }
        } else {
            if round < step.sets {
                return WorkoutPosition(stepIndex: position.stepIndex, round: round + 1, phase: .exercise)
            } else {
                return advanceToNextGroup(after: step)
            }
        }
    }
    
    private func advanceToNextGroup(after step: WorkoutStep) -> WorkoutPosition {
        var nextIdx = position.stepIndex + 1
        if let gid = step.circuitGroupID {
            while nextIdx < plan.steps.count && plan.steps[nextIdx].circuitGroupID == gid { nextIdx += 1 }
        }
        if nextIdx >= plan.steps.count {
            return WorkoutPosition(stepIndex: nextIdx, round: 1, phase: .done)
        }
        return WorkoutPosition(stepIndex: nextIdx, round: 1, phase: .exercise)
    }
    
    private func moveToNextStep(from step: WorkoutStep) {
        position = advanceToNextGroup(after: step)
        scrollToTop()
    }
    
    private func skipStep() {
        guard let step = currentStep else { return }
        position = advanceToNextGroup(after: step)
        scrollToTop()
    }
    
    // MARK: - Rest timer
    
    private func startRestTimer(seconds: Int, step: WorkoutStep) {
        restSecondsRemaining = seconds
        position.phase = .timedRest
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
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
    
    private func scrollToTop() {
        Task { @MainActor in
            withAnimation { scrollProxy?.scrollTo("top", anchor: .top) }
        }
    }
    
    // MARK: - Exercise timer
    
    @ViewBuilder
    private func exerciseTimerView(step: WorkoutStep) -> some View {
        let target = step.durationSeconds ?? step.exercise.defaultDuration ?? 30
        
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: min(Double(exerciseTimerSeconds) / Double(target), 1.0))
                    .stroke(
                        exerciseTimerSeconds >= target ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: exerciseTimerSeconds)
                VStack(spacing: 0) {
                    Text(formatTimerDisplay(exerciseTimerSeconds))
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(exerciseTimerSeconds >= target ? .green : .primary)
                    Text("/ \(target)s")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)
            
            HStack(spacing: 10) {
                Button {
                    if exerciseTimerRunning { stopExerciseTimer() }
                    else { startExerciseTimer(target: target) }
                } label: {
                    Image(systemName: exerciseTimerRunning ? "pause.fill" : "play.fill")
                        .font(.caption.bold())
                        .frame(width: 36, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .tint(exerciseTimerRunning ? .orange : .accentColor)
                
                Button { resetExerciseTimer() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.bold())
                        .frame(width: 36, height: 28)
                }
                .buttonStyle(.bordered)
                .disabled(exerciseTimerSeconds == 0 && !exerciseTimerRunning)
            }
            
            if exerciseTimerSeconds >= target {
                Label("Target reached!", systemImage: "checkmark.circle.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func startExerciseTimer(target: Int) {
        exerciseTimerRunning = true
        TrainingHaptic.setStart()
        exerciseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                self.exerciseTimerSeconds += 1
                if self.exerciseTimerSeconds == target {
                    TrainingHaptic.restDone()
                    AudioCue.shared.speak("Time")
                }
            }
        }
    }
    
    private func stopExerciseTimer() {
        exerciseTimerRunning = false
        exerciseTimer?.invalidate()
        exerciseTimer = nil
    }
    
    private func resetExerciseTimer() {
        stopExerciseTimer()
        exerciseTimerSeconds = 0
    }
    
    private func formatTimerDisplay(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "%02d", s)
    }
    
    // MARK: - Workout lifecycle
    
    private func startWorkout() {
        isStarting = true
        Task {
            do {
                try await sessionManager.startWorkout(activityType: plan.sessionType.workoutActivityType)
                workoutStarted = true
                TrainingHaptic.setStart()
            } catch {
                errorState.post("Could not start workout session: \(error.localizedDescription)")
            }
            isStarting = false
        }
    }
    
    private func finishWorkout() {
        Task {
            var hkUUID: UUID?
            if workoutStarted {
                do { hkUUID = try await sessionManager.endWorkout() }
                catch { errorState.post("Error saving HealthKit workout: \(error.localizedDescription)") }
            }
            
            TrainingHaptic.workoutEnd()
            
            let exercises = plan.steps.compactMap { completedExercises[$0.id] }
            let workout = CompletedWorkout(
                sessionType: plan.sessionType,
                startDate: Date().addingTimeInterval(-Double(sessionManager.elapsedSeconds)),
                endDate: Date(),
                exercises: exercises,
                activeCalories: sessionManager.activeCalories > 0 ? sessionManager.activeCalories : nil,
                averageHeartRate: sessionManager.heartRate > 0 ? sessionManager.heartRate : nil,
                hkWorkoutUUID: hkUUID
            )
            
            if plan.sessionType == .evening {
                settings.eveningRotationDay = (
                    settings.eveningRotationDay + 1
                ) % Skill.activeSkills.count
                WatchConnectivityManager.shared
                    .sendRotationDay(settings.eveningRotationDay)
            }
            
            saveSkillEntries()
           
            WatchConnectivityManager.shared.sendWorkout(workout)
            showSummary = true
        }
    }
    
    private func saveSkillEntries() {
        for step in plan.steps where step.exercise.category == .skillProgression {
            guard let ex = completedExercises[step.id], !ex.sets.isEmpty else { continue }
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
    let onComplete: (CompletedSet) -> Void
    
    @State private var currentReps: Int = 0
    @State private var currentDuration: Int = 0
    @State private var currentDifficulty: DifficultyRating = .moderate
    @State private var weightKg: Double = 24.0
    @Environment(\.dismiss) private var dismiss
    
    private var isTimed: Bool { step.exercise.setType == .timed }
    private var isKB: Bool    { step.exercise.category == .kettlebell }
    
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
                            .foregroundStyle(side == .left ? .blue : .orange)
                    }
                } else {
                    Text(step.exercise.name)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Text("Set \(existingSets.count + 1) of \(step.sets)")
                    .font(.caption).foregroundStyle(.secondary)
                
                if isKB {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weight").font(.caption2).foregroundStyle(.secondary)
                        Picker("", selection: $weightKg) {
                            ForEach(WorkoutData.kbWeights, id: \.self) { w in
                                Text(formatWeight(w)).tag(w)
                            }
                        }
                        .pickerStyle(.wheel).frame(height: 80)
                    }
                }
                
                if isTimed {
                    Stepper(value: $currentDuration, in: 0...600, step: 1) {
                        Text("Duration: \(currentDuration)s").font(.caption)
                    }
                    .onAppear { currentDuration = step.durationSeconds ?? step.exercise.defaultDuration ?? 30 }
                } else {
                    Stepper(value: $currentReps, in: 0...200, step: 1) {
                        Text("Reps: \(currentReps)").font(.caption)
                    }
                    .onAppear { currentReps = step.reps ?? step.exercise.defaultReps ?? 10 }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Effort").font(.caption2).foregroundStyle(.secondary)
                    Picker("", selection: $currentDifficulty) {
                        ForEach(DifficultyRating.allCases, id: \.self) { d in
                            Text("\(d.emoji) \(d.label)").tag(d)
                        }
                    }
                    .pickerStyle(.wheel).frame(height: 80)
                }
                
                Button("Log Set") {
                    let s = CompletedSet(
                        reps: isTimed ? nil : currentReps,
                        durationSeconds: isTimed ? currentDuration : nil,
                        feltDifficulty: currentDifficulty,
                        tguSide: tguSide
                    )
                    if isKB {
                        let exType: KettlebellExerciseType = step.exercise.name.contains("Get-Up") ? .tgu : .swing
                        WatchConnectivityManager.shared.sendKettlebellEntry(
                            exerciseType: exType, weightKg: weightKg, sets: 1, reps: currentReps
                        )
                    }
                    onComplete(s)
                    dismiss()
                }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                
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
                            Text(s.feltDifficulty.emoji).font(.caption2)
                        }
                    }
                }
            }
            .padding()
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
