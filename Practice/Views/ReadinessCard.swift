//
//  ReadinessCard.swift
//  Practice
//
//  Created by Steve Bryce on 03/08/2025.
//


import SwiftUI
import HealthKit

struct ReadinessCard: View {
    @Environment(ReadinessManager.self) var manager
    var compactMode: Bool = false
    
    @State private var animatedScore: Double = 0
    
    @AppStorage(
        SharedIDs.readinessDateKey,
        store: SharedReadinessStore
            .defaults) var lastUpdated: Date?
    
    var body: some View {
        Group {
            if compactMode {
                // Compact: Vertical
                VStack(spacing: 12) {
                    readinessGauge
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recovery").font(.headline)
                    HStack(spacing: 16) {
                        
                        readinessGauge
                            .frame(width: 100, height: 100)
                        
                        readinessDetails
                    }
                    .frame(maxWidth: .infinity)
                    
                    ReadinessStackedBarView()
                    ReadinessInsightText()
                        .frame(maxWidth: .infinity, alignment: .center)
                    if let lastUpdated {
                        Text("Last Updated: \(lastUpdated.formatted(.relative(presentation: .named)))"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .onChange(of: manager.readinessScore, initial: true) {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedScore = Double(manager.readinessScore)
            }
        }
        
        .onAppear {
            withAnimation {
                animatedScore = Double(manager.readinessScore)
            }
        }
    }
    
    
    private var readinessGauge: some View {
        Gauge(value: animatedScore, in: 0...100) {
            Text("Recovery")
        } currentValueLabel: {
            Text("\(Int(animatedScore))")
                .font(.largeTitle)
                .bold()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(gradientForScore(Int(animatedScore)))
    }
    
    private var readinessDetails: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                metricView(
                    icon: "waveform.path.ecg",
                    iconColor: .blue,
                    value: "\(Int(manager.hrv)) ms",
                    label: "HRV"
                )
                .gridColumnAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                metricView(
                    icon: "bed.double.fill",
                    iconColor: .purple,
                    value: Duration.seconds(manager.sleepActual).formatted(.units(allowed: [.hours], fractionalPart: .show(length: 1))),
                    label: "Sleep"
                )
                .gridColumnAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GridRow {
                metricView(
                    icon: "flame.fill",
                    iconColor: .orange,
                    value: "\(Int(manager.strain)) kcal",
                    label: "Strain"
                )
                .gridColumnAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                metricView(
                    icon: "bolt.heart.fill",
                    iconColor: .red,
                    value: "\(manager.restingHR.formatted(.number.precision(.fractionLength(0)))) bpm",
                    label: "Resting HR"
                )
                .gridColumnAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func metricView(icon: String, iconColor: Color, value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .bold()
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helpers
    private func gradientForScore(_ score: Int) -> Gradient {
        if score >= 80 { return Gradient(colors: [.green, .green.opacity(0.7)]) }
        if score >= 60 { return Gradient(colors: [.yellow, .green]) }
        if score >= 40 { return Gradient(colors: [.orange, .yellow])}
        return Gradient(colors: [.orange, .red])
    }
    
    private func colorForScore(_ score: Int) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}




#Preview {
    ReadinessCard(compactMode: false)
        .environment(ReadinessManager.shared)
}
