//
//  PracticeWatchWidgetExtension.swift
//  PracticeWatchWidgetExtension
//
//  Created by Steve Bryce on 06/08/2025.
//

import WidgetKit
import SwiftUI


struct ReadinessWidgetView: View {
    var entry: ReadinessEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.redactionReasons) var redactionReasons
    var body: some View {
        switch family {
            // Apple Watch circular complication
        case .accessoryCircular:
            Gauge(value: Double(entry.readinessScore), in: 0...100) {
                Text("\(entry.readinessScore)%")
                    .privacySensitive()
                    
            }
            currentValueLabel: {
                Image("kettlebell.flat")
                    .opacity(redactionReasons.contains(.privacy) ? 0.7 : 1.0)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(scoreColor.gradient)
            .widgetAccentable()
            .containerBackground(.fill.quaternary, for: .widget)
            .widgetURL(URL(string: "practice://readinessDetail"))
            // Apple Watch rectangular complication
        case .accessoryRectangular:
            HStack {
                Gauge(value: Double(entry.readinessScore), in: 0...100) {
                    Image("kettlebell.flat")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(scoreColor.gradient)
                .widgetAccentable()
                VStack(alignment: .leading) {
                    Text("Recovery")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(entry.readinessScore)%")
                        .font(.headline)
                        .foregroundStyle(scoreColor)
                        .privacySensitive()
                    
                }
                .widgetAccentable()
            }
            .containerBackground(.fill.quaternary, for: .widget)
            .widgetURL(URL(string: "practice://readinessDetail"))
            
            // iPhone widgets
        default:
            VStack {
                Text("Recovery")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Gauge(value: Double(entry.readinessScore), in: 0...100) {
                    Text("\(entry.readinessScore)%")
                }
                currentValueLabel: {
                    Image("kettlebell.flat")
                        .foregroundStyle(scoreColor.gradient)
                        .opacity(redactionReasons.contains(.privacy) ? 0.7 : 1.0)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(scoreColor.gradient)
            }
            .widgetAccentable()
            .containerBackground(.fill.quaternary, for: .widget)
            .widgetURL(URL(string: "practice://readinessDetail"))
        }
    }
    
    private var scoreColor: Color {
        guard !entry.isStale else { return .gray }
        switch entry.readinessScore {
        case 0..<40: return .red
        case 40..<70: return .yellow
        default: return .green
        }
    }
}

struct ReadinessWidget: Widget {
    let kind: String = "ReadinessComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessProvider()) { entry in
            ReadinessWidgetView(entry: entry)
        }
        .configurationDisplayName("Recovery")
        .description("Shows your current readiness score.")
        #if os(watchOS)
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
        
        #else
        .supportedFamilies([
            .systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular
        ])
        #endif
    }
}
