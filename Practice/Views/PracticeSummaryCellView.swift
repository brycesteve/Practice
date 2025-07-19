//
//  WorkoutSummaryCellView.swift
//  Practice
//
//  Created by Steve Bryce on 22/06/2025.
//

import SwiftUI
import HealthKit


struct PracticeSummaryCellView: View {
    var practice: PracticeSummary
    
    var body: some View {
        HStack(spacing: 16) {
            if (practice.image != nil) {
                practice.image!
                    .resizable()
                    .frame(width: 25, height: 25)
                    .padding(8)
                    .background {
                        Circle()
                            .fill(.green)
                    }
                    .foregroundStyle(.black)
            }
            VStack(alignment: .leading) {
                Text(practice.name)
                    .font(.headline)
                    
                Text(practice.date.formatted(date: .omitted, time: .shortened))
                
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(practice.duration)
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text(practice.heartRateRange)
                }
                
            }
            .font(.callout)
        }
        .padding()
        .fontDesign(.rounded)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        
        
    }
    
    
    
}

#Preview {
    let workout = HKWorkout(activityType: .functionalStrengthTraining, start: Date(timeIntervalSinceNow: -3600), end: .now)
    let practice = PracticeSummary(from: workout)
    
    
    VStack {
        List {
            PracticeSummaryCellView(practice: practice)
                
        }
        .scrollContentBackground(.hidden)
        
    }
}
