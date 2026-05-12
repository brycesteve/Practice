// TrainingWidget.swift — iOS Widget Extension Target
// Add a new "Widget Extension" target named "TrainingWidget".
// Add this file + Schema.swift + shared files to that target.
// Capabilities: iCloud + CloudKit (same container as iOS app).

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Entry

struct TrainingWidgetEntry: TimelineEntry {
    let date: Date
    let readinessScore: Double?
    let readinessLabel: String = ""
    let tonightSkill: String = "Planche"
    let restDayToday: Bool = false
    let trainedToday: Bool = false
    let trainedLast7: Int = 0
    let consistencyPercent: Double = 100
    
    static var placeholder: TrainingWidgetEntry {
        TrainingWidgetEntry(
            date: .now,
            readinessScore: 0
        )
    }
}

// MARK: - Provider

struct TrainingWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrainingWidgetEntry { .placeholder }
    
    func getSnapshot(in context: Context, completion: @escaping (TrainingWidgetEntry) -> Void) {
        completion(buildEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainingWidgetEntry>) -> Void) {
        let entry = buildEntry()
        let expiry = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
         
        completion(Timeline(entries: [entry], policy: .after(expiry)))
        
    }
    
    private func buildEntry() -> TrainingWidgetEntry {
        let context = AppGroupDefaults.shared.loadAppContext()
        
        return TrainingWidgetEntry(
            date: .now,
            readinessScore: context.recoveryData?.overallScore
        )
    }
}

struct ReadinessGauge: View {
    let entry: TrainingWidgetEntry
    
    var body: some View {
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
                .scaleEffect(1.5)
                .tint(readinessColor(score))
            } else {
                Gauge(value: 0, in: 0...100) {
                    Text("–").font(.caption2)
                } currentValueLabel: {
                    Image("kettlebell.flat")
                }
                .gaugeStyle(.accessoryCircular)
                .scaleEffect(1.5)
                .tint(.gray)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
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



// MARK: - Small widget view

struct SmallWidgetView: View {
    let entry: TrainingWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "figure.gymnastics")
                    .foregroundStyle(Color.accentColor)
                    .font(.caption2)
                Spacer()
                statusDot
            }
            
            if let score = entry.readinessScore {
                Text("\(Int(score))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(score))
                Text(entry.readinessLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("–")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("No data")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Text("Tonight: \(entry.tonightSkill)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    private var statusDot: some View {
        Circle()
            .fill(entry.trainedToday ? Color.green : entry.restDayToday ? Color.gray : Color.orange)
            .frame(width: 8, height: 8)
    }
    
    private func scoreColor(_ s: Double) -> Color {
        switch s {
        case 85...: return .green; case 70..<85: return .blue
        case 50..<70: return .yellow; case 30..<50: return .orange; default: return .red
        }
    }
}

// MARK: - Medium widget view

struct MediumWidgetView: View {
    let entry: TrainingWidgetEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Left — readiness score
            VStack(alignment: .leading, spacing: 4) {
                Text("Readiness")
                    .font(.caption2).foregroundStyle(.secondary)
                
                if let score = entry.readinessScore {
                    Text("\(Int(score))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(score))
                    Text(entry.readinessLabel)
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("–").font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("Wear Watch overnight")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Right — training status
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.trainedToday ? Color.green :
                                entry.restDayToday ? Color.gray : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(entry.trainedToday ? "Trained today" :
                            entry.restDayToday ? "Rest day" : "Not trained yet")
                    .font(.caption2)
                }
                
                Text("\(entry.trainedLast7)/7 days this week")
                    .font(.caption2).foregroundStyle(.secondary)
                
                Text("\(Int(entry.consistencyPercent))% consistency")
                    .font(.caption2).foregroundStyle(.secondary)
                
                Spacer()
                
                Text("🌙 \(entry.tonightSkill)")
                    .font(.caption2.bold())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    private func scoreColor(_ s: Double) -> Color {
        switch s {
        case 85...: return .green; case 70..<85: return .blue
        case 50..<70: return .yellow; case 30..<50: return .orange; default: return .red
        }
    }
}

// MARK: - Widget definition

struct TrainingWidget: Widget {
    let kind = "TrainingWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrainingWidgetProvider()) { entry in
            switch widgetFamily {
            case .systemSmall:  SmallWidgetView(entry: entry)
            case .systemMedium: MediumWidgetView(entry: entry)
            default:            SmallWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Training")
        .description("Readiness score and today's training status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
    
    @Environment(\.widgetFamily) private var widgetFamily
}

struct ReadinessWidget: Widget {
    let kind = "ReadinessWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrainingWidgetProvider()) { entry in
            switch widgetFamily {
            default:
                ReadinessGauge(entry: entry)
            }
        }
        .configurationDisplayName("Readiness")
        .description("Lock screen readiness view")
        .supportedFamilies([.accessoryCircular, .systemSmall])
    }
    
    @Environment(\.widgetFamily) private var widgetFamily
}

@main
struct TrainingWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrainingWidget()
        ReadinessWidget()
    }
}

#Preview(as: .systemSmall) {
    ReadinessWidget()
} timeline: {
    TrainingWidgetEntry.placeholder
}

