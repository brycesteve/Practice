//
//  ProgressGraphView.swift
//  Practice
//
//  Created by Steve Bryce on 20/07/2025.
//
import SwiftUI
import Charts



struct ProgressGraphView: View {
    var data: [PracticeVolume]
    

    var body: some View {
        VStack(alignment: .leading) {
            Text("Simple and Sinister Progress")
                    .font(.headline)
                
            Chart(data) {
                LineMark(
                    x: .value("Date", $0.date),
                    y: .value("Volume", $0.weight)
                )
                .foregroundStyle(.green)
                .interpolationMethod(.catmullRom)
                RuleMark(y: .value("Simple", 3520))
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(alignment: .leading) {
                        Text("Simple")
                            .foregroundStyle(.blue)
                    }
                RuleMark(y: .value("Sinister", 5280))
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(alignment: .leading) {
                        Text("Sinister")
                            .foregroundStyle(.purple)
                    }
                
                AreaMark(
                        x: .value("Date", $0.date),
                        y: .value("Volume", $0.weight)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.8),
                                Color.green.opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(.vertical)
            .chartYScale(domain: 0...6000)
            .chartYAxis(.hidden)
        }
        
        .padding()
        .frame(height: 250)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}

#Preview {
    @Previewable @State var data: [PracticeVolume] = [
        PracticeVolume(weight: 1800, date: Date()),
        PracticeVolume(weight: 1700, date: Date().addingTimeInterval(86400 * -1)),
        PracticeVolume(weight: 1600, date: Date().addingTimeInterval(86400 * -2)),
        PracticeVolume(weight: 1500, date: Date().addingTimeInterval(86400 * -3))
    ]
    
    ProgressGraphView(data: data)
    
}
