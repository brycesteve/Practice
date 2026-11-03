import SwiftUI
import SwiftData
import Charts

struct BodyCompositionHistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.bodyStatsSampleMode) private var sampleMode
    @Query(sort: \BodyMeasurementRecord.date, order: .reverse) private var measurements: [BodyMeasurementRecord]

    var body: some View {
        List {
            if measurements.isEmpty {
                ContentUnavailableView("No scale measurements", systemImage: "scalemass",
                    description: Text("Open Body measurement on your Apple Watch to get started."))
            } else {
                Section {
                    ForEach(measurements) { record in
                        NavigationLink { BodyMeasurementDetailView(record: record) } label: {
                            BodyMeasurementHistoryRow(record: record)
                        }
                    }
                } header: { Text("Scale readings") } footer: {
                    Text("Open a reading for estimates, calculation inputs and technical information.")
                }
            }
            Section {
                DisclosureGroup("Apple Health exports") {
                    Text("Practice keeps your readings even when an export is unavailable. Retry after updating Health permissions.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Retry Health exports") {
                        Task { await BodyMeasurementStore.retryHealthExports(in: context) }
                    }.disabled(sampleMode)
                }
            }
        }
        .navigationTitle("Measurements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BodyMeasurementHistoryRow: View {
    let record: BodyMeasurementRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.date, format: .dateTime.day().month().year().hour().minute()).font(.caption)
            Text("\(record.weightKg, format: .number.precision(.fractionLength(1))) kg · measured")
            if let fat = record.composition.bodyFatPercentage {
                Text("≈\(fat.value, format: .number.precision(.fractionLength(0)))% body fat · estimated")
                    .font(.caption).foregroundStyle(.secondary)
            } else if record.impedanceOhms == nil {
                Text("Weight only").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct BodyMeasurementDetailView: View {
    @Environment(\.modelContext) private var context
    let record: BodyMeasurementRecord
    @State private var message: String?
    @Environment(\.bodyStatsSampleMode) private var sampleMode

    var body: some View {
        List {
            Section("Measured") {
                Text(record.date, format: .dateTime.day().month().year().hour().minute())
                BodyMetricRow(title: "Weight", value: record.weightKg, unit: "kg")
                if let waist = record.profile.waistCm {
                    BodyMetricRow(title: "Latest waist", value: waist, unit: "cm")
                    if let date = record.profile.waistDate {
                        Text("Waist recorded \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                    }
                }
            }
            Section("Calculated & estimated") {
                BodyCompositionValuesView(weightKg: record.weightKg, profile: record.profile, result: record.composition)
                Text("≈ denotes an estimate, not a direct measurement.").font(.footnote)
            }
            DisclosureGroup("Calculation inputs") {
                BodyMetricRow(title: "Height", value: record.profile.heightCm, unit: "cm")
                if let age = record.profile.age { LabeledContent("Age at measurement", value: "\(age)") }
                LabeledContent("Model", value: record.profile.calculationSex?.rawValue.capitalized ?? "Not selected")
                Text([record.profile.heightSource, record.profile.ageSource, record.profile.sexSource]
                    .compactMap { $0 }.joined(separator: " · ")).font(.caption)
                NavigationLink("Complete missing profile") { BodyProfileSettingsView() }.disabled(sampleMode)
                Button("Fill missing calculation inputs") {
                    Task {
                        do {
                            try await BodyMeasurementStore.fillMissingProfile(record, in: context)
                            await BodyMeasurementStore.export(record, in: context)
                            message = "Available inputs saved. Raw scale readings are unchanged."
                        } catch { message = error.localizedDescription }
                    }
                }
                .disabled(sampleMode)
                if let message { Text(message).font(.footnote) }
            }
            DisclosureGroup("Method & technical information") {
                BodyMetricRow(title: "Impedance", value: record.impedanceOhms, unit: "Ω", digits: 0)
                Text(KushnerSchoellerCalculator.method + " · algorithm v1")
                Text("Skeletal muscle: Janssen 2000 · v1. BMR: Katch–McArdle · v1.")
                Text("Impedance units are experimentally inferred. Scale frequency and equivalence to the equations' whole-body resistance are unverified.")
                Text(record.scaleMAC)
                if let metadata = record.impedanceMetadata {
                    Text(verbatim: String(format: "Impedance metadata: 0x%04X (unknown)", metadata))
                }
            }.font(.footnote)
            DisclosureGroup("Apple Health export") {
                Text(record.healthExportedTypes.isEmpty ? "No authorised samples exported yet." : "Authorised samples exported.")
                if let error = record.healthExportError { Text(error) }
                Button("Retry export") { Task { await BodyMeasurementStore.export(record, in: context) } }.disabled(sampleMode)
            }.font(.footnote)
        }.navigationTitle("Measurement").navigationBarTitleDisplayMode(.inline)
    }
}

private struct BodyCompositionValuesView: View {
    let weightKg: Double
    let profile: BodyProfileSnapshot
    let result: BodyCompositionResult

    var body: some View {
        Group {
            if let fat = result.bodyFatPercentage {
                if let range = BodyReferences.bodyFat(age: profile.age, sex: profile.calculationSex) {
                    BodyReferenceGauge(title: "≈ Body fat (%)", value: fat.value, range: range, domain: 0...60, digits: 0)
                } else {
                    BodyMetricRow(title: "≈ Body fat", value: fat.value, unit: "%", digits: 0)
                }
            } else {
                Text("Body-fat estimate unavailable: impedance, adult age, height and a calculation model are required; implausible results are omitted.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            BodyMetricRow(title: "≈ Fat mass", value: result.fatMassKg?.value, unit: "kg")
            BodyMetricRow(title: "≈ Fat-free mass", value: result.fatFreeMassKg?.value, unit: "kg")
            BodyMetricRow(title: "≈ Total body water", value: result.totalBodyWaterLitres?.value, unit: "L")
            BodyMetricRow(title: "≈ Skeletal muscle mass", value: result.skeletalMuscleKg?.value, unit: "kg")
            BodyMetricRow(title: "≈ BMR", value: result.basalMetabolicRate?.value, unit: "kcal/day", digits: 0)
            if let bmi = result.bmi {
                if let age = profile.age, age >= 18 {
                    BodyReferenceGauge(title: "BMI", value: bmi.value, range: BodyReferences.bmi, domain: 10...45, digits: 1, usesBMILabels: true)
                } else { BodyMetricRow(title: "BMI", value: bmi.value, unit: "kg/m²") }
            }
            if let ratio = result.waistToHeightRatio {
                if let age = profile.age, age >= 18, let bmi = result.bmi, bmi.value < 35 {
                    BodyReferenceGauge(title: "Waist / height", value: ratio.value,
                        range: BodyReferences.waistToHeight, domain: 0.2...0.8, digits: 2)
                } else { BodyMetricRow(title: "Waist / height", value: ratio.value, unit: "", digits: 2) }
            }
        }
    }
}

private struct BodyMetricRow: View {
    let title: LocalizedStringKey
    let value: Double?
    let unit: String
    var digits = 1

    var body: some View {
        if let value {
            LabeledContent(title) {
                Text("\(value, format: .number.precision(.fractionLength(digits))) \(unit)")
                    .monospacedDigit()
            }
        }
    }
}

struct BodyReferenceGauge: View {
    let title: LocalizedStringKey
    let value: Double
    let range: BodyReferenceRange
    let domain: ClosedRange<Double>
    let digits: Int
    var usesBMILabels = false

    private var category: BodyReferenceCategory? { range.classify(value) }
    private var label: String {
        switch category {
        case .low: usesBMILabels ? "Underweight / low" : "Low / below reference"
        case .reference: "Reference"
        case .elevated: usesBMILabels ? "Overweight / increased" : "Elevated"
        case .high: usesBMILabels ? "Obesity / high" : "High"
        case nil: "Unclassified"
        }
    }
    private var tint: Color {
        switch category {
        case .reference: .green
        case .elevated, .low: .orange
        case .high: .red
        case nil: .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Text(value, format: .number.precision(.fractionLength(digits)))
                .font(.title2.bold()).monospacedDigit()
            // A reference band with a position marker, not a progress bar suggesting higher is better.
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Color.green.opacity(0.35))
                        .frame(width: geometry.size.width * fraction(range.upper - range.lower))
                        .offset(x: geometry.size.width * fraction(range.lower - domain.lowerBound))
                    Capsule().fill(.primary)
                        .frame(width: 4, height: 18)
                        .offset(x: max(0, min(geometry.size.width - 4,
                            geometry.size.width * fraction(value - domain.lowerBound))))
                }
            }.frame(height: 10).accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: category == .reference ? "checkmark.circle" : "info.circle")
                    .foregroundStyle(tint)
                Text(label).foregroundStyle(.primary)
            }.font(.subheadline.weight(.medium))
            Text("Reference \(range.lower.formatted())–<\(range.upper.formatted())")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value.formatted(.number.precision(.fractionLength(digits)))), \(label). Reference \(range.lower.formatted()) to below \(range.upper.formatted()).")
    }

    private func fraction(_ value: Double) -> Double {
        min(1, max(0, value / (domain.upperBound - domain.lowerBound)))
    }
}

struct WaistEntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var waistCm: Double?
    @State private var date = Date()
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        Form {
            TextField("Waist circumference (cm)", value: $waistCm, format: .number).keyboardType(.decimalPad)
            DatePicker("Measured", selection: $date, in: ...Date())
            Text("Measure midway between the bottom of your ribs and the top of your hips, after breathing out naturally.")
                .font(.footnote)
            Button("Save waist measurement") { Task { await save() } }
                .disabled(saving)
            if let error { Text(error) }
        }
        .navigationTitle("Record waist")
        .toolbar { Button("Cancel") { dismiss() }.disabled(saving) }
    }

    private func save() async {
        guard let waistCm, waistCm.isFinite, (20...300).contains(waistCm) else {
            error = "Enter a waist circumference between 20 and 300 cm."
            return
        }
        saving = true
        defer { saving = false }
        do {
            let configuration = try BodyMeasurementStore.configuration(in: context)
            let profile = await HealthKitManager.shared.bodyProfile(fallback: configuration, at: date)
            let record = try BodyMeasurementStore.insertWaist(date: date, circumferenceCm: waistCm,
                heightCm: profile.heightCm, into: context)
            await BodyMeasurementStore.exportWaist(record, in: context)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
