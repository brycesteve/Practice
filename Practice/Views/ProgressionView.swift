// ProgressionView.swift — iOS
// @Query replaces DataStore for skill progressions and session history.

import SwiftUI
import SwiftData
import Charts

struct ProgressionView: View {
    @Query private var progressionRecords: [SkillProgressionRecord]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(progressionRecords) { record in
                    NavigationLink(value: record) {
                        SkillRowView(record: record)
                    }
                }
            }
            .navigationTitle("Skills")
            .navigationDestination(for: SkillProgressionRecord.self) { record in
                SkillDetailView(record: record)
            }
        }
    }
}

// MARK: - Row

struct SkillRowView: View {
    let record: SkillProgressionRecord
    @Query private var allHistory: [SkillSessionRecord]
    
    private var history: [SkillSessionEntry] {
        allHistory
            .filter { $0.skillProgressionID == record.id }
            .map    { $0.toSkillSessionEntry() }
            .sorted { $0.date < $1.date }
    }
    
    private var recommendation: ProgressionRecommendation {
        ProgressionEngine().evaluate(progression: record.toSkillProgression(), history: history)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.skillName).font(.headline)
                Spacer()
                recommendationBadge
            }
            if let level = record.currentSkillLevel {
                Text("Level \(record.currentLevel): \(level.name)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(record.currentLevel), total: Double(record.levels.count))
                .tint(skillColor(record.skillName))
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var recommendationBadge: some View {
        switch recommendation {
        case .advance:
            Label("Advance!", systemImage: "arrow.up.circle.fill")
                .font(.caption.bold()).foregroundStyle(.green)
        case .regress:
            Label("Step back", systemImage: "arrow.down.circle.fill")
                .font(.caption).foregroundStyle(.orange)
        case .maintain:
            EmptyView()
        }
    }
    
    private func skillColor(_ name: String) -> Color {
        Skill(rawValue: name)?.color ?? .accentColor
    }
}

// MARK: - Detail

struct SkillDetailView: View {
    let record: SkillProgressionRecord
    @Environment(\.modelContext) private var modelContext
    @Query private var allHistory: [SkillSessionRecord]
    
    private var history: [SkillSessionEntry] {
        allHistory
            .filter { $0.skillProgressionID == record.id }
            .map    { $0.toSkillSessionEntry() }
            .sorted { $0.date < $1.date }
    }
    
    private var progression: SkillProgression { record.toSkillProgression() }
    
    private var recommendation: ProgressionRecommendation {
        ProgressionEngine().evaluate(progression: progression, history: history)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                recommendationBanner
                
                if let level = record.currentSkillLevel {
                    currentLevelCard(level: level)
                }
                if let next = record.nextSkillLevel {
                    nextLevelCard(level: next)
                }
                
                // Manual advance/regress controls
                progressionControls
                
                levelLadder
                
                if !history.isEmpty { historyChart }
            }
            .padding()
        }
        .navigationTitle(record.skillName)
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: Recommendation banner
    
    @ViewBuilder
    private var recommendationBanner: some View {
        let (icon, text, color): (String, String, Color) = switch recommendation {
        case .advance(_, let r): ("arrow.up.circle.fill",   r, .green)
        case .maintain(let r):   ("chart.bar.fill",          r, .blue)
        case .regress(_, let r): ("arrow.down.circle.fill", r, .orange)
        }
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(text).font(.subheadline)
        }
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.3)))
    }
    
    // MARK: Current level
    
    private func currentLevelCard(level: SkillLevel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Current — Level \(record.currentLevel)", systemImage: "star.fill")
                .font(.caption.bold()).foregroundStyle(.yellow)
            Text(level.name).font(.title3.bold())
            Text(level.details).font(.body).foregroundStyle(.secondary)
            if let d = level.targetDurationSeconds {
                Label("Target: \(d)s hold", systemImage: "timer").font(.caption).foregroundStyle(.blue)
            }
            if let r = level.targetReps {
                Label("Target: \(r) reps", systemImage: "repeat").font(.caption).foregroundStyle(.blue)
            }
            Label("Advance after \(level.advanceCriteria.consecutiveSessions) qualifying sessions",
                  systemImage: "flag.checkered")
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: Next level
    
    private func nextLevelCard(level: SkillLevel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Next — Level \(level.level)", systemImage: "lock.open.fill")
                .font(.caption.bold()).foregroundStyle(.secondary)
            Text(level.name).font(.headline)
            Text(level.details).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: Manual controls
    
    private var progressionControls: some View {
        HStack(spacing: 12) {
            Button {
                record.currentLevel = max(1, record.currentLevel - 1)
                try? modelContext.save()
            } label: {
                Label("Step Back", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(.orange)
            .disabled(record.currentLevel <= 1)
            
            Button {
                record.currentLevel = min(record.levels.count, record.currentLevel + 1)
                try? modelContext.save()
            } label: {
                Label("Advance", systemImage: "arrow.up.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.green)
            .disabled(record.currentLevel >= record.levels.count)
        }
    }
    
    // MARK: Level ladder with achievement timeline
    
    private var levelLadder: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progression Path").font(.headline)
            ForEach(record.levels, id: \.id) { (level: SkillLevel) in
                HStack(alignment: .top, spacing: 12) {
                    // Timeline column
                    VStack(spacing: 0) {
                        Circle()
                            .fill(level.level <= record.currentLevel ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if level.level < record.currentLevel {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                } else {
                                    Text("\(level.level)")
                                        .font(.caption.bold())
                                        .foregroundStyle(level.level == record.currentLevel ? .white : .secondary)
                                }
                            }
                        if level.level < record.levels.count {
                            Rectangle()
                                .fill(level.level < record.currentLevel ? Color.accentColor : Color.gray.opacity(0.2))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                                .padding(.vertical, 2)
                        }
                    }
                    
                    // Content column
                    VStack(alignment: .leading, spacing: 3) {
                        Text(level.name)
                            .font(.subheadline)
                            .fontWeight(level.level == record.currentLevel ? .bold : .regular)
                        
                        if let achieved = level.dateAchieved {
                            Label(achieved.formatted(date: .abbreviated, time: .omitted),
                                  systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        } else if level.level < record.currentLevel {
                            Text("Completed")
                                .font(.caption2).foregroundStyle(.secondary)
                        } else if level.level == record.currentLevel {
                            Text("Current level")
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                        }
                        
                        if let d = level.targetDurationSeconds {
                            Text("Target: \(d)s").font(.caption2).foregroundStyle(.secondary)
                        }
                        if let r = level.targetReps {
                            Text("Target: \(r) reps").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
    }
    
    // MARK: History chart
    
    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session History").font(.headline)
            let recent = Array(history.suffix(12))
            let isTimed = recent.first?.sets.first?.durationSeconds != nil
            
            Chart {
                ForEach(recent) { entry in
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value(isTimed ? "Duration (s)" : "Total Reps",
                                  isTimed ? entry.totalDuration : entry.totalReps)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
            }
            .frame(height: 140)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisGridLine(); AxisTick()
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            
            Chart {
                ForEach(recent) { entry in
                    LineMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Avg Difficulty", entry.averageDifficulty)
                    )
                    .symbol(.circle)
                    .foregroundStyle(Color.orange.gradient)
                }
            }
            .frame(height: 90)
            .chartYScale(domain: 1...5)
            .chartXAxis(.hidden)
            
            Text("Orange = avg difficulty (1 easy → 5 max)")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
