#if DEBUG && targetEnvironment(simulator)
import SwiftUI
import SwiftData

/// Explicit, isolated simulator inspection. Never opens the user's store or activates Health / Watch sync.
@MainActor
enum BodyStatsSamples {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("--body-stats-sample") }
    static let fixture = makeFixture()
    static var isDark: Bool { ProcessInfo.processInfo.arguments.contains("--body-stats-dark") }
    static var isLarge: Bool { ProcessInfo.processInfo.arguments.contains("--body-stats-large") }

    static func makeFixture() -> (container: ModelContainer, input: BodyStatsSampleInput) {
        do {
            let container = try ModelContainer(for: BodyMeasurementRecord.self, WaistMeasurementRecord.self,
                BodyProfileSettings.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
            var input = BodyStatsSampleInput()
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--body-stats-empty") { return (container, input) }
            let single = arguments.contains("--body-stats-single")
            let scale = ScaleIdentifier(companyID: 0xA0AC, macAddress: "A0:91:5B:35:E2:A8")!
            let count = single ? 1 : 61
            for index in 0..<count {
                let date = Calendar.current.date(byAdding: .day, value: -(count - 1 - index) * 3, to: .now)!
                let fraction = Double(index) / Double(max(1, count - 1))
                let weight = 71.2 - 3.4 * fraction + sin(Double(index) * 1.7) * 0.35
                let profile = BodyProfileSnapshot(heightCm: 172, age: 47, calculationSex: .male)
                let raw = RawBodyMeasurement(date: date, weightKg: weight,
                    impedanceOhms: 529 + sin(Double(index)) * 3, scale: scale, profile: profile)
                container.mainContext.insert(try BodyMeasurementRecord(raw))
                // Deliberate Health copies exercise display deduplication.
                input.weight.append(.init(id: "sample-health-\(index)", date: date, value: weight, source: "Apple Health"))
                if index.isMultiple(of: 3) || single {
                    input.vo2.append(.init(id: "sample-vo2-\(index)", date: date,
                        value: 40.3 + fraction * 3.5 + cos(Double(index)) * 0.3, source: "Apple Health"))
                    container.mainContext.insert(try WaistMeasurementRecord(date: date,
                        circumferenceCm: 89 - 4 * fraction, heightCm: 172))
                }
            }
            input.profile = BodyProfileSnapshot(heightCm: 172, age: 47, calculationSex: .male, waistCm: 85)
            input.profile.waistDate = .now
            input.profile.waistSource = "Sample manual waist"
            try container.mainContext.save()
            return (container, input)
        } catch { fatalError("Cannot construct isolated Body Stats sample: \(error)") }
    }
}

struct BodyStatsSampleScreen: View {
    var body: some View {
        NavigationStack {
            BodyStatsView(sample: BodyStatsSamples.fixture.input)
        }
        .modelContainer(BodyStatsSamples.fixture.container)
        .environment(\.bodyStatsSampleMode, true)
        .preferredColorScheme(BodyStatsSamples.isDark ? .dark : .light)
        .dynamicTypeSize(BodyStatsSamples.isLarge ? .accessibility3 : .large)
    }
}

#Preview("Populated Body Stats") {
    BodyStatsSampleScreen()
}
#endif
