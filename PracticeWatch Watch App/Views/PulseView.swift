//
//  PulseView.swift
//  Practice
//
//  Created by Steve Bryce on 01/06/2025.
//

import SwiftUI
import OSLog

struct PulseView: View {
    @Binding var bpm: Double
    @State private var pulseActive: Bool = false
    @State private var timer: Timer?
    @State private var activeBpm: Double = 0
    
    @State private var bpmHistory: [Double] = []
    @State private var maxSamples = 5
    
    var body: some View {
        HStack(spacing: -2) {
            Text(bpm > 0 ? "\(bpm.formatted(.number.precision(.fractionLength(0))))" : "--")
            Image(systemName: "heart")
                .symbolVariant(bpm > 0 ? .fill : .none)
                .foregroundStyle(.red)
                .scaleEffect(pulseActive ? 0.7 : 0.6)
                .symbolEffect(.pulse, isActive: bpm == 0)
                
                
                
            
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onAppear {
            startPulse()
        }
        .onChange(of: bpm) {
            addBpmSample(bpm)
            startPulse()
        }
        
        
    }
    
    func startPulse() {
        timer?.invalidate()
        
        let interval = 60.0 / max(activeBpm, 1)
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { _ in
            triggerPulse(interval: interval)
        })
        
        triggerPulse(interval: interval)
    }
    
    private func addBpmSample(_ sample: Double) {
        bpmHistory.append(sample)
        if bpmHistory.count > maxSamples {
            bpmHistory.removeFirst()
        }
        
        activeBpm = bpmHistory.reduce(0, +) / Double(bpmHistory.count)
    }
    
    private func triggerPulse(interval: Double) {
        withAnimation(.spring(response: interval / 3, dampingFraction: 0.4)) {
            pulseActive = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval / 3) {
            withAnimation(.easeOut(duration: interval * 2 / 3)) {
                pulseActive = false
            }
        }
    }
    
}

#Preview {
    @Bindable var practiceManager = PracticeManager()
    
    PulseView(bpm: .constant(100))
}
