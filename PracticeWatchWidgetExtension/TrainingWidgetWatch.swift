//
//  TrainingWidget.swift
//  Practice
//
//  Created by Steve Bryce on 28/04/2026.
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Complication 1: Readiness Gauge
struct ReadinessGaugeComplication: Widget {
    let kind = "ReadinessGauge"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrainingTimelineProvider()) { entry in
            ReadinessGaugeView(entry: entry)
        }
        .configurationDisplayName("Readiness")
        .description("Today's recovery and readiness score.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
        ])
        // Tapping the complication opens the recovery detail screen
        // The watch app handles the "training://recovery" URL in TrainingWatchApp
    }
}

struct ReadinessGaugeView: View {
    let entry: TrainingEntry
    @Environment(\.widgetFamily) private var family
    
    var body: some View {
        mainContent
            .widgetURL(URL(string: "training://recovery"))
            .containerBackground(.background, for: .widget)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch family {
            
        case .accessoryCircular:
            // Circular gauge — the classic watch complication face
            ZStack {
                if let score = entry.readinessScore {
                    Gauge(value: score, in: 0...100) {
                        Text("\(Int(score))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                    } currentValueLabel: {
                        Image("kettlebell.flat")
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(gaugeGradient)
                } else {
                    Gauge(value: 0, in: 0...100) {
                        Text("–").font(.caption2)
                    } currentValueLabel: {
                        Image("kettlebell.flat")
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(.gray)
                }
            }
            
        case .accessoryCorner:
            // .accessoryCorner renders the view into the watch face corner;
            // use .accessoryCircularCapacity to fill the curved bar.
            Gauge(value: entry.readinessScore ?? 0, in: 0...100) {
                Image(systemName: "heart.fill")
            } currentValueLabel: {
                Text(entry.readinessScore.map { "\(Int($0))" } ?? "–")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(gaugeGradient)
            
        case .accessoryInline:
            Label {
                Text("Readiness: \(entry.readinessScore.map { "\(Int($0))" } ?? "–")")
            } icon: {
                Image(systemName: "heart.fill")
            }
            
        default:
            Text(entry.readinessScore.map { "\(Int($0))" } ?? "–")
        }
    }
    
    private var gaugeGradient: Gradient {
        Gradient(colors: [.red, .orange, .yellow, .green])
    }
}

// MARK: - Complication 2: Skill Progress Ring



// MARK: - Shared timeline entry

struct TrainingEntry: TimelineEntry {
    let date: Date
    let readinessScore: Double?        // 0–100, nil if no data
    
    static var placeholder: TrainingEntry {
        TrainingEntry(
            date: .now,
            readinessScore: 72
        )
    }
    
    static var empty: TrainingEntry {
        TrainingEntry(
            date: .now,
            readinessScore: nil
        )
    }
}

// MARK: - Shared provider

struct TrainingTimelineProvider: TimelineProvider {
    typealias Entry = TrainingEntry
    
    func placeholder(in context: Context) -> TrainingEntry { .placeholder }
    
    func getSnapshot(in context: Context, completion: @escaping (TrainingEntry) -> Void) {
        completion(buildEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainingEntry>) -> Void) {
        let entry = buildEntry()
        let expiry = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        
        completion(Timeline(entries: [entry], policy: .after(expiry)))
    }
    
    // MARK: Build entry
    private func buildEntry() -> TrainingEntry {
        let context = AppGroupDefaults.shared.loadAppContext()
        guard let score = context.recoveryData else { return .empty }
        
        return TrainingEntry(
            date: .now,
            readinessScore: score.overallScore
        )
    }
    
    private func readinessColor(_ score: Double?) -> Color {
        guard let score else { return .gray }
        switch score {
        case 85...100: return .green
        case 70..<85:  return .blue
        case 50..<70:  return .yellow
        case 30..<50:  return .orange
        default:       return .red
        }
    }
}

// MARK: - Bundle

@main
struct TrainingComplicationsBundle: WidgetBundle {
    var body: some Widget {
        ReadinessGaugeComplication()
    }
}


#Preview(as: .accessoryCircular) {
    ReadinessGaugeComplication()
} timeline: {
    TrainingEntry.placeholder
}

