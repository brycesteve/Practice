//
//  SummaryMetricView.swift
//  Practice
//
//  Created by Steve Bryce on 17/08/2025.
//


import SwiftUI

struct SummaryMetricView: View {
    var icon: String
    var title: String
    var value: String
    var color: Color
    
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: icon)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
    }
}
