/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The workout metrics view.
*/

import SwiftUI
import HealthKit
import Combine

struct MetricsView: View {
    @Environment(PracticeManager.self) var practiceManager
    
    @State var crownManager = CrownRotationManager()
    
    @State var exerciseTimeRemaining: TimeInterval = 0
    @State var exerciseTimer: Cancellable?
    
    var body: some View {
        @Bindable var practiceManager = practiceManager
        NavigationStack {
            VStack {
                TimelineView(MetricsTimelineSchedule(from: practiceManager.builder?.startDate ?? Date(),
                                                         isPaused: practiceManager.session?.state == .paused)) { context in
                        VStack(alignment: .leading) {
                            ElapsedTimeView(elapsedTime: practiceManager.builder?.elapsedTime(at: context.date) ?? 0, showSubseconds: context.cadence == .live)
                                .foregroundStyle(.yellow)
                            //                    Text(Measurement(value: workoutManager.activeEnergy, unit: UnitEnergy.kilocalories)
                            //                        .formatted(.measurement(width: .abbreviated, usage: .workout, numberFormatStyle: .number.precision(.fractionLength(0)))))
                            
                            PulseView(bpm: $practiceManager.heartRate)
                            
                            HStack {
                                Text(practiceManager.segmentDescription)
                                
                                Spacer()
                                Text(practiceManager.segmentSetCount)
                            }
                            .font(.headline.lowercaseSmallCaps())
                            .foregroundStyle(.blue)
                            
                            HStack(alignment: .top) {
                                Text(practiceManager.setDescription)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                Text(practiceManager.setRepsOrDuration)
                            }
                            .font(.caption.smallCaps())
                            .foregroundStyle(.mint)
                            if (practiceManager.showExerciseTimer) {
                                HStack(alignment: .center) {
                                    Label(formattedTimeRemaining, systemImage: "timer")
                                        .symbolRenderingMode(.multicolor)
                                        .padding(.top, 4)
                                }
                            }
                            
                        }
                        //.padding(.top)
                        .font(.system(.title2, design: .rounded).monospacedDigit().lowercaseSmallCaps())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ignoresSafeArea(edges: .bottom)
                        
                        .toolbar {
                            ToolbarItemGroup(placement: .bottomBar) {
                                Spacer()
                                Button {
                                    manualAdvance()
                                }
                                label: {
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .scenePadding()
                }
            }
            .withDigitalCrown(manager: crownManager)
            .onChange(of: showTimerHash, initial: true) {
                _,_ in
                if practiceManager.showExerciseTimer {
                    setupTimer()
                }
            }
           .onAppear {
                crownManager.onTrigger = {
                    manualAdvance()
                }
            }
        }
        
        
        
    }
    
    var showTimerHash: Int {
        var hasher = Hasher()
        hasher.combine(practiceManager.currentSegmentIndex)
        hasher.combine(practiceManager.currentExerciseIndex)
        hasher.combine(practiceManager.showExerciseTimer)
        
        return hasher.finalize()
    }
    
    func setupTimer() {
        exerciseTimeRemaining = TimeInterval(practiceManager.exerciseTimerDuration?.components.seconds ?? 0)
        exerciseTimeRemaining -= 1
        stopExerciseTimer()
        exerciseTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                exerciseTimeRemaining -= 1
                if exerciseTimeRemaining <= 0 {
                    WKInterfaceDevice.current().play(.notification)
                    stopExerciseTimer()
                    practiceManager.startNextActivity()
                }
            }
    }
    
    var formattedTimeRemaining: String {
        return Duration.seconds(exerciseTimeRemaining).formatted(.units(width: .narrow))
    }
    
    func stopExerciseTimer() {
        exerciseTimer?.cancel()
        exerciseTimer = nil
    }
    
    func manualAdvance() {
        WKInterfaceDevice.current().play(.click)
        stopExerciseTimer()
        practiceManager.startNextActivity()
    }
}

#Preview {
    @Previewable @State var practiceManager = PracticeManager.shared
    MetricsView()
        .environment(practiceManager)
        .onAppear {
            practiceManager.selectedPractice = .SimpleAndSinisterStretches
            practiceManager.currentSegmentIndex = 0
            practiceManager.currentExerciseIndex = 2
        }
}

private struct MetricsTimelineSchedule: TimelineSchedule {
    var startDate: Date
    var isPaused: Bool

    init(from startDate: Date, isPaused: Bool) {
        self.startDate = startDate
        self.isPaused = isPaused
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var baseSchedule = PeriodicTimelineSchedule(from: self.startDate,
                                                    by: (mode == .lowFrequency ? 1.0 : 1.0 / 30.0))
            .entries(from: startDate, mode: mode)
        
        return AnyIterator<Date> {
            guard !isPaused else { return nil }
            return baseSchedule.next()
        }
    }
}
