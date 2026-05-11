// DashboardView.swift — iOS
// All data via @Query from SwiftData. No DataStore references.

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \WorkoutRecord.startDate, order: .reverse) private var allWorkouts: [WorkoutRecord]
    @Query private var progressionRecords: [SkillProgressionRecord]
    @Query private var settingsResults: [AppSettings]
    @Query private var restDays: [RestDayRecord]
    @Query(sort: \ConditioningScoreRecord.date, order: .reverse)
    private var conditioningHistory: [ConditioningScoreRecord]
    
    @State private var latestWeightKg: Double? = nil
    @State private var latestVO2Max: Double?   = nil
    @State private var recoveryScore: RecoveryScore? = nil
    @State private var showEveningPreview = false
    @State private var path = NavigationPath()
    
    private var settings: AppSettings { settingsResults.first ?? AppSettings() }
    
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }
    
    private var todayWorkouts: [WorkoutRecord] {
        allWorkouts.filter { Calendar.current.isDateInToday($0.startDate) }
    }
    
    private var last7DaysWorkouts: [WorkoutRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return allWorkouts.filter { $0.startDate >= cutoff }
    }
    
    private var thisMonthCount: Int {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        return allWorkouts.filter { $0.startDate >= start }.count
    }
    
    private func workoutCount(for type: SessionType) -> Int {
        allWorkouts.filter { $0.sessionTypeRaw == type.rawValue }.count
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting).font(.title2).foregroundStyle(.secondary)
                        Text("Keep moving.").font(.largeTitle.bold())
                    }
                    .padding(.horizontal)
                    
                    // Today
                    if todayWorkouts.isEmpty { noWorkoutCard } else { todayCard }
                    
                    // Recovery card
                    recoveryCard
                    
                    // Conditioning card
                    conditioningCard
                    
                    // Weekly streak
                    weeklyStreak
                    
                    // Tonight's skill
                    upcomingSkillCard
                    
                    // Main stats
                    statsGrid
                    
                    // Body stats
                    bodyStatsSection
                }
                .padding(.vertical)
                .task {
                    async let weight = HealthKitManager.shared.fetchLatestBodyMass()
                    async let vo2    = HealthKitManager.shared.fetchLatestVO2Max()
                    async let score  = RecoveryEngine().computeScore()
                    latestWeightKg = try? await weight
                    latestVO2Max   = try? await vo2
                    recoveryScore  = try? await score
                    latestVO2Max   = try? await HealthKitManager.shared.fetchLatestVO2Max()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .recovery:
                    RecoveryView()
                case .conditioning:
                    ConditioningView()
                case .bodyStats:
                    BodyStatsView()
                case .history:
                    HistoryView(path: $path)
                default:
                    EmptyView()
                }
            }
        }
        
    }
    
    // MARK: - Subviews
    
    private var noWorkoutCard: some View {
        CardView {
            HStack {
                Image(systemName: "figure.run").font(.largeTitle).foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("No session yet today").font(.headline)
                    Text("Open the Watch app to begin.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today").font(.headline).padding(.horizontal)
            ForEach(todayWorkouts) { workout in
                CardView {
                    HStack {
                        Text(workout.sessionType.emoji).font(.largeTitle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.sessionType.displayName).font(.headline)
                            Text("\(workout.durationMinutes) min")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            if let cal = workout.activeCalories {
                                Label("\(Int(cal)) kcal", systemImage: "flame.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            if let hr = workout.averageHeartRate {
                                Label("\(Int(hr)) bpm", systemImage: "heart.fill")
                                    .font(.caption).foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var weeklyStreak: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("This Week").font(.headline)
                    Spacer()
                    Text("\(last7DaysWorkouts.count) sessions · \(Int(consistencyPercent))% consistency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                GeometryReader { geo in
                    let days      = last7DaysSummary()
                    let colWidth  = geo.size.width / CGFloat(days.count)
                    let circleSize = min(colWidth * 0.65, 36.0)
                    
                    HStack(spacing: 0) {
                        ForEach(days, id: \.date) { day in
                            VStack(spacing: 5) {
                                ZStack {
                                    // Background circle
                                    Circle()
                                        .fill(day.state.fillColor)
                                        .frame(width: circleSize, height: circleSize)
                                    
                                    // Today ring
                                    if Calendar.current.isDateInToday(day.date) {
                                        Circle()
                                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
                                            .frame(width: circleSize + 4, height: circleSize + 4)
                                    }
                                    
                                    // Icon
                                    Image(systemName: day.state.icon)
                                        .font(.system(size: circleSize * 0.38, weight: .bold))
                                        .foregroundStyle(day.state.iconColor)
                                }
                                
                                Text(day.label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(
                                        Calendar.current.isDateInToday(day.date)
                                        ? Color.accentColor : Color.secondary
                                    )
                                    .fontWeight(Calendar.current.isDateInToday(day.date) ? .semibold : .regular)
                            }
                            .frame(width: colWidth)
                        }
                    }
                }
                .frame(height: 58)
                
                // Legend
                HStack(spacing: 14) {
                    legendItem(icon: "checkmark", color: .accentColor, label: "Trained")
                    legendItem(icon: "bed.double.fill", color: .gray, label: "Rest")
                    legendItem(icon: "minus", color: .gray.opacity(0.4), label: "Missed")
                }
            }
        }
    }
    
    @ViewBuilder
    private func legendItem(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9)).foregroundStyle(color)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    var upcomingSkillCard: some View {
        let skillNames = Skill.activeSkills.map { $0.rawValue }
        let tonight    = skillNames[settings.eveningRotationDay % Skill.activeSkills.count]
        let prog       = progressionRecords.first { $0.skillName == tonight }
        
        Button { showEveningPreview = true } label: {
            CardView {
                HStack {
                    Image(systemName: "moon.stars.fill").font(.title2).foregroundStyle(.indigo)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tonight's Focus").font(.caption).foregroundStyle(.secondary)
                        Text(tonight).font(.headline)
                        if let p = prog {
                            Text("Level \(p.currentLevel): \(p.currentSkillLevel?.name ?? "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEveningPreview) {
            EveningPreviewSheet(
                rotationDay: settings.eveningRotationDay,
                progressions: progressionRecords.map { $0.toSkillProgression() }
            )
        }
    }
    
    @ViewBuilder
    private var recoveryCard: some View {
        Button{
            path.append(Route.recovery)
        } label: {
            CardView {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        if let s = recoveryScore {
                            Circle()
                                .trim(from: 0, to: s.overall / 100)
                                .stroke(
                                    AngularGradient(
                                        colors: [.red, .orange, .yellow, .green],
                                        center: .center,
                                        startAngle: .degrees(-90),
                                        endAngle: .degrees(270)
                                    ),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                        }
                        if let s = recoveryScore {
                            Text("\(Int(s.overall))")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        } else {
                            ProgressView().scaleEffect(0.6)
                        }
                    }
                    .frame(width: 52, height: 52)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recovery & Readiness")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let s = recoveryScore {
                            Text("\(s.emoji) \(s.label) — \(Int(s.overall))/100")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let hrv = s.metrics.hrv {
                                Text(String(format: "HRV %.0f ms · RHR %.0f bpm",
                                            hrv,
                                            s.metrics.restingHeartRate ?? 0))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            }
                        } else {
                            Text("Loading…")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var conditioningCard: some View {
        let record = conditioningHistory.first
        Button {
            path.append(Route.conditioning)
        } label: {
            CardView {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        if let r = record {
                            Circle()
                                .trim(from: 0, to: r.overallScore / 100)
                                .stroke(
                                    AngularGradient(
                                        colors: [.red, .orange, .yellow, .green],
                                        center: .center,
                                        startAngle: .degrees(-90),
                                        endAngle: .degrees(270)
                                    ),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                        }
                        if let r = record {
                            Text("\(Int(r.overallScore))")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        } else {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 52, height: 52)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Conditioning")
                            .font(.headline).foregroundStyle(.primary)
                        if let r = record {
                            Text("\(r.trendEmoji) \(r.trendLabel)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            Text("Tap to compute")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stats").font(.headline).padding(.horizontal)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                Button {
                    path.append(Route.history)
                } label: {
                    StatCard(title: "This Month", value: "\(thisMonthCount)",        unit: "sessions", color: .blue)
                }
                .buttonStyle(.plain)
                Button {
                    path.append(Route.history)
                } label: {
                    StatCard(title: "Total",      value: "\(allWorkouts.count)",     unit: "workouts", color: .purple)
                }
                .buttonStyle(.plain)
                Button {
                    path.append(Route.history)
                } label: {
                    StatCard(title: "Morning",    value: "\(workoutCount(for: .morning))", unit: "sessions", color: .orange)
                }
                .buttonStyle(.plain)
                Button {
                    path.append(Route.history)
                } label: {
                    StatCard(title: "Evening",    value: "\(workoutCount(for: .evening))", unit: "sessions", color: .indigo)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var bodyStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Body Stats").font(.headline).padding(.horizontal)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                
                Button {
                    path.append(Route.bodyStats)
                } label: {
                    if let kg = latestWeightKg {
                        StatCard(title: "Body Weight", value: String(format: "%.1f", kg), unit: "kg", color: .teal)
                    } else {
                        StatCard(title: "Body Weight", value: "–", unit: "Log via Health", color: .teal)
                    }
                }
                .buttonStyle(.plain)
                
                Button {
                    path.append(Route.bodyStats)
                } label: {
                    if let vo2 = latestVO2Max {
                        StatCard(title: "VO₂ Max", value: String(format: "%.1f", vo2), unit: "mL/kg/min", color: .green)
                    } else {
                        StatCard(title: "VO₂ Max", value: "–", unit: "Needs outdoor run", color: .green)
                    }
                }
                .buttonStyle(.plain)
                
                
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helpers
    
    private enum DayState {
        case trained, rest, missed, future
        
        var fillColor: Color {
            switch self {
            case .trained: return .accentColor
            case .rest:    return Color.gray.opacity(0.35)
            case .missed:  return Color.gray.opacity(0.12)
            case .future:  return Color.clear
            }
        }
        var icon: String {
            switch self {
            case .trained: return "checkmark"
            case .rest:    return "bed.double.fill"
            case .missed:  return "minus"
            case .future:  return ""
            }
        }
        var iconColor: Color {
            switch self {
            case .trained: return .white
            case .rest:    return .secondary
            case .missed:  return Color.gray.opacity(0.3)
            case .future:  return .clear
            }
        }
    }
    
    private struct DaySummary { let date: Date; let label: String; let state: DayState }
    
    private func last7DaysSummary() -> [DaySummary] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let date    = cal.date(byAdding: .day, value: -offset, to: today)!
            let isFuture = date > today
            let worked  = allWorkouts.contains { cal.isDate($0.startDate, inSameDayAs: date) }
            let rested  = restDays.contains    { cal.isDate($0.date,      inSameDayAs: date) }
            let label   = cal.shortWeekdaySymbols[cal.component(.weekday, from: date) - 1]
            let state: DayState = isFuture ? .future : worked ? .trained : rested ? .rest : .missed
            return DaySummary(date: date, label: label, state: state)
        }
    }
    
    private var consistencyPercent: Double {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -27, to: today)!
        var credited = 0
        var elapsed  = 0   // only count days up to and including today
        for offset in 0..<28 {
            let day = cal.date(byAdding: .day, value: offset, to: start)!
            guard day <= today else { break }
            elapsed += 1
            let worked = allWorkouts.contains { cal.isDate($0.startDate, inSameDayAs: day) }
            let rested = restDays.contains    { cal.isDate($0.date,      inSameDayAs: day) }
            if worked || rested { credited += 1 }
        }
        // Target is 5/7 of elapsed days, minimum 1 to avoid division by zero
        let target = max(1, Int((Double(elapsed) * 5.0 / 7.0).rounded()))
        return min(Double(credited) / Double(target), 1.0) * 100
    }
}

// MARK: - Reusable views (shared with other iOS views)

struct CardView<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title.bold()).foregroundStyle(color)
            Text(unit).font(.caption2).foregroundStyle(.tertiary)
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
