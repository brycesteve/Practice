import Foundation
import Observation

/// Durable Watch outbox over the existing WC transport; remove only after a phone save.
@MainActor
@Observable
final class BodyMeasurementOutbox {
    static let shared = BodyMeasurementOutbox()
    private(set) var pending: [RawBodyMeasurement] = []
    private(set) var errorMessage: String?
    private let fileURL: URL
    private var loadError: Error?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory.appendingPathComponent("BodyMeasurementOutbox.json")
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                pending = try JSONDecoder().decode([RawBodyMeasurement].self, from: Data(contentsOf: self.fileURL))
            }
        } catch {
            loadError = error
            errorMessage = error.localizedDescription
        }
    }

    func enqueue(_ measurement: RawBodyMeasurement) throws {
        if let loadError { throw loadError }
        guard measurement.isValid, !pending.contains(where: { $0.id == measurement.id }) else { return }
        let updated = pending + [measurement]
        try persist(updated)
        pending = updated
        errorMessage = nil
    }

    func acknowledge(_ id: UUID) throws {
        if let loadError { throw loadError }
        let updated = pending.filter { $0.id != id }
        try persist(updated)
        pending = updated
        errorMessage = nil
    }

    private func persist(_ measurements: [RawBodyMeasurement]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(measurements).write(to: fileURL, options: .atomic)
    }
}
