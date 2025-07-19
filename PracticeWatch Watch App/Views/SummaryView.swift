/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The workout summary view.
*/

import Foundation
import HealthKit
import SwiftUI
import WatchKit

struct SummaryView: View {
    @Environment(PracticeManager.self) var practiceManager
    @Environment(\.dismiss) var dismiss
    @State private var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    var body: some View {
        if practiceManager.workout == nil {
            ProgressView("Saving Workout")
                .navigationBarHidden(true)
        } else {
            ScrollView {
                VStack(alignment: .leading) {
                    SummaryMetricView(title: "Total Time",
                                      value: durationFormatter.string(from: practiceManager.workout?.duration ?? 0.0) ?? "")
                        .foregroundStyle(.yellow)
                    
                    SummaryMetricView(title: "Total Energy",
                                      value: Measurement(value: totalEnergy(),
                                                         unit: UnitEnergy.kilocalories)
                                        .formatted(.measurement(width: .abbreviated,
                                                                usage: .workout,
                                                                numberFormatStyle: .number.precision(.fractionLength(0)))))
                        .foregroundStyle(.pink)
                    SummaryMetricView(title: "Avg. Heart Rate",
                                      value: avgHeartRate().formatted(.number.precision(.fractionLength(0))) + " bpm")
                        .foregroundStyle(.red)
                    Text("Activity").font(.headline.smallCaps())
                    ActivityRingsView(healthStore: practiceManager.healthStore)
                        .frame(width: 50, height: 50)
                    Button("Done") {
                        dismiss()
                    }
                }
                .scenePadding()
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func totalEnergy() -> Double {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            { return 100 }
        let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        return practiceManager.workout?.statistics(for: type)?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
    }
    
    
    func avgHeartRate() -> Double {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        { return 80 }
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        return practiceManager.workout?.statistics(for: type)?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
    }
}


#Preview {
    @Previewable @Bindable var practiceManager = PracticeManager()
    ScrollView {
        SummaryView()
            .environment(practiceManager)
            .onAppear {
                practiceManager.workout = HKWorkout(activityType: .functionalStrengthTraining, start: Date(timeIntervalSinceNow: -3600), end: .now)
            }
    }
}

struct SummaryMetricView: View {
    var title: String
    var value: String

    var body: some View {
        Text(title)
            .font(.headline.smallCaps())
            .foregroundStyle(.white)
        Text(value)
            .font(.system(.title2, design: .rounded).lowercaseSmallCaps())
        Divider()
    }
}
