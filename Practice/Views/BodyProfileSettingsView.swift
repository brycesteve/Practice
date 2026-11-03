import SwiftUI
import SwiftData

struct BodyProfileSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [BodyProfileSettings]
    @State private var height: Double?
    @State private var birthDateText = ""
    @State private var model = ""
    @State private var mac = ""
    @State private var company = ""
    @State private var message: String?
    @State private var profile = BodyProfileSnapshot()

    var body: some View {
        Form {
            Section("Health profile") {
                Text("Practice uses authorised HealthKit height, date of birth and biological sex first. Missing values use the fallbacks below.")
                if let cm = profile.heightCm {
                    LabeledContent("Height", value: "\(cm.formatted()) cm · \(profile.heightSource ?? "")")
                }
                if let age = profile.age { LabeledContent("Age", value: "\(age) · \(profile.ageSource ?? "")") }
                if let sex = profile.calculationSex {
                    LabeledContent("Calculation model", value: sex.rawValue.capitalized)
                } else {
                    Text("Choose a male or female calculation model if HealthKit cannot provide one. This selects equation coefficients; it does not change your Health profile.")
                }
                Button("Review Health access") {
                    Task {
                        do {
                            try await HealthKitManager.shared.requestAuthorization()
                            await refreshProfile()
                        } catch { message = error.localizedDescription }
                    }
                }
            }
            Section("Local fallbacks") {
                TextField("Height (cm)", value: $height, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Date of birth (YYYY-MM-DD)", text: $birthDateText)
                    .keyboardType(.numbersAndPunctuation)
                Picker("Calculation model", selection: $model) {
                    Text("Use HealthKit / not selected").tag("")
                    Text("Male coefficients").tag("male")
                    Text("Female coefficients").tag("female")
                }
                Text("No body-composition estimate is made without height, adult age and a calculation model. Weight is always the fresh scale reading.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Scale") {
                TextField("MAC address", text: $mac).textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Company identifier (hex)", text: $company)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                Text("This is the default scale for Watch. An explicit selection on Watch takes precedence. Leave both blank to discover AAA002 on Watch. Bluetooth pairing is not required.")
                    .font(.footnote)
                Button("Use development scale") {
                    mac = "A0:91:5B:35:E2:A8"
                    company = "A0AC"
                }
            }
            Section {
                Button("Save and sync to Watch") { save() }
                if let message { Text(message).font(.footnote) }
            }
        }
        .navigationTitle("Body profile & scale")
        .task {
            let config = settings.first?.configuration ?? .init()
            height = config.heightCm
            if let birth = config.dateOfBirth { birthDateText = Self.dateFormatter.string(from: birth) }
            model = config.calculationSex?.rawValue ?? ""
            mac = config.scale?.macAddress ?? ""
            company = config.scale.map { String(format: "%04X", $0.companyID) } ?? ""
            await refreshProfile()
        }
    }

    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }

    private func refreshProfile() async {
        profile = await HealthKitManager.shared.bodyProfile(fallback: settings.first?.configuration ?? .init())
    }

    private func save() {
        if let height, !height.isFinite || height <= 0 || height > 300 {
            message = "Enter a valid height in centimetres, or leave it blank."
            return
        }
        var config = BodyConfiguration()
        config.heightCm = height
        let text = birthDateText.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            guard let date = Self.dateFormatter.date(from: text), date <= Date(),
                  Self.dateFormatter.string(from: date) == text else {
                message = "Enter a valid date of birth as YYYY-MM-DD."
                return
            }
            config.dateOfBirth = date
        }
        config.calculationSex = BodyCalculationSex(rawValue: model)
        if !mac.isEmpty || !company.isEmpty {
            guard let identifier = UInt16(company, radix: 16),
                  let scale = ScaleIdentifier(companyID: identifier, macAddress: mac) else {
                message = "Enter a six-byte MAC and hexadecimal company identifier, or leave both blank."
                return
            }
            config.scale = scale
        }
        do {
            let record = settings.first ?? BodyProfileSettings()
            if settings.isEmpty { context.insert(record) }
            record.configuration = config
            try context.save()
            var payload = AppGroupDefaults.shared.loadAppContext()
            payload.bodyConfiguration = config
            AppGroupDefaults.shared.saveAppContext(payload)
            WatchConnectivityManager.shared.sendFullSync(payload: payload)
            message = "Saved. Watch settings will sync when available."
            Task { await refreshProfile() }
        } catch { message = error.localizedDescription }
    }
}
