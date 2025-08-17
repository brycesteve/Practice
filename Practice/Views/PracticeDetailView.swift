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
        List {
            Section {
                PracticeDetailStatsView(practice: practice)
            }
            header: {
                Text("Stats")
            }
            .headerProminence(.increased)
            ForEach(practice.segments.enumerated(), id: \.offset) {
 _,
segment in
                DisclosureGroup {
                    
                    
                    // Mini HR chart for this phase
                    MiniHRChart(hrData: segment.heartRateDataPoints)
                        .frame(height: 120)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.background.secondary))
                    WorkRestSummaryView(workDuration: segment.workRestRatio.workTime, restDuration: segment.workRestRatio.restTime)
                        .cleanListItem()
                    
                    // Sets / rests in this phase
                    ForEach(segment.sets.enumerated(), id: \.offset) { _,set in
                        HStack {
                            Text(set.description)
                                .font(.footnote)
                            Spacer()
                            Text("\(set.repsOrDuration)")
                                .monospacedDigit()
                                .font(.footnote.bold())
                            Divider()
                            Text("\(set.lowHR.formatted(.number.precision(.fractionLength(0))))–\(set.highHR.formatted(.number.precision(.fractionLength(0)))) bpm")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                        .cleanListItem()
                    }
                }
                label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(segment.name)
                                .font(.subheadline.bold())
                            Text("\(segment.startDate.formatted(date: .omitted, time: .shortened)) – \(segment.endDate.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(.orange)
                    }
                }
            }
            
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .navigationTitle(practice.name)
        .navigationSubtitle(practice.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.large)
        
    }
}
