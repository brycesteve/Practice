import SwiftUI
import SwiftData
import Charts

struct BodyStatsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurementRecord.date, order: .reverse) private var measurements: [BodyMeasurementRecord]
    @Query(sort: \WaistMeasurementRecord.date, order: .reverse) private var waists: [WaistMeasurementRecord]
    @State private var healthWeight: [BodyTrendPoint] = []
    @State private var vo2: [BodyTrendPoint] = []
    @State private var profile = BodyProfileSnapshot()
    @State private var isLoading = true
    @State private var healthReadFailed = false
    // Injection is for previews and the isolated simulator sample screen only.
    var sample: BodyStatsSampleInput?

    private var snapshot: BodyStatsSnapshot {
        BodyStatsSnapshot(measurements: measurements, waists: waists,
            healthWeight: sample?.weight ?? healthWeight, vo2: sample?.vo2 ?? vo2,
            currentProfile: sample?.profile ?? profile)
    }

    var body: some View {
        let data = snapshot
        let secondaryMetrics = [BodyMetric.leanMass, .skeletalMuscle, .waist, .bmi].filter {
            $0 == .waist || !(data.series[$0] ?? []).isEmpty
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if sample != nil {
                    Label("Sample data · not saved to Health", systemImage: "eye")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Your body, over time")
                    .font(.title2.bold())
                Text("Recent trends and your latest available readings.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.top, -12)
                if isLoading && sample == nil {
                    ProgressView("Updating Apple Health…").font(.caption)
                }
                if healthReadFailed {
                    Text("Apple Health couldn’t be refreshed. Your Practice measurements are still available. Pull down to retry.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach([BodyMetric.weight, .bodyFat, .vo2]) { metric in
                    NavigationLink {
                        BodyMetricHistoryView(metric: metric, snapshot: data, measurements: measurements)
                    } label: {
                        BodyTrendCard(metric: metric, points: data.series[metric] ?? [])
                    }
                    .buttonStyle(.plain)
                }
                BodyStatsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("More body measures").font(.headline)
                        ForEach(secondaryMetrics) { metric in
                            NavigationLink {
                                BodyMetricHistoryView(metric: metric, snapshot: data, measurements: measurements)
                            } label: {
                                BodySummaryRow(metric: metric, latest: data.series[metric]?.last,
                                    waistRatio: metric == .waist ? data.waistRatio : nil)
                            }
                            .buttonStyle(.plain)
                            if metric != secondaryMetrics.last { Divider() }
                        }
                        if secondaryMetrics.count == 1 {
                            Text("Body-composition summaries appear as measurements become available.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                NavigationLink {
                    BodyCompositionHistoryView()
                } label: {
                    BodyStatsCard {
                        HStack {
                            Label("Measurement history", systemImage: "clock")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }.font(.subheadline)
                    }
                }.buttonStyle(.plain)
                Text("Start a scale measurement from Body measurement on Apple Watch. Profile and scale configuration are in Settings.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Body Stats")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadData() }
        .refreshable { await loadData() }
        .task(id: waists.count) { await loadProfile() }
    }

    private func loadProfile() async {
        guard sample == nil else { return }
        let configuration = (try? BodyMeasurementStore.configuration(in: context)) ?? .init()
        profile = await BodyMeasurementStore.resolveProfile(configuration: configuration, at: .now, in: context)
    }

    private func loadData() async {
        guard sample == nil else { isLoading = false; return }
        isLoading = true
        healthReadFailed = false
        // Keep this UI's historical window explicit; existing HealthKit behaviour is unchanged.
        async let weight = HealthKitManager.shared.fetchBodyMassHistory(days: 365)
        async let fitness = HealthKitManager.shared.fetchVO2MaxHistory(days: 365)
        do {
            let values = try await weight
            healthWeight = values.enumerated().map {
                .init(id: "health-weight-\($0.offset)-\($0.element.date.timeIntervalSince1970)",
                    date: $0.element.date, value: $0.element.kg, source: "Apple Health")
            }
        } catch { healthReadFailed = true }
        do {
            let values = try await fitness
            vo2 = values.enumerated().map {
                .init(id: "vo2-\($0.offset)-\($0.element.date.timeIntervalSince1970)",
                    date: $0.element.date, value: $0.element.value, source: "Apple Health")
            }
        } catch { healthReadFailed = true }
        await loadProfile()
        isLoading = false
    }
}

/// Same material, corner radius and padding as Practice's Recovery / Conditioning cards.
struct BodyStatsCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct BodyTrendCard: View {
    let metric: BodyMetric
    let points: [BodyTrendPoint]
    private var recent: [BodyTrendPoint] { BodyTrendRange.quarter.filter(points) }

    var body: some View {
        BodyStatsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(metric.title, systemImage: metric.icon).font(.headline)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                if let latest = points.last {
                    Text(metric.formatted(latest.value))
                        .font(.largeTitle.bold()).monospacedDigit()
                        .foregroundStyle(.primary)
                    Text(latest.date, format: .dateTime.day().month(.abbreviated).year())
                        .font(.caption).foregroundStyle(.secondary)
                    if let change = BodyTrend.change(recent, metric: metric) {
                        Text(change).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    }
                    if !recent.isEmpty {
                        BodyTrendChart(metric: metric, points: recent, compact: true)
                            .accessibilityHidden(true)
                        Text(recent.count == 1 ? "One recent reading · more readings build a trend" :
                            metric.smoothsTrend ? "Past 3 months · 7-day mean" : "Past 3 months")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No readings in the past 3 months. Open for history.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Text("No readings yet").font(.title3.weight(.semibold))
                    Text(metric.emptyMessage).font(.footnote).foregroundStyle(.secondary)
                }
                if metric == .bodyFat && !points.isEmpty {
                    Text("An estimate · focus on sustained changes")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if metric == .vo2 && !points.isEmpty {
                    Text("Cardio fitness estimate · Apple Health")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens history and details")
    }

}

private struct BodySummaryRow: View {
    let metric: BodyMetric
    let latest: BodyTrendPoint?
    var waistRatio: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.title).font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            if let latest {
                Text(metric.formatted(latest.value)).font(.title3.weight(.semibold)).monospacedDigit()
                Text("\(metric.isEstimated ? "Estimated · " : metric == .bmi ? "Calculated · " : "")\(latest.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
                if let waistRatio {
                    Text("Waist / height \(waistRatio.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text(metric == .waist ? "Record a waist measurement" : "Not enough measurement data")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct BodyTrendChart: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let metric: BodyMetric
    let points: [BodyTrendPoint]
    var compact = false

    private var plotted: [BodyTrendPoint] {
        metric.smoothsTrend ? BodyTrend.sevenDayMeans(points) : BodyTrend.dailyMeans(points)
    }
    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let padding = max(metric.minimumPadding, (high - low) * 0.2)
        return max(0, low - padding)...(high + padding)
    }
    private var xDomain: ClosedRange<Date> {
        let first = plotted.first?.date ?? .now
        let last = plotted.last?.date ?? first
        let padding = max(86_400, last.timeIntervalSince(first) * 0.03)
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }
    private var axisDateFormat: Date.FormatStyle {
        xDomain.upperBound.timeIntervalSince(xDomain.lowerBound) > 330 * 86_400
            ? .dateTime.month(.abbreviated).year(.twoDigits)
            : .dateTime.month(.abbreviated).day()
    }
    private var segments: [String: Int] {
        var result: [String: Int] = [:]
        var segment = 0
        var previous: Date?
        for point in plotted {
            if let previous, point.date.timeIntervalSince(previous) > 14 * 86_400 { segment += 1 }
            result[point.id] = segment
            previous = point.date
        }
        return result
    }

    var body: some View {
        let trend = plotted
        let groups = segments
        Chart {
            if !compact && metric.smoothsTrend {
                ForEach(points) { point in
                    PointMark(x: .value("Date", point.date), y: .value(metric.unit, point.value))
                        .foregroundStyle(Color.secondary.opacity(0.35)).symbolSize(12)
                        .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue(metric.formatted(point.value, detail: true))
                }
            }
            ForEach(trend) { point in
                LineMark(x: .value("Date", point.date), y: .value(metric.unit, point.value),
                    series: .value("Continuous observations", groups[point.id] ?? 0))
                    .foregroundStyle(Color.accentColor).lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("Date", point.date), y: .value(metric.unit, point.value))
                    .foregroundStyle(Color.accentColor).symbolSize(trend.count < 8 ? 24 : 8)
                    .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue(metric.formatted(point.value, detail: true))
            }
        }
        .frame(height: compact ? (dynamicTypeSize.isAccessibilitySize ? 170 : 110)
            : (dynamicTypeSize.isAccessibilitySize ? 300 : 220))
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisValueLabel(format: axisDateFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel()
            }
        }
        .chartLegend(.hidden)
        .accessibilityLabel("\(metric.title) history")
    }
}

struct BodyMetricHistoryView: View {
    let metric: BodyMetric
    let snapshot: BodyStatsSnapshot
    let measurements: [BodyMeasurementRecord]
    @State private var range = BodyTrendRange.quarter
    @State private var showWaist = false
    @State private var refreshedWaistSnapshot: BodyStatsSnapshot?
    @Environment(\.modelContext) private var context
    @Query(sort: \WaistMeasurementRecord.date, order: .reverse) private var waists: [WaistMeasurementRecord]
    @Environment(\.bodyStatsSampleMode) private var sampleMode

    private var currentSnapshot: BodyStatsSnapshot { refreshedWaistSnapshot ?? snapshot }
    private var points: [BodyTrendPoint] { currentSnapshot.series[metric] ?? [] }
    private var visible: [BodyTrendPoint] { range.filter(points) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BodyStatsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        if let latest = points.last {
                            Text("Latest available").font(.caption).foregroundStyle(.secondary)
                            Text(metric.formatted(latest.value)).font(.largeTitle.bold()).monospacedDigit()
                            Text(latest.date, format: .dateTime.day().month(.abbreviated).year())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Picker("History range", selection: $range) {
                            ForEach(BodyTrendRange.allCases) { value in Text(value.rawValue).tag(value) }
                        }.pickerStyle(.menu)
                        if visible.isEmpty {
                            ContentUnavailableView(points.isEmpty ? "No readings yet" : "No readings in this range",
                                systemImage: metric.icon,
                                description: Text(points.isEmpty ? metric.emptyMessage : "Choose All available to see older readings."))
                        } else {
                            if let change = BodyTrend.change(visible, metric: metric) {
                                Text(change).font(.headline)
                            }
                            BodyTrendChart(metric: metric, points: visible)
                            Text(visible.count == 1 ? "One reading so far. A trend needs readings on different days." :
                                metric.smoothsTrend ? "Dots show readings. The line shows a 7-day mean of observed days; gaps over two weeks remain unconnected." :
                                "Daily means. Gaps over two weeks remain unconnected.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let latest = points.last, let reference = currentSnapshot.references[metric] {
                    BodyStatsCard {
                        BodyReferenceGauge(title: metric == .bodyFat ? "Estimated body fat (%)" : "BMI",
                            value: latest.value, range: reference,
                            domain: metric == .bodyFat ? 0...60 : 10...45, digits: metric.digits,
                            usesBMILabels: metric == .bmi)
                    }
                }
                if metric == .waist {
                    BodyStatsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            if let ratio = currentSnapshot.waistRatio {
                                if let reference = currentSnapshot.waistRange {
                                    BodyReferenceGauge(title: "Waist / height", value: ratio, range: reference,
                                        domain: 0.2...0.8, digits: 2)
                                } else {
                                    Text("Waist / height \(ratio.formatted(.number.precision(.fractionLength(2))))")
                                        .font(.headline)
                                }
                                Text("Uses the latest waist and available height. NICE ranges apply to adults with BMI below 35.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Button("Record waist circumference", systemImage: "plus") { showWaist = true }
                                .disabled(sampleMode)
                        }
                    }
                }
                Text(metric.explanation).font(.subheadline).foregroundStyle(.secondary)
                if metric.isEstimated {
                    Text("This foot-to-foot scale has not been validated against the original whole-body resistance method. Estimates and reference ranges are context, not a diagnosis.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if metric == .bodyFat {
                    Text("Gallagher reference bands use the age and calculation model of the latest estimate (ages 20–79).")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if metric == .weight || metric == .vo2 {
                    Text("Apple Health history covers the past year. All available also includes older Practice scale readings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !visible.isEmpty {
                    BodyStatsCard {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            Text("Readings").font(.headline)
                            ForEach(visible.reversed()) { point in
                                if let id = point.recordID, let record = measurements.first(where: { $0.id == id }) {
                                    NavigationLink { BodyMeasurementDetailView(record: record) } label: {
                                        reading(point, opensDetail: true)
                                    }.buttonStyle(.plain)
                                } else { reading(point, opensDetail: false) }
                                Divider()
                            }
                        }
                    }
                }
            }.padding()
        }
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWaist) { NavigationStack { WaistEntryView() } }
        .task(id: waists.count) {
            guard metric == .waist, !sampleMode else { return }
            let configuration = (try? BodyMeasurementStore.configuration(in: context)) ?? .init()
            let profile = await BodyMeasurementStore.resolveProfile(configuration: configuration, at: .now, in: context)
            refreshedWaistSnapshot = BodyStatsSnapshot(measurements: measurements, waists: waists,
                healthWeight: [], vo2: [], currentProfile: profile)
        }
    }

    private func reading(_ point: BodyTrendPoint, opensDetail: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(metric.formatted(point.value, detail: true)).font(.headline)
                Spacer()
                if opensDetail { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
            }
            Text(point.date, format: .dateTime.day().month().year().hour().minute())
                .font(.caption).foregroundStyle(.secondary)
            Text(point.source).font(.caption).foregroundStyle(.secondary)
            if metric == .waist, let error = waists.first(where: { $0.id.uuidString == point.id })?.healthExportError {
                Text("Health export pending: \(error)").font(.caption).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
}

struct BodyStatsSampleInput {
    var weight: [BodyTrendPoint] = []
    var vo2: [BodyTrendPoint] = []
    var profile = BodyProfileSnapshot()
}

private struct BodyStatsSampleModeKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var bodyStatsSampleMode: Bool {
        get { self[BodyStatsSampleModeKey.self] }
        set { self[BodyStatsSampleModeKey.self] = newValue }
    }
}
