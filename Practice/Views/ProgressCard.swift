//
//  ProgressCard.swift
//  Practice
//
//  Created by Steve Bryce on 03/08/2025.
//


import SwiftUI

struct ProgressCard: View {
    var currentTonnage: Double // 0...1
    var milestones: [Double] = [8, 16, 24, 32, 40, 48] // milestone weights
    
    var simpleProgress: Double { currentTonnage / 3520 }
    var sinisterProgress: Double { currentTonnage / 5280 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)
            
            HStack(spacing: 16) {
                // Progress ring
                Spacer()
                ZStack {
                    Circle()
                        .stroke(lineWidth: 10)
                        .opacity(0.2)
                        .foregroundStyle(.indigo)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(simpleProgress))
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundStyle(.indigo.gradient)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: simpleProgress)
                    
                    VStack {
                        Text("\(Int(simpleProgress * 100))%")
                            .font(.headline)
                        Text("Simple")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 80, height: 80)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(lineWidth: 10)
                        .opacity(0.2)
                        .foregroundStyle(.indigo)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(sinisterProgress))
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundStyle(.indigo.gradient)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: sinisterProgress)
                    
                    VStack {
                        Text("\(Int(sinisterProgress * 100))%")
                            .font(.headline)
                        Text("Sinister")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 80, height: 80)
                Spacer()
                
                
            }
            // Milestone ladder
            BellMilestoneBar(totalTonnage: currentTonnage)
            .padding()
        }
        
    }
}

#Preview {
    ProgressCard(
        currentTonnage: 2640
    )
}
