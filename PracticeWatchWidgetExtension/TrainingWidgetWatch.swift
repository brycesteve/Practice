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

struct SkillRingComplication: Widget {
    let kind = "SkillRing"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrainingTimelineProvider()) { entry in
            SkillRingView(entry: entry)
        }
        .configurationDisplayName("Skill Progress")
        .description("Progress ring for tonight's skill.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

struct SkillRingView: View {
    let entry: TrainingEntry
    @Environment(\.widgetFamily) private var family
    
    private var progressFraction: Double {
        guard entry.skillTotalLevels > 0 else { return 0 }
        return Double(entry.skillCurrentLevel) / Double(entry.skillTotalLevels)
    }
    
    var body: some View {
        mainContent
            .widgetURL(URL(string: "training://recovery"))
            .containerBackground(.background, for: .widget)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch family {
            
        case .accessoryCircular:
            ZStack {
                Gauge(value: progressFraction) {
                    EmptyView()
                } currentValueLabel: {
                    VStack(spacing: 0) {
                        Text("\(entry.skillCurrentLevel)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text("/ \(entry.skillTotalLevels)")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .gaugeStyle(.accessoryCircular)
                .tint(skillColor)
            }
            
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: skillIcon)
                        .foregroundStyle(skillColor)
                    Text(entry.skillName)
                        .font(.headline)
                        .minimumScaleFactor(0.7)
                }
                Text(entry.skillLevelName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                ProgressView(value: progressFraction)
                    .tint(skillColor)
            }
            
        case .accessoryCorner:
            Gauge(value: progressFraction) {
                Image(systemName: skillIcon)
            } currentValueLabel: {
                Text("L\(entry.skillCurrentLevel)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(skillColor)
            
        case .accessoryInline:
            Label("\(entry.skillName) L\(entry.skillCurrentLevel)/\(entry.skillTotalLevels)",
                  systemImage: skillIcon)
            
        default:
            EmptyView()
        }
    }
    
    private var skillColor: Color {
        Skill(rawValue: entry.skillName)?.color ?? .accentColor
    }
    
    private var skillIcon: String {
        Skill(rawValue: entry.skillName)?.icon ?? ""
    }
}

// MARK: - Shared timeline entry

struct TrainingEntry: TimelineEntry {
    let date: Date
    let readinessScore: Double?        // 0–100, nil if no data
    let readinessLabel: String
    let readinessColor: Color
    let skillName: String              // e.g. "Planche"
    let skillCurrentLevel: Int
    let skillTotalLevels: Int
    let skillLevelName: String         // e.g. "Tuck Planche"
    let todaySessionType: String?      // "Morning" / "Evening" / nil
    let bodyWeightKg: Double?
    
    static var placeholder: TrainingEntry {
        TrainingEntry(
            date: .now,
            readinessScore: 72,
            readinessLabel: "Good",
            readinessColor: .blue,
            skillName: "Planche",
            skillCurrentLevel: 2,
            skillTotalLevels: 6,
            skillLevelName: "Tuck Planche",
            todaySessionType: "Morning",
            bodyWeightKg: nil
        )
    }
    
    static var empty: TrainingEntry {
        TrainingEntry(
            date: .now,
            readinessScore: nil,
            readinessLabel: "–",
            readinessColor: .gray,
            skillName: "–",
            skillCurrentLevel: 1,
            skillTotalLevels: 6,
            skillLevelName: "–",
            todaySessionType: nil,
            bodyWeightKg: nil
        )
    }
}

// MARK: - Shared provider

struct TrainingTimelineProvider: TimelineProvider {
    typealias Entry = TrainingEntry
    
    func placeholder(in context: Context) -> TrainingEntry { .placeholder }
    
    func getSnapshot(in context: Context, completion: @escaping (TrainingEntry) -> Void) {
        Task {
            completion(await buildEntry())
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainingEntry>) -> Void) {
        Task {
            let base = await buildEntry()
            let cal  = Calendar.current
            
            // Hourly entries for the next 12 hours (complications have a
            // tighter budget than widgets — 12 entries is a reasonable range)
            var entries: [TrainingEntry] = []
            for hour in 0..<12 {
                let entryDate = cal.date(byAdding: .hour, value: hour, to: Date()) ?? Date()
                var entry = base
                entry = TrainingEntry(
                    date:              entryDate,
                    readinessScore:    base.readinessScore,
                    readinessLabel:    base.readinessLabel,
                    readinessColor:    base.readinessColor,
                    skillName:         base.skillName,
                    skillCurrentLevel: base.skillCurrentLevel,
                    skillTotalLevels:  base.skillTotalLevels,
                    skillLevelName:    base.skillLevelName,
                    todaySessionType:  base.todaySessionType,
                    bodyWeightKg:      base.bodyWeightKg
                )
                entries.append(entry)
            }
            
            let expiry = cal.date(byAdding: .hour, value: 12, to: Date()) ?? Date()
            completion(Timeline(entries: entries, policy: .after(expiry)))
        }
    }
    
    // MARK: Build entry from SwiftData + HealthKit
    
    @MainActor
    private func buildEntry() async -> TrainingEntry {
        // Load from local SwiftData store (widget extension uses same bundle container as iOS)

        guard let container = try? ModelContainer.makeWatch() else {
            return .empty
        }

        let context = container.mainContext
        
        // Fetch today's cached recovery score
        let today = Calendar.current.startOfDay(for: Date())
        let scoreDescriptor = FetchDescriptor<RecoveryScoreRecord>(
            predicate: #Predicate { $0.date >= today },
            sortBy: [SortDescriptor(\RecoveryScoreRecord.date, order: .reverse)]
        )
        var scoreRecord = try? context.fetch(scoreDescriptor).first
        
        if scoreRecord == nil {
            if let computed = try? await RecoveryEngine().computeScore() {
                let fresh = RecoveryScoreRecord(date: today, overallScore: computed.overall)
                fresh.hrv        = computed.metrics.hrv
                fresh.restingHR  = computed.metrics.restingHeartRate
                fresh.sleepHours = computed.metrics.sleepDuration
                context.insert(fresh)
                try? context.save()
                scoreRecord = fresh
            }
        }
        
        let score = scoreRecord?.overallScore
        let label = scoreRecord?.readinessLabel ?? "–"
        let color = readinessColor(score)
        
        // Fetch active skill progressions — pick the one for tonight's session
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let settings = try? context.fetch(settingsDescriptor).first
        let rotationDay = settings?.eveningRotationDay ?? 0
        let skillNames = Skill.activeSkills.map { $0.rawValue }
        let tonightSkill = skillNames[rotationDay % Skill.activeSkills.count]
        
        let progressionDescriptor = FetchDescriptor<SkillProgressionRecord>(
            predicate: #Predicate { $0.skillName == tonightSkill }
        )
        let progression = try? context.fetch(progressionDescriptor).first
        
        // Check if we've already worked out today
        let workoutDescriptor = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.startDate >= today },
            sortBy: [SortDescriptor(\WorkoutRecord.startDate, order: .reverse)]
        )
        let todayWorkout = try? context.fetch(workoutDescriptor).first
        let todaySession = todayWorkout?.sessionTypeRaw
        
        return TrainingEntry(
            date: .now,
            readinessScore: score,
            readinessLabel: label,
            readinessColor: color,
            skillName: progression?.skillName ?? tonightSkill,
            skillCurrentLevel: progression?.currentLevel ?? 1,
            skillTotalLevels: progression?.levels.count ?? 6,
            skillLevelName: progression?.currentSkillLevel?.name ?? "–",
            todaySessionType: todaySession,
            bodyWeightKg: nil
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
        SkillRingComplication()
    }
}


#Preview(as: .accessoryCircular) {
    ReadinessGaugeComplication()
} timeline: {
    TrainingEntry.placeholder
}

