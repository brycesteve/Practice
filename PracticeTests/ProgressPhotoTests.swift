import Foundation
import Testing
import SwiftData
import UIKit
import ImageIO
import CloudKit
import UserNotifications
import LocalAuthentication
import SwiftUI
@testable import Practice

@Suite("Private progress photographs")
@MainActor
struct ProgressPhotoTests {
    @Test func verificationFindsCustomZoneMetadataWithoutAnIndexAndRejectsMismatches() {
        let id = UUID(), sessionID = UUID()
        let recordID = CKRecord.ID(recordName: "server-capture", zoneID: .init(zoneName: "mirror-zone"))
        let record = CKRecord(recordType: "CD_ProgressPhotoRecord", recordID: recordID)
        record["CD_id"] = id.uuidString.lowercased()
        record["CD_sessionID"] = sessionID.uuidString
        record["CD_contentHash"] = "expected-hash"
        var candidates: [CKRecord.ID: UUID] = [:]
        let originals = [id: (sessionID, "expected-hash")]
        ProgressPhotoCloudStatus.updateCandidates(&candidates, record: record, originals: originals)
        #expect(candidates[recordID] == id)
        record["CD_contentHash"] = "different-hash"
        ProgressPhotoCloudStatus.updateCandidates(&candidates, record: record, originals: originals)
        #expect(candidates.isEmpty)
        record["CD_contentHash"] = "expected-hash"
        record["CD_sessionID"] = UUID().uuidString
        ProgressPhotoCloudStatus.updateCandidates(&candidates, record: record, originals: originals)
        #expect(candidates.isEmpty)
    }

    @Test func partialCloudErrorsExplainTheUnderlyingProblem() {
        let error = NSError(domain: CKErrorDomain, code: CKError.Code.partialFailure.rawValue,
            userInfo: [CKPartialErrorsByItemIDKey: ["photo": CKError(.quotaExceeded)]])
        #expect(ProgressPhotoCloudStatus.explanation(error).contains("storage is full"))
        #expect(ProgressPhotoCloudStatus.explanation(CKError(.zoneNotFound)).contains("not reached iCloud yet"))
        #expect(ProgressPhotoCloudStatus.explanation(CKError(.missingEntitlement)).contains("configuration"))
    }

