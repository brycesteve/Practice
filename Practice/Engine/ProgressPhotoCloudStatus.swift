import Foundation
import CloudKit
import CoreData
import CryptoKit
import Observation

/// Read-only verification of SwiftData's mirrored records. Never writes to Core Data's zone.
/// A successful general export event is deliberately not treated as per-photo confirmation.
@MainActor @Observable
final class ProgressPhotoCloudStatus {
    var accountMessage = "Checking iCloud…"
    var verificationMessage: String?
    var lastSyncError: String?
    var isChecking = false
    private(set) var verified: [UUID: Date] = [:]
    private let cloud = CKContainer(identifier: "iCloud.net.stevebryce.practice")

    func refreshAccount() async {
        verified.removeAll()
        verificationMessage = nil
        do {
            switch try await cloud.accountStatus() {
            case .available: accountMessage = "iCloud sync enabled. New photos are saved on this device first."
            case .noAccount: accountMessage = "Sign in to iCloud in Settings to sync. You can still save photos on this device."
            case .restricted: accountMessage = "iCloud is restricted. Photos remain saved on this device."
            case .temporarilyUnavailable: accountMessage = "iCloud is temporarily unavailable. Photos remain saved on this device."
            default: accountMessage = "iCloud is unavailable. Photos remain saved on this device."
            }
        } catch { accountMessage = "iCloud could not be checked. Photos remain saved on this device." }
    }

    func observeSync(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event, event.endDate != nil else { return }
        if let error = event.error {
            lastSyncError = "\(Self.explanation(error)) Your saved photos remain on this device."
        } else if event.succeeded { lastSyncError = nil }
    }

    func verify(_ photos: [ProgressPhotoRecord]) async {
        guard !isChecking else { return }
        isChecking = true
        verificationMessage = nil
        verified.removeAll()
        defer { isChecking = false }
        // Capture immutable inputs before suspension. Verification state is local, never synced.
        let inputs = photos.map { (id: $0.id, hash: $0.contentHash, sessionID: $0.sessionID) }
        do {
            guard try await cloud.accountStatus() == .available else {
                verificationMessage = "iCloud is unavailable. These photographs are not yet verified in iCloud."
                return
            }
            let userID = try await cloud.userRecordID()
            let database = cloud.privateCloudDatabase
            let originals = Dictionary(uniqueKeysWithValues: inputs.map { ($0.id, ($0.sessionID, $0.hash)) })
            var candidates: [CKRecord.ID: UUID] = [:]
            // Core Data mirrors into a custom zone. A database query without a zone
            // searches the default zone and also requires a separately deployed index.
            // Read only metadata through zone changes instead, without query indexes.
            let zones = try await database.allRecordZones()
            for zone in zones where zone.zoneID != CKRecordZone.default().zoneID {
                var token: CKServerChangeToken?
                repeat {
                    try Task.checkCancellation()
                    let page = try await database.recordZoneChanges(inZoneWith: zone.zoneID, since: token,
                        desiredKeys: ["CD_id", "CD_sessionID", "CD_contentHash"], resultsLimit: 200)
                    for (_, result) in page.modificationResultsByID {
                        let record = try result.get().record
                        Self.updateCandidates(&candidates, record: record, originals: originals)
                    }
                    for deletion in page.deletions { candidates.removeValue(forKey: deletion.recordID) }
                    token = page.changeToken
                    if !page.moreComing { break }
                } while true
            }
            var confirmations: [UUID: Date] = [:]
            let keys = ["CD_id", "CD_sessionID", "CD_contentHash", "CD_imageData", "CD_imageData_ckAsset"]
            for (recordID, id) in candidates {
                try Task.checkCancellation()
                guard let original = originals[id] else { continue }
                let results = try await database.records(for: [recordID], desiredKeys: keys)
                guard let result = results[recordID] else { continue }
                let record = try result.get()
                // Reading CKAssets and hashing full originals must not block scrolling.
                let matches = try await Task.detached(priority: .utility) {
                    try Self.matchesOriginal(record, id: id, sessionID: original.0, hash: original.1)
                }.value
                if matches { confirmations[id] = .now }
            }
            // An account switch during the read invalidates all results.
            guard try await cloud.userRecordID() == userID else {
                verified.removeAll()
                verificationMessage = "Your iCloud account changed. Please check again."
                return
            }
            verified = confirmations
            verificationMessage = verified.count == inputs.count
                ? "These original photographs were verified in iCloud just now."
                : "Some photographs are not yet verified in iCloud. Uploads can take time; check again later."
        } catch is CancellationError {
            verified.removeAll()
        } catch {
            verified.removeAll()
            verificationMessage = "\(Self.explanation(error)) Keep this device or export a backup until verification succeeds."
        }
    }

    static func explanation(_ error: Error) -> String {
        let details = error as NSError
        if let partial = details.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
           let underlying = partial.values.first { return explanation(underlying) }
        guard let cloudError = error as? CKError else { return "iCloud could not complete this request. Try again later." }
        switch cloudError.code {
        case .quotaExceeded: return "Your iCloud storage is full. Free up space to resume syncing."
        case .notAuthenticated: return "Sign in to iCloud in Settings to sync your photographs."
        case .networkFailure, .networkUnavailable: return "iCloud is offline. Check your connection and try again."
        case .serviceUnavailable, .requestRateLimited, .zoneBusy: return "iCloud is busy. Try again later."
        case .zoneNotFound, .unknownItem:
            return "These photographs have not reached iCloud yet. Allow sync to finish, then check again."
        case .invalidArguments, .serverRejectedRequest:
            return "iCloud could not read the photo records (\(cloudError.code.rawValue)). The app’s iCloud configuration or schema may need updating."
        case .permissionFailure, .missingEntitlement:
            return "This version of Practice could not access its iCloud photo records. The app’s iCloud configuration needs checking."
        default: return "iCloud could not complete verification (\(cloudError.code.rawValue)). Try again later."
        }
    }
    nonisolated static func updateCandidates(_ candidates: inout [CKRecord.ID: UUID], record: CKRecord,
                                             originals: [UUID: (UUID, String)]) {
        candidates.removeValue(forKey: record.recordID)
        guard record.recordType == "CD_ProgressPhotoRecord",
              let rawID = record["CD_id"] as? String, let id = UUID(uuidString: rawID),
              let original = originals[id],
              (record["CD_sessionID"] as? String)?.lowercased() == original.0.uuidString.lowercased(),
              record["CD_contentHash"] as? String == original.1 else { return }
        candidates[record.recordID] = id
    }

    nonisolated static func matchesOriginal(_ record: CKRecord, id: UUID, sessionID: UUID, hash: String) throws -> Bool {
        guard (record["CD_id"] as? String)?.lowercased() == id.uuidString.lowercased(),
              (record["CD_sessionID"] as? String)?.lowercased() == sessionID.uuidString.lowercased(),
              record["CD_contentHash"] as? String == hash else { return false }
        let bytes: Data?
        if let inline = record["CD_imageData"] as? Data, !inline.isEmpty { bytes = inline }
        else if let url = ((record["CD_imageData_ckAsset"] as? CKAsset) ??
                          (record["CD_imageData"] as? CKAsset))?.fileURL { bytes = try Data(contentsOf: url) }
        else { bytes = nil }
        guard let bytes else { return false }
        return ProgressPhotoImage.hash(bytes) == hash
    }

}
