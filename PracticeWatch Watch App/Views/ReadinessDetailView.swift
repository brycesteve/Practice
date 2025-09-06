//
//  ReadinessDetailView.swift
//  Practice
//
//  Created by Steve Bryce on 06/09/2025.
//


import SwiftUI

struct ReadinessDetailView: View {
    var manager = ReadinessManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Gauge
                Gauge(value: Double(manager.readinessScore), in: 0...100) {
                    Text("Score")
                } currentValueLabel: {
                    Text("\(manager.readinessScore)")
                        .font(.title2.bold())
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(gradientForScore(manager.readinessScore))
                .frame(width: 50, height: 50)
                .padding(.bottom, 4)
                
                // Metrics grid (2x2)
                VStack (alignment: .leading, spacing: 12){
                    
                        metric(icon: "waveform.path.ecg", color: .blue,
                               value: "\(Int(manager.hrv)) ms", label: "HRV")
                        metric(icon: "bed.double.fill", color: .purple,
                               value: Duration.seconds(manager.sleepActual).formatted(.units(allowed: [.hours], fractionalPart: .show(length: 1))), label: "Sleep")
                    
                        metric(icon: "flame.fill", color: .orange,
                               value: "\(Int(manager.strain)) kcal", label: "Strain")
                        metric(icon: "bolt.heart.fill", color: .red,
                               value: "\(Int(manager.restingHR)) bpm", label: "Resting HR")
                    
                }
                .padding(.top, 4)
                //.frame(maxWidth: .infinity)
                
                // Insight text
                ReadinessInsightText()
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .environment(manager)
            }
            .padding()
        }
        .navigationTitle("Readiness")
    }
    
    private func metric(icon: String, color: Color, value: String, label: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            
            // Icon in fixed-size circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.8))
                    .frame(width: 32, height: 32) // fixed container
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold)) // dynamic sizing inline
                    .foregroundColor(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.callout.bold())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func gradientForScore(_ score: Int) -> Gradient {
        switch score {
        case 80...: return Gradient(colors: [.green, .green.opacity(0.7)])
        case 60..<80: return Gradient(colors: [.yellow, .green])
        case 40..<60: return Gradient(colors: [.orange, .yellow])
        default: return Gradient(colors: [.orange, .red])
        }
    }
}

#Preview {
    NavigationStack {
        ReadinessDetailView()
            .environment(ReadinessManager.shared)
    }
}