    private func container() throws -> ModelContainer {
        let schema = Schema(CurrentSchema.models)
        return try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }
    private func image(_ color: UIColor = .blue) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 24, height: 40), format: format).jpegData(withCompressionQuality: 0.9) { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 40))
        }
    }
    private func records(_ container: ModelContainer) throws -> [ProgressPhotoRecord] {
        try ModelContext(container).fetch(FetchDescriptor<ProgressPhotoRecord>())
    }

    @Test func repeatSaveIsIdempotentAndPreservesOriginalBytes() throws {
        let store = try container(), session = UUID()
        let data = image()
        let draft = ProgressPhotoDraft(view: .front, data: data)
        try ProgressPhotoStore.save(sessionID: session, date: .now, drafts: [draft], into: store)
        try ProgressPhotoStore.save(sessionID: session, date: .now, drafts: [draft], into: store)
        let photos = try records(store)
        let photo = try #require(photos.first)
        #expect(photos.count == 1)
        #expect(photo.imageData == data)
        #expect(photo.contentHash == ProgressPhotoImage.hash(data))
        #expect(photo.pixelWidth == 24 && photo.pixelHeight == 40)
        #expect(photo.thumbnailData != nil)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<ProgressPhotoSession>()) == 1)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<WorkoutRecord>()) == 0)
    }

    @Test func replacementDeletionAndRestoreRetainOriginals() throws {
        let store = try container(), session = UUID()
        let first = ProgressPhotoDraft(view: .front, data: image(.red))
        let second = ProgressPhotoDraft(view: .front, data: image(.green))
        let side = ProgressPhotoDraft(view: .side, data: image(.blue))
        try ProgressPhotoStore.save(sessionID: session, date: .now, drafts: [first, side], into: store)
        try ProgressPhotoStore.save(sessionID: session, date: .now, drafts: [second], into: store)
        var photos = try records(store)
        #expect(photos.count == 3)
        #expect(photos.first { $0.id == first.id }?.deletedAt != nil)
        #expect(Set(ProgressPhotoStore.currentPhotos(photos, sessionID: session).map(\.id)) == [second.id, side.id])
        try ProgressPhotoStore.setDeleted(first.id, deleted: false, in: store)
        photos = try records(store)
        #expect(photos.first { $0.id == second.id }?.deletedAt != nil)
        #expect(photos.first { $0.id == first.id }?.imageData == first.data)
        try ProgressPhotoStore.setDeleted(first.id, deleted: true, in: store)
        try ProgressPhotoStore.setDeleted(first.id, deleted: false, in: store)
        #expect(try records(store).first { $0.id == first.id }?.deletedAt == nil)
        try ProgressPhotoStore.permanentlyDelete(second.id, in: store)
        #expect(try records(store).count == 2)
        #expect(throws: ProgressPhotoError.self) { try ProgressPhotoStore.permanentlyDelete(first.id, in: store) }
    }

    @Test func invalidBatchCannotPartiallySaveOrReplaceExistingPhotos() throws {
        let store = try container(), session = UUID()
        let original = ProgressPhotoDraft(view: .front, data: image())
        try ProgressPhotoStore.save(sessionID: session, date: .now, drafts: [original], into: store)
        #expect(throws: ProgressPhotoError.self) {
            try ProgressPhotoStore.save(sessionID: session, date: .now, drafts: [
                .init(view: .front, data: image(.red)), .init(view: .back, data: Data([0, 1, 2]))], into: store)
        }
        let all = try records(store)
        #expect(all.count == 1)
        #expect(all.first?.deletedAt == nil)
        #expect(all.first?.id == original.id)
    }

    @Test func reusedIdentityWithDifferentBytesCannotOverwriteOriginal() throws {
        let store = try container(), session = UUID(), id = UUID()
        let original = ProgressPhotoDraft(id: id, view: .front, data: image())
        try ProgressPhotoStore.save(sessionID: session, date: .now, drafts: [original], into: store)
        #expect(throws: ProgressPhotoError.self) {
            try ProgressPhotoStore.save(sessionID: session, date: .now,
                drafts: [.init(id: id, view: .front, data: image(.red))], into: store)
        }
        #expect(try records(store).first?.imageData == original.data)
        #expect(try records(store).count == 1)
    }

    @Test func originalExifOrientationAndAspectRatioSurvive() throws {
        let bytes = image()
        let source = try #require(CGImageSourceCreateWithData(bytes as CFData, nil))
        let rotated = NSMutableData()
        let output = try #require(CGImageDestinationCreateWithData(rotated, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImageFromSource(output, source, 0, [kCGImagePropertyOrientation: 6] as CFDictionary)
        #expect(CGImageDestinationFinalize(output))
        let data = rotated as Data
        let info = try ProgressPhotoImage.properties(data)
        #expect(info.width == 40 && info.height == 24)
        let preview = try #require(ProgressPhotoImage.preview(data))
        #expect(preview.size.width > preview.size.height)
        let store = try container()
        try ProgressPhotoStore.save(sessionID: UUID(), date: .now, drafts: [.init(view: .back, data: data)], into: store)
        #expect(try records(store).first?.imageData == data)
    }

    @Test func cloudConfirmationRequiresMatchingIdentityAndActualOriginalBytes() throws {
        let id = UUID(), session = UUID(), bytes = image()
        let hash = ProgressPhotoImage.hash(bytes)
        let record = CKRecord(recordType: "CD_ProgressPhotoRecord")
        record["CD_id"] = id.uuidString
        record["CD_sessionID"] = session.uuidString
        record["CD_contentHash"] = hash
        #expect(try !ProgressPhotoCloudStatus.matchesOriginal(record, id: id, sessionID: session, hash: hash))
        record["CD_imageData"] = image(.red)
        #expect(try !ProgressPhotoCloudStatus.matchesOriginal(record, id: id, sessionID: session, hash: hash))
        record["CD_imageData"] = bytes
        #expect(try ProgressPhotoCloudStatus.matchesOriginal(record, id: id, sessionID: session, hash: hash))
        #expect(try !ProgressPhotoCloudStatus.matchesOriginal(record, id: UUID(), sessionID: session, hash: hash))
        record["CD_imageData"] = Data()
        let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try bytes.write(to: url)
        record["CD_imageData_ckAsset"] = CKAsset(fileURL: url)
        #expect(try ProgressPhotoCloudStatus.matchesOriginal(record, id: id, sessionID: session, hash: hash))
    }

    @Test func exportProducesZipAndFailsWhenAnOriginalIsMissing() throws {
        let store = try container(), session = UUID()
        try ProgressPhotoStore.save(sessionID: session, date: .now, drafts: [.init(view: .front, data: image())], into: store)
        let photos = try records(store)
        let sessions = try store.mainContext.fetch(FetchDescriptor<ProgressPhotoSession>())
        let url = try ProgressPhotoBackup.prepare(photos: photos, sessions: sessions)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        #expect(url.pathExtension == "zip")
        #expect(data.starts(with: [0x50, 0x4b]))
        photos[0].imageData = nil
        #expect(throws: ProgressPhotoError.self) { try ProgressPhotoBackup.prepare(photos: photos, sessions: sessions) }
    }

    @Test func v3MigrationAndDiskReopenPreserveTrainingAndPhotographs() throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("migration.store")
        let workoutID = try makeV3Store(at: url)
        let draft = ProgressPhotoDraft(view: .back, data: try largeImage())
        #expect(draft.data.count > 1_000_000)
        let sessionID = UUID()
        try migrateAndSave(url: url, workoutID: workoutID, sessionID: sessionID, draft: draft)
        let schema = Schema(CurrentSchema.models)
        let reopened = try ModelContainer(for: schema, migrationPlan: TrainingMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let photo = try #require(records(reopened).first)
        #expect(photo.id == draft.id)
        #expect(photo.imageData == draft.data)
        #expect(photo.sessionID == sessionID)
        let settings = try #require(reopened.mainContext.fetch(FetchDescriptor<AppSettings>()).first)
        #expect(settings.currentSwingWeightKg == 28)
        #expect(settings.eveningRotationDay == 2)
        #expect(try reopened.mainContext.fetchCount(FetchDescriptor<WaistMeasurementRecord>()) == 1)
        let workout = try #require(reopened.mainContext.fetch(FetchDescriptor<WorkoutRecord>()).first)
        #expect(workout.id == workoutID)
        let set = try #require(workout.toCompletedWorkout().exercises.first?.sets.first)
        #expect(set.weightKg == 20 && set.peakHeartRate == 130)
    }
    /// Noise keeps the JPEG above the inline-storage threshold, exercising external files.
    private func largeImage() throws -> Data {
        let width = 1000, height = 1300
        var seed: UInt64 = 12345
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for index in pixels.indices where index % 4 != 3 {
            seed = seed &* 6364136223846793005 &+ 1
            pixels[index] = UInt8(truncatingIfNeeded: seed >> 32)
        }
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        return try #require(UIImage(cgImage: image).jpegData(compressionQuality: 1))
    }

    @Test func concurrentViewsChooseOneDeterministicPhotoWithoutDiscardingOthers() throws {
        let store = try container(), sessionID = UUID(), time = Date()
        try ProgressPhotoStore.save(sessionID: sessionID, date: time,
            drafts: [.init(view: .front, capturedAt: time, data: image())], into: store)
        let original = try #require(records(store).first)
        let context = ModelContext(store)
        context.insert(ProgressPhotoRecord(id: UUID(), sessionID: sessionID, capturedAt: time,
            viewRaw: "front", imageData: original.imageData!, thumbnailData: original.thumbnailData!,
            contentHash: original.contentHash, pixelWidth: 24, pixelHeight: 40, fileExtension: "jpg"))
        try context.save()
        let all = try records(store)
        #expect(all.count == 2)
        let expected = all.map(\.id.uuidString).max()
        #expect(ProgressPhotoStore.currentPhotos(all, sessionID: sessionID).first?.id.uuidString == expected)
        #expect(ProgressPhotoStore.currentPhotos(all.reversed(), sessionID: sessionID).count == 1)
        #expect(all.allSatisfy { $0.imageData != nil && $0.deletedAt == nil })
    }

    private func makeV3Store(at url: URL) throws -> UUID {
        let schema = Schema(TrainingSchemaV3.models)
        let store = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let settings = AppSettings()
        settings.currentSwingWeightKg = 28; settings.eveningRotationDay = 2
        let workout = CompletedWorkout(sessionType: .strengthA, startDate: .now, endDate: .now,
            exercises: [.init(exerciseID: UUID(), exerciseName: "Recorded strength", sets: [.init(reps: 5, weightKg: 20, peakHeartRate: 130)])])
        store.mainContext.insert(settings)
        store.mainContext.insert(try WaistMeasurementRecord(circumferenceCm: 85))
        store.mainContext.insert(WorkoutRecord(from: workout))
        try store.mainContext.save()
        return workout.id
    }
    private func migrateAndSave(url: URL, workoutID: UUID, sessionID: UUID, draft: ProgressPhotoDraft) throws {
        let schema = Schema(CurrentSchema.models)
        let store = try ModelContainer(for: schema, migrationPlan: TrainingMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        #expect(try store.mainContext.fetch(FetchDescriptor<WorkoutRecord>()).first?.id == workoutID)
        try ProgressPhotoStore.save(sessionID: sessionID, date: .now, drafts: [draft], into: store)
    }
}

