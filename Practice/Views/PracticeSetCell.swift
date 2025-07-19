//
//  PracticeSetCell.swift
//  Practice
//
//  Created by Steve Bryce on 06/07/2025.
//
import SwiftUI
import HealthKit

struct PracticeSetCell: View {
    var practiceSet: HKWorkoutActivity
    var body: some View {
        HStack {
            EmptyView()
//            VStack(alignment: .leading) {
//                Text(exercise).font(.headline.smallCaps())
//                Text(repsAndWeight)
//            }
//            Spacer()
//            VStack(alignment: .trailing) {
//                Text(totalDuration)
//                HStack {
//                    Image(systemName: "heart.fill")
//                        .foregroundStyle(.red)
//                    Text(heartRate)
//                }
//                
//            }
//            .font(.callout)
        }
        .padding()
    }
    
    
//    var exercise: String {
//        var name = practiceSet.type.name
//        if practiceSet.handedness != .none {
//            name += " - \(practiceSet.handedness.rawValue)"
//        }
//        return name
//    }
//    
//    var repsAndWeight: String {
//        guard practiceSet.type != .rest else {
//            return ""
//        }
//        var repString = "\(practiceSet.reps) reps"
//        if let weight = practiceSet.weight {
//            repString += " @ \(weight)Kg"
//        }
//        return repString
//    }
//    
//    var totalDuration: String {
//        let formatter = DateComponentsFormatter()
//        formatter.unitsStyle = .abbreviated
//        
//        return formatter.string(from: practiceSet.duration) ?? ""
//    }
//    
//    var heartRate: String {
//        
//        return "\(practiceSet.lowHR ?? 0)-\(practiceSet.highHR ?? 0)"
//    }
}
