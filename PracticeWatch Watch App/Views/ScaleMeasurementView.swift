import SwiftUI

struct ScaleMeasurementView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller = ScaleMeasurementController()
    @State private var outbox = BodyMeasurementOutbox.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "scalemass").font(.title)
                Text(controller.status).multilineTextAlignment(.center)
                if let weight = controller.session?.liveWeightKg {
                    Text("\(weight, format: .number.precision(.fractionLength(1))) kg")
                        .font(.title2.bold()).monospacedDigit()
                }
                if controller.session?.finalWeightKg != nil {
                    Label("Stabilised", systemImage: "checkmark.circle")
                    if controller.session?.impedanceOhms != nil {
                        Label("Impedance received", systemImage: "checkmark.circle")
                    } else if controller.session?.completedMeasurement == nil {
                        ProgressView("Waiting for impedance…")
                        Text("Weight-only recording after 12 seconds.").font(.footnote)
                    } else {
                        Text("Weight only — no impedance received.").font(.footnote)
                    }
                }
                if controller.saved, let raw = controller.session?.completedMeasurement {
                    Label("Saved on Watch", systemImage: "checkmark.circle.fill")
                    Text(outbox.pending.contains(where: { $0.id == raw.id })
                         ? "Waiting to sync with iPhone." : "Saved on iPhone.")
                        .font(.footnote)
                    Text("Step off before starting another measurement.").font(.footnote)
                }
                if let error = controller.saveError {
                    Text(error).foregroundStyle(.red)
                    Button("Retry save") { controller.retrySave() }
                }
                ForEach(controller.discovered) { device in
                    Button { controller.select(device.scale) } label: {
                        VStack {
                            Text("Use AAA002")
                            Text(device.scale.macAddress).font(.caption2)
                        }
                    }
                }
                if controller.isScanning || controller.isPreparing {
                    Button("Cancel") { controller.stop() }
                } else if controller.saveError == nil {
                    Button(controller.saved ? "New measurement" : "Start measurement") {
                        Task { await controller.start() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                if !controller.isScanning && !controller.isPreparing {
                    Button("Choose another scale") { controller.changeScale() }
                        .font(.footnote)
                }
                Text("Keep this screen open. Stand barefoot for impedance.")
                    .font(.footnote).foregroundStyle(.secondary)
                if !outbox.pending.isEmpty {
                    Button("Retry iPhone sync (\(outbox.pending.count))") {
                        WatchConnectivityManager.shared.flushBodyMeasurements()
                    }.font(.footnote)
                }
            }.padding()
        }
        .navigationTitle("Body measurement")
        .onDisappear { controller.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { controller.stop() }
        }
        .task { WatchConnectivityManager.shared.flushBodyMeasurements() }
    }
}
