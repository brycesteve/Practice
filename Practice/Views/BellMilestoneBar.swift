//
//  BellMilestoneBar.swift
//  Practice
//
//  Created by Steve Bryce on 03/08/2025.
//


import SwiftUI


struct BellSelection: Identifiable {
    let id = UUID()
    let weight: Double
    let tonnage: Double
}


struct BellMilestoneBar: View {
    var totalTonnage: Double           // current tonnage
    var milestones: [Double] = [8, 16, 24, 32, 40, 48]          // e.g., [24,28,32,36]
    
    @State private var selectedBell: BellSelection? = nil
    
    private var tonnageForMilestone: [Double] {
        milestones.map { Double(100 + 10) * $0 } // 100 swings + 10 getups
    }
    
    var body: some View {
        GeometryReader { geo in
            let bellWidth = max(30, (geo.size.width - CGFloat(milestones.count - 1) * 12) / CGFloat(milestones.count))
            
            HStack(spacing: 12) {
                ForEach(Array(milestones.enumerated()), id: \.offset) { idx, weight in
                    let goal = tonnageForMilestone[idx]
                    let prevGoal = idx > 0 ? tonnageForMilestone[idx - 1] : 0
                    
                    let fillAmount: Double = {
                        if totalTonnage >= goal { return 1.0 }
                        else if totalTonnage > prevGoal {
                            return (totalTonnage - prevGoal) / (goal - prevGoal)
                        } else { return 0.0 }
                    }()
                    
                    VStack {
                        ZStack {
                            
                            Image("kettlebell")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.gray.opacity(0.4))
                            
                            Image("kettlebell")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.green.gradient)
                                .mask(
                                    Rectangle()
                                        .frame(height: bellWidth * fillAmount)
                                        .offset(y: bellWidth * (1 - fillAmount) / 2)
                                )
                            
                        }
                        .frame(width: bellWidth, height: bellWidth)
                        .onTapGesture {
                            selectedBell = BellSelection(weight: weight, tonnage: goal)
                        }
                        Text("\(Int(weight))Kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: bellWidth)
        }
        .frame(height: 60)
        .popover(item: $selectedBell, arrowEdge: .bottom, content: { bell in
            VStack(spacing: 16) {
                Text("\(Int(bell.weight)) kg Goal")
                    .font(.title2.bold())
                Text("Target Tonnage: \(Int(bell.tonnage)) kg")
                    .font(.headline)
                
            }
            .padding()
            .glassEffect(.clear, in: .rect(cornerRadius: 12))
            .presentationCompactAdaptation(.popover)
        })
        
    }
}

#Preview {
    VStack(spacing: 20) {
        BellMilestoneBar(totalTonnage: 3400, milestones: [8,16,24,32,40,48])
    }
    .padding()
    .border(.black)
}
