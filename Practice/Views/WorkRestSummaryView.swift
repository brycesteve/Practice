//
//  WorkRestSummaryView.swift
//  Practice
//
//  Created by Steve Bryce on 17/08/2025.
//
import SwiftUI

struct WorkRestSummaryView: View {
    let workDuration: TimeInterval
    let restDuration: TimeInterval
    
    var ratio: Double {
        restDuration == 0 ? workDuration : workDuration / restDuration
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Work / Rest Ratio")
                .font(.headline.smallCaps())
            
            GeometryReader { geo in
                HStack(spacing: 0) {
                    let total = workDuration + restDuration
                    let workWidth = total > 0 ? geo.size.width * workDuration / total : 0
                    let restWidth = total > 0 ? geo.size.width * restDuration / total : 0
                    
                    RoundedRectangle(cornerRadius: 0)
                        .fill(.green)
                        .frame(width: workWidth, height: 20)
                    
                    RoundedRectangle(cornerRadius: 0)
                        .fill(.blue)
                        .frame(width: restWidth, height: 20)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(height: 20) // fixes GeometryReader’s expansion
            
            Text(String(format: "Work: %.0f sec, Rest: %.0f sec (%.2f:1)",
                        workDuration, restDuration, ratio))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}
