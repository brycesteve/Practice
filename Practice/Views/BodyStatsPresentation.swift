import Foundation

/// Presentation-only projections. Raw measurements, stored profiles and calculation versions are unchanged.
struct BodyTrendPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
    var recordID: UUID?
    var source = "Practice scale"
}

enum BodyMetric: String, CaseIterable, Identifiable {
    case weight, bodyFat, vo2, leanMass, skeletalMuscle, waist, bmi
    var id: Self { self }

    var title: String {
        switch self {
        case .weight: "Weight"
        case .bodyFat: "Estimated body fat"
        case .vo2: "VO₂ max"
        case .leanMass: "Fat-free mass"
        case .skeletalMuscle: "Skeletal muscle"
        case .waist: "Waist"
        case .bmi: "BMI"
        }
    }
    var unit: String {
        switch self {
        case .weight, .leanMass, .skeletalMuscle: "kg"
        case .bodyFat: "%"
        case .vo2: "mL/kg/min"
        case .waist: "cm"
        case .bmi: "kg/m²"
        }
    }
    var icon: String {
        switch self {
        case .weight: "scalemass"
        case .bodyFat: "waveform.path"
        case .vo2: "lungs"
        case .leanMass: "figure.stand"
        case .skeletalMuscle: "figure.strengthtraining.traditional"
        case .waist: "measuringtape"
        case .bmi: "function"
        }
    }
    var isEstimated: Bool { [.bodyFat, .leanMass, .skeletalMuscle].contains(self) }
    var smoothsTrend: Bool { [.weight, .bodyFat, .leanMass, .skeletalMuscle].contains(self) }
    var digits: Int { self == .bodyFat ? 0 : 1 }
    var minimumPadding: Double { self == .bmi ? 1 : 2 }
    var emptyMessage: String {
        switch self {
        case .weight: "Measure on your Watch or add weight in Apple Health."
        case .bodyFat, .leanMass, .skeletalMuscle: "A scale reading with impedance and a complete body profile is needed."
        case .vo2: "Outdoor walks and runs with Apple Watch can provide cardio fitness estimates."
        case .waist: "Record a waist measurement below, or allow access to waist circumference in Apple Health."
        case .bmi: "A weight measurement and height are needed. Body profile settings are in Settings."
        }
    }
    var explanation: String {
        switch self {
        case .weight: "Measured weight from Practice and Apple Health. Practice readings take precedence over their matching Health copies."
        case .bodyFat: "BIA is an estimate, not a direct measurement. Hydration and electrode contact can change a reading. Look for a sustained pattern over several weeks."
        case .vo2: "Apple Health’s estimate of aerobic fitness, commonly recorded during outdoor walks and runs with Apple Watch."
        case .leanMass: "Estimated fat-free mass includes water, bone, organs and muscle. It is not a measure of muscle alone."
        case .skeletalMuscle: "Estimated skeletal muscle mass uses the Janssen impedance equation. It is distinct from total fat-free mass."
        case .waist: "Measured waist circumference provides context independently of scale estimates. Waist-to-height ratio uses the height available with the measurement."
        case .bmi: "BMI is calculated from weight and height. NICE adult ranges are general references; interpretation varies with ethnicity, age and muscle mass."
        }
    }
    func formatted(_ value: Double, detail: Bool = false) -> String {
        let precision = detail ? 1 : digits
        let number = value.formatted(.number.precision(.fractionLength(precision)))
        return "\(isEstimated ? "≈" : "")\(number)\(self == .bodyFat ? "%" : " " + unit)"
    }
}

enum BodyTrendRange: String, CaseIterable, Identifiable {
    case month = "1 month", quarter = "3 months", halfYear = "6 months", year = "1 year", all = "All available"
    var id: Self { self }
    var months: Int? {
        switch self {
        case .month: 1
        case .quarter: 3
        case .halfYear: 6
        case .year: 12
        case .all: nil
        }
    }
    func filter(_ points: [BodyTrendPoint], now: Date = .now) -> [BodyTrendPoint] {
        guard let months, let start = Calendar.current.date(byAdding: .month, value: -months, to: now) else { return points }
        return points.filter { $0.date >= start && $0.date <= now }
    }
}

enum BodyTrend {
    /// Collapse only matching exported observations, never all readings on the same day.
    static func mergingWeight(scale: [BodyTrendPoint], health: [BodyTrendPoint]) -> [BodyTrendPoint] {
        let remaining = health.filter { healthPoint in
            !scale.contains {
                abs($0.date.timeIntervalSince(healthPoint.date)) < 1
                    && abs($0.value - healthPoint.value) < 0.001
            }
        }
        return (scale + remaining).filter { $0.value.isFinite && $0.value > 0 }.sorted { $0.date < $1.date }
    }

    static func dailyMeans(_ points: [BodyTrendPoint], calendar: Calendar = .current) -> [BodyTrendPoint] {
        Dictionary(grouping: points, by: { calendar.startOfDay(for: $0.date) })
            .map { day, values in
                BodyTrendPoint(id: "day-\(day.timeIntervalSince1970)", date: day,
                    value: values.map(\.value).reduce(0, +) / Double(values.count))
            }.sorted { $0.date < $1.date }
    }

