/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The workout metrics view.
*/

import SwiftUI
import HealthKit

struct MetricsView: View {
    @Environment(PracticeManager.self) var practiceManager
    
    var body: some View {
        @Bindable var practiceManager = practiceManager
        NavigationStack {
            ScrollView {
                
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
                            .foregroundStyle(.mint)
                            
                            HStack(alignment: .top) {
                                Text(practiceManager.setDescription)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                Text(practiceManager.setWeight)
                            }
                            .font(.caption.smallCaps())
                            
                        }
                        .padding(.top)
                        .font(.system(.title2, design: .rounded).monospacedDigit().lowercaseSmallCaps())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .ignoresSafeArea(edges: .bottom)
                        
                        .toolbar {
                            ToolbarItemGroup(placement: .bottomBar) {
                                Spacer()
                                Button {
                                    practiceManager.startNextActivity()
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
        }
        
        
    }
}

#Preview {
    @Previewable @State var practiceManager = PracticeManager()
    MetricsView()
        .environment(practiceManager)
        .onAppear {
            practiceManager.selectedPractice = .SimpleAndSinister
            practiceManager.currentSegmentIndex = 1
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
