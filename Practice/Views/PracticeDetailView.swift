//
//  PracticeDetail.swift
//  Practice
//
//  Created by Steve Bryce on 22/06/2025.
//
import SwiftUI
import HealthKit

struct PracticeDetailView: View {
    @State var practice: PracticeDetailViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                
                // 🔹 Summary Card
                PracticeDetailSummaryCardView(practice: practice)
                
                // 🔹 Segments
                ForEach(practice.segments.enumerated(), id: \.offset) { _, segment in
                    DisclosureGroup {
                        VStack(spacing: 12) {
                            
                            // HR Chart
                            MiniHRChart(hrData: segment.heartRateDataPoints)
                                .frame(height: 80)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.background.secondary)
                                )
                            
                            // Work/Rest ratio
                            WorkRestSummaryView(
                                workDuration: segment.workRestRatio.workTime,
                                restDuration: segment.workRestRatio.restTime
                            )
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.background.secondary)
                            )
                            
                            // Sets
                            VStack(spacing: 4) {
                                ForEach(segment.sets.enumerated(), id: \.offset) { _, set in
                                    HStack {
                                        Text(set.description)
                                            .font(.footnote)
                                        
                                        Spacer()
                                        
                                        Text("\(set.repsOrDuration)")
                                            .font(.footnote.bold())
                                            .monospacedDigit()
                                        
                                        Divider()
                                        
                                        Text("\(set.lowHR.formatted(.number.precision(.fractionLength(0))))–\(set.highHR.formatted(.number.precision(.fractionLength(0)))) bpm")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.background.secondary)
                            )
                        }
                        .padding(.top, 8)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(segment.name)
                                    .font(.subheadline.bold())
                                Text("\(segment.startDate.formatted(date: .omitted, time: .shortened)) – \(segment.endDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: iconForSegment(segment.name))
                                .foregroundStyle(colorForSegment(segment.name))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thinMaterial)
                    )
                }
            }
            .padding()
        }
        .navigationTitle(practice.name)
        .navigationSubtitle(practice.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }
    
    func iconForSegment(_ name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("warm"): return "sunrise.fill"
        case let n where n.contains("swing"): return "dumbbell.fill"
        case let n where n.contains("get up"): return "figure.strengthtraining.traditional"
        case let n where n.contains("rest"): return "pause.fill"
        default: return "bolt.heart.fill"
        }
    }
    
    func colorForSegment(_ name: String) -> Color {
        switch name.lowercased() {
        case let n where n.contains("warm"): return .orange
        case let n where n.contains("swing"): return .green
        case let n where n.contains("get up"): return .blue
        case let n where n.contains("rest"): return .gray
        default: return .purple
        }
    }
}

struct PracticeDetailSummaryMetricView: View {
    var title: String
    var value: String
    var color: Color
    var icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