    /// A calendar-day window, not the previous seven readings. Each observed day has equal weight.
    static func sevenDayMeans(_ points: [BodyTrendPoint], calendar: Calendar = .current) -> [BodyTrendPoint] {
        let daily = dailyMeans(points, calendar: calendar)
        return daily.map { point in
            let start = calendar.date(byAdding: .day, value: -6, to: point.date) ?? point.date
            let window = daily.filter { $0.date >= start && $0.date <= point.date }
            return BodyTrendPoint(id: point.id, date: point.date,
                value: window.map(\.value).reduce(0, +) / Double(window.count))
        }
    }

    static func change(_ points: [BodyTrendPoint], metric: BodyMetric) -> String? {
        let daily = dailyMeans(points)
        guard let first = daily.first, let last = daily.last,
              last.date.timeIntervalSince(first.date) >= 7 * 86_400 else { return nil }
        let firstWeek = daily.filter { $0.date.timeIntervalSince(first.date) < 7 * 86_400 }
        let lastWeek = daily.filter { last.date.timeIntervalSince($0.date) < 7 * 86_400 }
        let useMeans = metric.smoothsTrend && last.date.timeIntervalSince(first.date) >= 28 * 86_400
            && firstWeek.count >= 2 && lastWeek.count >= 2
        let initial = useMeans ? firstWeek.map(\.value).reduce(0, +) / Double(firstWeek.count) : first.value
        let final = useMeans ? lastWeek.map(\.value).reduce(0, +) / Double(lastWeek.count) : last.value
        let delta = final - initial
        let rounded = (delta * pow(10, Double(metric.digits))).rounded() / pow(10, Double(metric.digits))
        let unit = metric == .bodyFat ? (abs(rounded) == 1 ? "percentage point" : "percentage points") : metric.unit
        let formatted = delta.formatted(.number.precision(.fractionLength(metric.digits)).sign(strategy: .always()))
        if rounded == 0 {
            return "No change at displayed precision · \(useMeans ? "first to latest week" : "first to latest day")"
        }
        return "\(formatted) \(unit) · \(useMeans ? "first to latest week" : "first to latest day")"
    }
}

struct BodyStatsSnapshot {
    var series: [BodyMetric: [BodyTrendPoint]] = [:]
    var references: [BodyMetric: BodyReferenceRange] = [:]
    var waistRatio: Double?
    var waistRange: BodyReferenceRange?
    var waistDate: Date?

    init(measurements: [BodyMeasurementRecord], waists: [WaistMeasurementRecord],
         healthWeight: [BodyTrendPoint], vo2: [BodyTrendPoint], currentProfile: BodyProfileSnapshot) {
        let ordered = measurements.sorted { $0.date < $1.date }
        for record in ordered {
            let result = record.composition
            let values: [(BodyMetric, Double?)] = [
                (.weight, record.weightKg), (.bodyFat, result.bodyFatPercentage?.value),
                (.leanMass, result.fatFreeMassKg?.value), (.skeletalMuscle, result.skeletalMuscleKg?.value),
                (.bmi, result.bmi?.value)
            ]
            for (metric, value) in values {
                guard let value else { continue }
                series[metric, default: []].append(.init(id: record.id.uuidString, date: record.date,
                    value: value, recordID: record.id))
                // A missing range on the latest valid result must clear any older age/model range.
                if metric == .bodyFat {
                    references[metric] = BodyReferences.bodyFat(age: record.profile.age, sex: record.profile.calculationSex)
                } else if metric == .bmi {
                    references[metric] = (record.profile.age ?? 0) >= 18 ? BodyReferences.bmi : nil
                }
            }
        }
        series[.weight] = BodyTrend.mergingWeight(scale: series[.weight] ?? [], health: healthWeight)
        series[.vo2] = vo2.sorted { $0.date < $1.date }
        series[.waist] = waists.filter { $0.circumferenceCm.isFinite && $0.circumferenceCm > 0 }.map {
            .init(id: $0.id.uuidString, date: $0.date, value: $0.circumferenceCm, source: "Manual waist")
        }.sorted { $0.date < $1.date }
        if let cm = currentProfile.waistCm, cm.isFinite, cm > 0, let date = currentProfile.waistDate {
            let alreadyPresent = (series[.waist] ?? []).contains {
                abs($0.date.timeIntervalSince(date)) < 1 && abs($0.value - cm) < 0.001
            }
            if !alreadyPresent {
                series[.waist, default: []].append(.init(id: "health-waist-\(date.timeIntervalSince1970)",
                    date: date, value: cm, source: currentProfile.waistSource ?? "Apple Health"))
                series[.waist]?.sort { $0.date < $1.date }
            }
        }
        if let latest = series[.waist]?.last {
            waistDate = latest.date
            let manual = waists.first { $0.id.uuidString == latest.id }
            let height = manual?.heightCm ?? currentProfile.heightCm
            if let height, height > 0 {
                waistRatio = latest.value / height
                if (currentProfile.age ?? 0) >= 18, let bmi = ordered.last?.composition.bmi, bmi.value < 35 {
                    waistRange = BodyReferences.waistToHeight
                }
            }
        }
    }
}