@Suite("Progress reminder schedules")
struct ProgressReminderTests {
    @Test func weeklyWaistAndMonthlyPhotosUseCalendarSchedules() throws {
        let weekly = try NotificationManager.progressReminderComponents(.waist, day: 2, hour: 8, minute: 15)
        #expect(weekly.weekday == 2 && weekly.day == nil && weekly.hour == 8 && weekly.minute == 15)
        let monthly = try NotificationManager.progressReminderComponents(.photos, day: 28, hour: 9, minute: 30)
        #expect(monthly.day == 28 && monthly.weekday == nil && monthly.hour == 9 && monthly.minute == 30)
        #expect(UNCalendarNotificationTrigger(dateMatching: monthly, repeats: true).nextTriggerDate() != nil)
        #expect(NotificationManager.ProgressReminder.waist.identifier != NotificationManager.ProgressReminder.photos.identifier)
        #expect(throws: CocoaError.self) { try NotificationManager.progressReminderComponents(.photos, day: 31, hour: 9, minute: 0) }
        #expect(throws: CocoaError.self) { try NotificationManager.progressReminderComponents(.waist, day: 0, hour: 9, minute: 0) }
    }
}

@Suite("Progress photo privacy and presentation", .serialized)
@MainActor
struct ProgressPhotoPresentationTests {
    @Test func photographsStartLockedAndCanBeRelockedAfterAuthentication() async {
        var requests = 0
        let access = ProgressPhotoAccess(authenticate: { requests += 1; return true })
        #expect(!access.isUnlocked)
        await access.unlock()
        #expect(access.isUnlocked && requests == 1)
        await access.unlock()
        #expect(requests == 1)
        access.lock()
        #expect(!access.isUnlocked && !access.isAuthenticating)
        await access.unlock()
        #expect(access.isUnlocked && requests == 2)
    }

