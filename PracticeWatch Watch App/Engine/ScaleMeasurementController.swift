import Foundation
import CoreBluetooth
import Observation

@MainActor
@Observable
final class ScaleMeasurementController: NSObject, @preconcurrency CBCentralManagerDelegate {
    struct DiscoveredScale: Identifiable {
        let scale: ScaleIdentifier
        var id: String { "\(scale.companyID)-\(scale.macAddress)" }
    }

    private(set) var selectedScale: ScaleIdentifier?
    private(set) var discovered: [DiscoveredScale] = []
    private(set) var session: ScaleMeasurementSession?
    private(set) var status = "Ready"
    private(set) var isScanning = false
    private(set) var isPreparing = false
    private(set) var saved = false
    private(set) var saveError: String?
    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var profile = BodyProfileSnapshot()
    @ObservationIgnored private var requestedScan = false
    @ObservationIgnored private var scanStarted: Date?
    @ObservationIgnored private var generation = UUID()

    override init() {
        super.init()
        // An explicit on-Watch selection takes precedence over the phone's default.
        if let data = UserDefaults.standard.data(forKey: "selectedBodyScale") {
            selectedScale = try? JSONDecoder().decode(ScaleIdentifier.self, from: data)
        }
        if selectedScale == nil {
            selectedScale = AppGroupDefaults.shared.loadAppContext().bodyConfiguration?.scale
        }
    }

    func start() async {
        stop()
        let attempt = UUID()
        generation = attempt
        isPreparing = true
        saved = false
        saveError = nil
        session = nil
        discovered = []
        status = "Reading profile…"
        let configuration = AppGroupDefaults.shared.loadAppContext().bodyConfiguration ?? .init()
        let resolved = await HealthKitManager.shared.bodyProfile(fallback: configuration)
        guard generation == attempt else { return }
        profile = resolved
        isPreparing = false
        requestedScan = true
        scanStarted = .now
        if let selectedScale {
            session = ScaleMeasurementSession(startedAt: .now, scale: selectedScale)
        }
        status = selectedScale == nil ? "Step on the scale to discover it." : "Waiting for scale"
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil)
        } else if let central {
            // An already-denied/off manager may not emit another state callback.
            centralManagerDidUpdateState(central)
        }
        guard requestedScan else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                guard let self else { return }
                self.tick()
            }
        }
    }

    func select(_ scale: ScaleIdentifier) {
        selectedScale = scale
        if let data = try? JSONEncoder().encode(scale) {
            UserDefaults.standard.set(data, forKey: "selectedBodyScale")
        }
        session = ScaleMeasurementSession(startedAt: .now, scale: scale)
        status = "Selected. Step off, then step on to measure."
        discovered = []
    }

    func changeScale() {
        stop()
        selectedScale = nil
        session = nil
        UserDefaults.standard.removeObject(forKey: "selectedBodyScale")
        status = "Start to discover a scale."
    }

    func stop() {
        if (requestedScan || isPreparing) && session?.isFinished != true {
            status = "Measurement cancelled."
        }
        generation = UUID()
        requestedScan = false
        central?.stopScan()
        isScanning = false
        isPreparing = false
        ticker?.cancel()
        ticker = nil
        if session?.isFinished == false { session?.cancel() }
    }

    func retrySave() {
        guard var raw = session?.completedMeasurement, !saved else { return }
        raw.profile = profile
        do {
            try BodyMeasurementOutbox.shared.enqueue(raw)
            saved = true
            saveError = nil
            status = raw.impedanceOhms == nil ? "Weight saved" : "Measurement saved"
            WatchConnectivityManager.shared.flushBodyMeasurements()
        } catch {
            saveError = "Could not save on Watch: \(error.localizedDescription)"
        }
    }

    private func tick() {
        session?.advance(to: .now)
        if session?.completedMeasurement != nil {
            stop()
            retrySave()
        } else if let failure = session?.failure {
            stop()
            status = failure
        } else if session == nil, let scanStarted, Date().timeIntervalSince(scanStarted) >= 60 {
            stop()
            status = "No scale found. Wake the scale and try again."
        }
    }

    private func beginScanIfReady() {
        guard requestedScan, let central, central.state == .poweredOn else { return }
        // Broadcast-only device. No connection/pairing or service filter is involved.
        central.scanForPeripherals(withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: beginScanIfReady()
        case .unknown, .resetting: status = "Waiting for Bluetooth…"
        case .poweredOff: stop(); status = "Turn on Bluetooth, then try again."
        case .unauthorized: stop(); status = "Allow Bluetooth access in Settings."
        case .unsupported: stop(); status = "Bluetooth is unavailable."
        @unknown default: stop(); status = "Bluetooth is unavailable."
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard requestedScan,
              let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              let identity = ScaleIdentifier(manufacturerData: data),
              let frame = ScaleDecoder.decode(data) else { return }
        if let selectedScale {
            guard selectedScale == identity else { return }
            session?.receive(frame, at: .now)
            tick()
        } else {
            let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
            guard name == "AAA002", !discovered.contains(where: { $0.scale == identity }) else { return }
            discovered.append(DiscoveredScale(scale: identity))
        }
    }

    deinit { ticker?.cancel() }
}
