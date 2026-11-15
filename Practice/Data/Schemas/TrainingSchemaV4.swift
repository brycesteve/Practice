import Foundation
import SwiftData

/// Additive only. V1–V3 and all existing model identities remain unchanged.
enum TrainingSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] {
        TrainingSchemaV3.models + [ProgressPhotoSession.self, ProgressPhotoRecord.self]
    }

    @Model
    final class ProgressPhotoSession {
        var id: UUID = UUID()
        var date: Date = Date()
        init(id: UUID = UUID(), date: Date = .now) {
            self.id = id
            self.date = date
        }
    }

    /// Each capture is an immutable revision. Replacement never overwrites the old bytes.
    /// Scalar session IDs avoid cascading deletion while CloudKit imports arrive out of order.
    @Model
    final class ProgressPhotoRecord {
        var id: UUID = UUID()
        var sessionID: UUID = UUID()
        var capturedAt: Date = Date()
        var viewRaw: String = "front"
        var contentHash: String = ""
        var pixelWidth: Int = 0
        var pixelHeight: Int = 0
        var fileExtension: String = "jpg"
        var deletedAt: Date?
        @Attribute(.externalStorage) var imageData: Data?
        var thumbnailData: Data?

        init(id: UUID, sessionID: UUID, capturedAt: Date, viewRaw: String,
             imageData: Data, thumbnailData: Data, contentHash: String,
             pixelWidth: Int, pixelHeight: Int, fileExtension: String) {
            self.id = id
            self.sessionID = sessionID
            self.capturedAt = capturedAt
            self.viewRaw = viewRaw
            self.imageData = imageData
            self.thumbnailData = thumbnailData
            self.contentHash = contentHash
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.fileExtension = fileExtension
        }
    }
}