    @Test func cancellationNeverRevealsPhotographs() async {
        let access = ProgressPhotoAccess(authenticate: { throw LAError(.userCancel) })
        await access.unlock()
        #expect(!access.isUnlocked && !access.isAuthenticating)
        #expect(access.message != nil)
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") as? String != nil)
    }

    @Test func backgroundLockInvalidatesAnAuthenticationAlreadyInFlight() async {
        var continuation: CheckedContinuation<Bool, any Error>?
        let access = ProgressPhotoAccess(authenticate: {
            try await withCheckedThrowingContinuation { continuation = $0 }
        })
        let authentication = Task { await access.unlock() }
        while continuation == nil { await Task.yield() }
        #expect(access.isAuthenticating)
        access.lock()
        continuation?.resume(returning: true)
        await authentication.value
        #expect(!access.isUnlocked && !access.isAuthenticating)
    }

    @Test func photoCanvasKeepsItsSizeAndZoomAcrossRepeatedLayoutsAndPanning() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
        }
        let scroll = ProgressZoomScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let delegate = ZoomDelegate()
        scroll.delegate = delegate
        scroll.photoView.image = image
        scroll.addSubview(scroll.photoView)
        scroll.layoutIfNeeded()
        let fitted = scroll.minimumZoomScale
        #expect(abs(fitted - 1.3) < 0.001)
        scroll.setZoomScale(fitted * 2, animated: false)
        let canvas = scroll.photoView.frame
        for _ in 0..<100 { scroll.setNeedsLayout(); scroll.layoutIfNeeded() }
        #expect(abs(scroll.zoomScale - fitted * 2) < 0.001)
        #expect(scroll.photoView.frame == canvas)
        scroll.contentOffset = CGPoint(x: 60, y: 50)
        scroll.layoutIfNeeded()
        #expect(scroll.photoView.frame == canvas)
        scroll.frame.size = CGSize(width: 700, height: 390)
        scroll.setNeedsLayout()
        scroll.layoutIfNeeded()
        #expect(abs(scroll.minimumZoomScale - 0.975) < 0.001)
        #expect(scroll.zoomScale == scroll.minimumZoomScale)
    }

    @Test func inspectorAndSharePresentationsAlwaysContainTheirContent() throws {
        let bytes = Data([1, 2, 3])
        let inspection = ProgressPhotoInspection(data: bytes)
        #expect(inspection.data == bytes)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        try bytes.write(to: url)
        let export = ProgressPhotoExportPresentation(url: url)
        #expect(FileManager.default.fileExists(atPath: export.url.path))
        export.cleanUp()
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func dashboardHasScrollableContentImmediatelyWithAnIsolatedStore() async throws {
        let store = try ModelContainer(for: Schema(CurrentSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let controller = UIHostingController(rootView: DashboardView().modelContainer(store))
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousKeyWindow?.makeKey() }
        try await Task.sleep(for: .milliseconds(100))
        controller.view.layoutIfNeeded()
        func scrollView(in view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
        }
        let scroll = try #require(scrollView(in: controller.view))
        #expect(scroll.isScrollEnabled)
        #expect(scroll.contentSize.height > scroll.bounds.height)
        scroll.setContentOffset(CGPoint(x: 0, y: 100), animated: false)
        #expect(scroll.contentOffset.y == 100)
    }

    private final class ZoomDelegate: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ProgressZoomScrollView)?.photoView
        }
    }
}
