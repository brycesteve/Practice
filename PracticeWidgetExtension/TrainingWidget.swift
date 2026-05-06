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
    let readinessLabel: String
    let trainedToday: Bool
    let restDayToday: Bool
    let consistencyPercent: Double
    let trainedLast7: Int
    let tonightSkill: String
    
    static var placeholder: TrainingWidgetEntry {
        TrainingWidgetEntry(date: .now, readinessScore: 74, readinessLabel: "Good",
                            trainedToday: false, restDayToday: false,
                            consistencyPercent: 80, trainedLast7: 4, tonightSkill: "Handstand")
    }
}

// MARK: - Provider

struct TrainingWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrainingWidgetEntry { .placeholder }
    
    func getSnapshot(in context: Context, completion: @escaping (TrainingWidgetEntry) -> Void) {
        Task { completion(await buildEntry()) }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TrainingWidgetEntry>) -> Void) {
        Task {
            let base  = await buildEntry()
            let cal   = Calendar.current
            
            // Generate one entry per hour for the next 24 hours.
            // Each entry uses the same cached score — WidgetKit picks the
            // entry whose date is closest to the current time.
            // When BackgroundTaskManager computes a new score it calls
            // reloadAllTimelines(), which invalidates this schedule immediately.
            var entries: [TrainingWidgetEntry] = []
            for hour in 0..<24 {
                let entryDate = cal.date(byAdding: .hour, value: hour, to: Date()) ?? Date()
                let entry = TrainingWidgetEntry(
                    date:                entryDate,
                    readinessScore:      base.readinessScore,
                    readinessLabel:      base.readinessLabel,
                    trainedToday:        base.trainedToday,
                    restDayToday:        base.restDayToday,
                    consistencyPercent:  base.consistencyPercent,
                    trainedLast7:        base.trainedLast7,
                    tonightSkill:        base.tonightSkill
                )
                entries.append(entry)
            }
            
            // After 24 hours rebuild from scratch
            let expiry = cal.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
            completion(Timeline(entries: entries, policy: .after(expiry)))
        }
    }
    
    @MainActor
    private func buildEntry() async -> TrainingWidgetEntry {
        guard let container = try? ModelContainer.makeiOS() else { return .placeholder }
        let context = container.mainContext
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        // Recovery score
        let scoreDesc = FetchDescriptor<RecoveryScoreRecord>(
            predicate: #Predicate { $0.date >= today },
            sortBy: [SortDescriptor(\RecoveryScoreRecord.date, order: .reverse)]
        )
        var scoreRecord = try? context.fetch(scoreDesc).first
        
        // Fallback: if no cached score exists for today, compute one now.
        // This runs on first launch before background delivery has fired.
        if scoreRecord == nil {
            if let computed = try? await RecoveryEngine().computeScore() {
                let fresh = RecoveryScoreRecord(date: today, overallScore: computed.overall)
                fresh.hrvScore             = computed.hrvContribution
                fresh.restingHRScore       = computed.restingHRContribution
                fresh.sleepDurationScore   = computed.sleepDurationContribution
                fresh.sleepQualityScore    = computed.sleepQualityContribution
                fresh.respiratoryRateScore = computed.respiratoryContribution
                fresh.trainingLoadScore    = computed.trainingLoadContribution
                fresh.hrv                  = computed.metrics.hrv
                fresh.restingHR            = computed.metrics.restingHeartRate
                fresh.sleepHours           = computed.metrics.sleepDuration
                fresh.respiratoryRate      = computed.metrics.respiratoryRate
                fresh.activeEnergyYesterday = computed.metrics.activeEnergyYesterday
                context.insert(fresh)
                try? context.save()
                scoreRecord = fresh
            }
        }
        
        // Today's workout / rest day
        let workoutDesc = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.startDate >= today }
        )
        let trainedToday = (try? context.fetchCount(workoutDesc)) ?? 0 > 0
        
        let restDesc = FetchDescriptor<RestDayRecord>(
            predicate: #Predicate { $0.date >= today }
        )
        let restDayToday = (try? context.fetchCount(restDesc)) ?? 0 > 0
        
        // Last 7 days
        let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: today)!
        let recentDesc = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.startDate >= sevenDaysAgo }
        )
        let trainedLast7 = (try? context.fetchCount(recentDesc)) ?? 0
        
        // Consistency (last 28 days, 5/7 target)
        let start28 = cal.date(byAdding: .day, value: -27, to: today)!
        var credited = 0; var elapsed = 0
        for offset in 0..<28 {
            let day = cal.date(byAdding: .day, value: offset, to: start28)!
            let dayEnd = cal.date(byAdding: .day, value: 1, to: day)!
            guard day <= today else { break }
            elapsed += 1
            let wDesc = FetchDescriptor<WorkoutRecord>(predicate: #Predicate { $0.startDate >= day && $0.startDate < dayEnd })
            let rDesc = FetchDescriptor<RestDayRecord>(predicate: #Predicate { $0.date >= day && $0.date < dayEnd })
            if ((try? context.fetchCount(wDesc)) ?? 0) > 0 ||
                ((try? context.fetchCount(rDesc)) ?? 0) > 0 { credited += 1 }
        }
        let target = max(1, Int((Double(elapsed) * 5.0 / 7.0).rounded()))
        let consistency = min(Double(credited) / Double(target), 1.0) * 100
        
        // Tonight's skill
        let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first
        let skillNames = Skill.activeSkills.map { $0.rawValue }
        let tonight = skillNames[(settings?.eveningRotationDay ?? 0) % Skill.activeSkills.count]
        
        return TrainingWidgetEntry(
            date: .now,
            readinessScore: scoreRecord?.overallScore,
            readinessLabel: scoreRecord?.readinessLabel ?? "–",
            trainedToday: trainedToday,
            restDayToday: restDayToday,
            consistencyPercent: consistency,
            trainedLast7: trainedLast7,
            tonightSkill: tonight
        )
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

@main
struct TrainingWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrainingWidget()
    }
}

#Preview(as: .accessoryCircular) {
    TrainingWidget()
} timeline: {
    TrainingWidgetEntry.placeholder
}

