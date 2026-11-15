import Foundation
import SwiftData
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
import UIKit
import LocalAuthentication
import Observation

enum ProgressPhotoView: String, CaseIterable, Identifiable, Codable {
    case front, side, back
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct ProgressPhotoDraft: Identifiable, Sendable {
    let id: UUID
    let view: ProgressPhotoView
    let capturedAt: Date
    let data: Data
    init(id: UUID = UUID(), view: ProgressPhotoView, capturedAt: Date = .now, data: Data) {
        self.id = id; self.view = view; self.capturedAt = capturedAt; self.data = data
    }
}

enum ProgressPhotoError: LocalizedError {
    case invalidImage, missingImage, invalidSession, duplicateView, conflictingIdentity
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "This photograph could not be read. Please retake it."
        case .missingImage: return "The original photograph is unavailable. Allow iCloud to finish downloading, then try again."
        case .invalidSession: return "This photo session is unavailable. Please reopen Progress."
        case .duplicateView: return "Choose one photograph for each view."
        case .conflictingIdentity: return "This photograph’s identifier is already in use. Please reopen the session."
        }
    }
}

/// ImageIO applies EXIF orientation to previews; originals are never resized or re-encoded.
enum ProgressPhotoImage {
    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func preview(_ data: Data?, maxPixel: Int = 1400) -> UIImage? {
        guard let data, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    static func properties(_ data: Data) throws -> (width: Int, height: Int, ext: String, thumbnail: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetStatus(source) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0,
              let thumbnail = preview(data, maxPixel: 360)?.jpegData(compressionQuality: 0.8) else {
            throw ProgressPhotoError.invalidImage
        }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let rotated = (5...8).contains(orientation)
        let ext = (CGImageSourceGetType(source) as String?).flatMap { UTType($0)?.preferredFilenameExtension } ?? "jpg"
        return (rotated ? height : width, rotated ? width : height, ext, thumbnail)
    }
}

@MainActor
enum ProgressPhotoStore {
    /// No suspension between lookup and save. A retry of the same draft inserts nothing twice.
    /// A dedicated context keeps errors from rolling back unrelated workout/UI changes.
    static func save(sessionID: UUID, date: Date, drafts: [ProgressPhotoDraft], into container: ModelContainer) throws {
        guard !drafts.isEmpty else { throw ProgressPhotoError.invalidImage }
        guard Set(drafts.map(\.view)).count == drafts.count else { throw ProgressPhotoError.duplicateView }
        let prepared = try drafts.map { ($0, try ProgressPhotoImage.properties($0.data)) }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let sessions = try context.fetch(FetchDescriptor<ProgressPhotoSession>(predicate: #Predicate { $0.id == sessionID }))
        if sessions.isEmpty { context.insert(ProgressPhotoSession(id: sessionID, date: date)) }
        let records = try context.fetch(FetchDescriptor<ProgressPhotoRecord>())
        for (draft, info) in prepared {
            let hash = ProgressPhotoImage.hash(draft.data)
            if let existing = records.first(where: { $0.id == draft.id }) {
                guard existing.sessionID == sessionID, existing.viewRaw == draft.view.rawValue,
                      existing.contentHash == hash else { throw ProgressPhotoError.conflictingIdentity }
                continue
            }
            for old in records where old.sessionID == sessionID && old.viewRaw == draft.view.rawValue && old.deletedAt == nil {
                old.deletedAt = .now
            }
            context.insert(ProgressPhotoRecord(id: draft.id, sessionID: sessionID,
                capturedAt: draft.capturedAt, viewRaw: draft.view.rawValue, imageData: draft.data,
                thumbnailData: info.thumbnail, contentHash: hash, pixelWidth: info.width,
                pixelHeight: info.height, fileExtension: info.ext))
        }
        try context.save()
    }

    static func setDeleted(_ id: UUID, deleted: Bool, in container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        guard let record = try context.fetch(FetchDescriptor<ProgressPhotoRecord>(predicate: #Predicate { $0.id == id })).first else {
            throw ProgressPhotoError.missingImage
        }
        if !deleted {
            let sessionID = record.sessionID, view = record.viewRaw
            let siblings = try context.fetch(FetchDescriptor<ProgressPhotoRecord>(predicate: #Predicate {
                $0.sessionID == sessionID && $0.viewRaw == view
            }))
            for sibling in siblings where sibling.id != id && sibling.deletedAt == nil { sibling.deletedAt = .now }
        }
        record.deletedAt = deleted ? .now : nil
        try context.save()
    }

    static func permanentlyDelete(_ id: UUID, in container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        guard let record = try context.fetch(FetchDescriptor<ProgressPhotoRecord>(predicate: #Predicate { $0.id == id })).first,
              record.deletedAt != nil else { throw ProgressPhotoError.invalidSession }
        context.delete(record)
        try context.save()
    }

    /// Concurrent captures on different devices are retained. Pick a deterministic current view.
    static func currentPhotos(_ records: [ProgressPhotoRecord], sessionID: UUID) -> [ProgressPhotoRecord] {
        ProgressPhotoView.allCases.compactMap { view in
            records.filter { $0.sessionID == sessionID && $0.viewRaw == view.rawValue && $0.deletedAt == nil }
                .sorted {
                    $0.capturedAt == $1.capturedAt ? $0.id.uuidString > $1.id.uuidString : $0.capturedAt > $1.capturedAt
                }.first
        }
    }
}

struct ProgressPhotoExport: Codable {
    struct Entry: Codable {
        let id: UUID
        let sessionID: UUID
        let sessionDate: Date
        let capturedAt: Date
        let view: String
        let deletedAt: Date?
        let filename: String
        let sha256: String
    }
    let formatVersion: Int
    let photographs: [Entry]
}

@MainActor
enum ProgressPhotoBackup {
    /// Fail explicitly if any requested original is missing; never produce a silently partial backup.
    static func prepare(photos: [ProgressPhotoRecord], sessions: [ProgressPhotoSession]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Practice-Progress-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        let archive = directory.appendingPathExtension("zip")
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            var entries: [ProgressPhotoExport.Entry] = []
            for photo in photos {
                guard let data = photo.imageData, !data.isEmpty,
                      ProgressPhotoImage.hash(data) == photo.contentHash else { throw ProgressPhotoError.missingImage }
                let ext = try ProgressPhotoImage.properties(data).ext
                let name = "\(photo.id.uuidString).\(ext)"
                try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
                entries.append(.init(id: photo.id, sessionID: photo.sessionID,
                    sessionDate: sessions.first { $0.id == photo.sessionID }?.date ?? photo.capturedAt,
                    capturedAt: photo.capturedAt, view: photo.viewRaw, deletedAt: photo.deletedAt,
                    filename: name, sha256: photo.contentHash))
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(ProgressPhotoExport(formatVersion: 1, photographs: entries))
                .write(to: directory.appendingPathComponent("manifest.json"), options: [.atomic, .completeFileProtection])
            // Foundation provides a coordinated ZIP representation for directory uploads.
            // Copy it before the coordination block ends; its temporary URL is otherwise invalid.
            var coordinationError: NSError?
            var archiveError: Error?
            NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading, error: &coordinationError) { url in
                do {
                    try FileManager.default.copyItem(at: url, to: archive)
                    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: archive.path)
                } catch { archiveError = error }
            }
            if let error = coordinationError ?? archiveError { throw error }
            return archive
        } catch {
            try? FileManager.default.removeItem(at: archive)
            throw error
        }
    }
}

/// Presentation content and visibility have a single source of truth.
struct ProgressPhotoInspection: Identifiable {
    let id = UUID()
    let data: Data
}

struct ProgressPhotoExportPresentation: Identifiable {
    let id = UUID()
    let url: URL
    func cleanUp() { try? FileManager.default.removeItem(at: url) }
}

@MainActor @Observable
final class ProgressPhotoAccess {
    private(set) var isUnlocked = false
    private(set) var isAuthenticating = false
    private(set) var message: String?
    private var attempt = UUID()
    private var authenticationContext: LAContext?
    private let authenticate: (@MainActor () async throws -> Bool)?

    init(authenticate: (@MainActor () async throws -> Bool)? = nil) {
        self.authenticate = authenticate
    }

    func unlock() async {
        guard !isAuthenticating, !isUnlocked else { return }
        let currentAttempt = UUID()
        attempt = currentAttempt
        isAuthenticating = true
        message = nil
        do {
            let accepted: Bool
            if let authenticate {
                accepted = try await authenticate()
            } else {
                let context = LAContext()
                authenticationContext = context
                accepted = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                    localizedReason: "View your private progress photographs.")
            }
            guard attempt == currentAttempt else { return }
            isUnlocked = accepted
            if !accepted { message = "Photos remain locked. Try unlocking again when ready." }
        } catch {
            guard attempt == currentAttempt else { return }
            message = "Photos remain locked. Use Face ID, Touch ID or your device passcode to unlock."
        }
        guard attempt == currentAttempt else { return }
        isAuthenticating = false
        authenticationContext = nil
    }

    func lock() {
        attempt = UUID()
        authenticationContext?.invalidate()
        authenticationContext = nil
        isAuthenticating = false
        isUnlocked = false
        message = nil
    }
}
