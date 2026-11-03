import Foundation

struct BodyEstimate: Equatable, Sendable {
    let value: Double
    let method: String
    let algorithmVersion: Int
}

struct BodyCompositionResult: Sendable {
    var bmi: BodyEstimate?
    var waistToHeightRatio: BodyEstimate?
    var totalBodyWaterLitres: BodyEstimate?
    var fatFreeMassKg: BodyEstimate?
    var fatMassKg: BodyEstimate?
    var bodyFatPercentage: BodyEstimate?
    var skeletalMuscleKg: BodyEstimate?
    var basalMetabolicRate: BodyEstimate?
}

protocol BodyCompositionCalculating {
    var algorithmVersion: Int { get }
    func calculate(weightKg: Double, impedanceOhms: Double?, profile: BodyProfileSnapshot) -> BodyCompositionResult
}

/// Independently implemented published equations; no openScale/GPL implementation used.
///
/// Kushner RF, Schoeller DA. AJCN 1986;44:417–424. doi:10.1093/ajcn/44.3.417.
/// Sex-specific D2O-TBW (L):
/// male:   0.396 * heightCm² / resistanceOhms + 0.143 * weightKg + 8.399
/// female: 0.382 * heightCm² / resistanceOhms + 0.105 * weightKg + 8.315
/// FFM = TBW / 0.732 (constant adult FFM hydration; water treated as 1 kg/L).
/// Fat mass = fresh scale weight − FFM; body fat % = 100 * fat / scale weight.
/// This version uses the published D2O-TBW predictions directly, without a separate
/// isotope-space correction. Changing that assumption requires a new algorithm version.
///
/// These equations use whole-body resistance at 50 kHz. The scale's whole-ohm
/// interpretation is experimentally inferred; its frequency and equivalence to
/// hand-to-foot resistance are NOT established. Foot-to-foot application is therefore
/// an unvalidated estimate, sensitive to hydration, contact, posture and population.
/// Adult estimates only; no clamping of impossible estimates to plausible-looking values.
struct KushnerSchoellerCalculator: BodyCompositionCalculating {
    let algorithmVersion = 1
    static let method = "Kushner–Schoeller 1986, sex-specific; hydration 0.732"

    func calculate(weightKg: Double, impedanceOhms: Double?, profile: BodyProfileSnapshot) -> BodyCompositionResult {
        var result = BodyCompositionResult()
        func estimate(_ value: Double, _ method: String) -> BodyEstimate? {
            guard value.isFinite, value > 0 else { return nil }
            return BodyEstimate(value: value, method: method, algorithmVersion: algorithmVersion)
        }
        guard let height = profile.heightCm, height.isFinite, height > 0 else { return result }
        if let waist = profile.waistCm, waist.isFinite, waist > 0 {
            result.waistToHeightRatio = estimate(waist / height, "Waist / height, same units")
        }
        guard weightKg.isFinite, weightKg > 0 else { return result }
        result.bmi = estimate(weightKg / pow(height / 100, 2), "BMI: kg / m²")
        guard let age = profile.age, (18...120).contains(age),
              let sex = profile.calculationSex,
              let resistance = impedanceOhms, resistance.isFinite, resistance > 0 else { return result }
        let index = height * height / resistance
        let water: Double
        switch sex {
        case .male: water = 0.396 * index + 0.143 * weightKg + 8.399
        case .female: water = 0.382 * index + 0.105 * weightKg + 8.315
        }
        let ffm = water / 0.732
        guard water.isFinite, water > 0, ffm > 0, ffm < weightKg else { return result }
        result.totalBodyWaterLitres = estimate(water, Self.method)
        result.fatFreeMassKg = estimate(ffm, Self.method)
        result.fatMassKg = estimate(weightKg - ffm, Self.method)
        result.bodyFatPercentage = estimate(100 * (weightKg - ffm) / weightKg, Self.method)
        // Katch–McArdle, Exercise Physiology (McArdle, Katch & Katch):
        // basal energy kcal/day = 370 + 21.6 * fat-free mass in kg.
        result.basalMetabolicRate = estimate(370 + 21.6 * ffm, "Katch–McArdle; FFM from " + Self.method)
        // Janssen et al. J Appl Physiol 2000;89:465–471.
        // doi:10.1152/jappl.2000.89.2.465. Ht cm; R ohms; age years; male=1, female=0.
        // Predicts skeletal muscle, NOT all lean tissue or generic muscle mass.
        let muscle = 0.401 * index + (sex == .male ? 3.825 : 0) - 0.071 * Double(age) + 5.102
        if muscle < ffm {
            result.skeletalMuscleKg = estimate(muscle, "Janssen 2000")
        }
        return result
    }
}

enum BodyReferenceCategory: String, Sendable {
    case low, reference, elevated, high
}

/// Threshold data has no dependency on UI wording or colours.
struct BodyReferenceRange: Sendable {
    let lower: Double
    let upper: Double
    let high: Double
    let source: String

    func classify(_ value: Double) -> BodyReferenceCategory? {
        guard value.isFinite, value >= 0 else { return nil }
        if value < lower { return .low }
        if value < upper { return .reference }
        if value < high { return .elevated }
        return .high
    }
}

enum BodyReferences {
    // NICE NG246 adult general BMI thresholds (not ethnicity-adjusted).
    static let bmi = BodyReferenceRange(lower: 18.5, upper: 25, high: 30, source: "NICE NG246")
    // Below 0.40 is outside the reference band, not automatically better.
    // NICE recommends central-adiposity classification for adults with BMI <35.
    static let waistToHeight = BodyReferenceRange(lower: 0.40, upper: 0.50, high: 0.60, source: "NICE NG246")

    struct FatBand: Sendable {
        let sex: BodyCalculationSex
        let ages: ClosedRange<Int>
        let range: BodyReferenceRange
    }

    /// Gallagher et al. AJCN 2000;72:694–701, Table 4 (4-compartment estimates,
    /// African American/white groups), doi:10.1093/ajcn/72.3.694.
    /// Provisional reference bands, NOT diagnostic cut-offs or universal ethnic norms.
    /// Deliberately uses the original Table 4, rather than rounded commercial charts.
    static let bodyFatBands: [FatBand] = [
        .init(sex: .female, ages: 20...39, range: .init(lower: 21, upper: 33, high: 39, source: "Gallagher 2000, Table 4")),
        .init(sex: .female, ages: 40...59, range: .init(lower: 23, upper: 34, high: 40, source: "Gallagher 2000, Table 4")),
        .init(sex: .female, ages: 60...79, range: .init(lower: 24, upper: 36, high: 42, source: "Gallagher 2000, Table 4")),
        .init(sex: .male, ages: 20...39, range: .init(lower: 8, upper: 20, high: 25, source: "Gallagher 2000, Table 4")),
        .init(sex: .male, ages: 40...59, range: .init(lower: 11, upper: 22, high: 28, source: "Gallagher 2000, Table 4")),
        .init(sex: .male, ages: 60...79, range: .init(lower: 13, upper: 25, high: 30, source: "Gallagher 2000, Table 4"))
    ]

    static func bodyFat(age: Int?, sex: BodyCalculationSex?) -> BodyReferenceRange? {
        guard let age, let sex else { return nil }
        return bodyFatBands.first { $0.sex == sex && $0.ages.contains(age) }?.range
    }
}
