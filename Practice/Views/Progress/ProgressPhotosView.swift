import SwiftUI
import SwiftData
import CoreData
import CloudKit
import UIKit

/// Keep the entire navigation and presentation tree behind authentication.
/// Removing it on lock also dismisses inspectors, comparisons and share sheets.
struct ProgressPhotosView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var access = ProgressPhotoAccess()

    var body: some View {
        NavigationStack {
            Group {
                if access.isUnlocked {
                    ProgressPhotoLibraryView()
                } else {
                    ContentUnavailableView {
                        Label("Private Progress Photos", systemImage: "lock.fill")
                    } description: {
                        Text(access.message ?? "Unlock with Face ID, Touch ID or your device passcode to view your photographs.")
                    } actions: {
                        Button("Unlock Photos", systemImage: "faceid") {
                            Task { await access.unlock() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(access.isAuthenticating)
                    }
                    .navigationTitle("Progress")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { access.lock(); dismiss() } }
            }
        }
        .id(access.isUnlocked)
        .privacySensitive()
        .overlay { if scenePhase != .active { ProgressPrivacyCover() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { access.lock() }
        }
    }
}

struct ProgressPhotoLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ProgressPhotoSession.date, order: .reverse) private var sessions: [ProgressPhotoSession]
    @Query(sort: \ProgressPhotoRecord.capturedAt, order: .reverse) private var photos: [ProgressPhotoRecord]
    @State private var cloud = ProgressPhotoCloudStatus()
    @State private var showCapture = false
    @State private var showCompare = false
    @State private var showDeleted = false
    @State private var selectedSessions: Set<UUID> = []
    @State private var export: ProgressPhotoExportPresentation?
    @State private var errorMessage: String?

    /// An image imported ahead of its session remains accessible, including after device replacement.
    private var visibleSessions: [ProgressPhotoSession] {
        let active = photos.filter { $0.deletedAt == nil }
        let known = Set(sessions.map(\.id))
        let recovered = Dictionary(grouping: active.filter { !known.contains($0.sessionID) }, by: \.sessionID)
            .map { id, records in ProgressPhotoSession(id: id, date: records.map(\.capturedAt).min() ?? .now) }
        return (sessions + recovered).filter { session in active.contains { $0.sessionID == session.id } }
            .sorted { $0.date == $1.date ? $0.id.uuidString > $1.id.uuidString : $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Small changes. A longer view.").font(.title2.bold())
                    Text("Private photographs, kept in Practice.").font(.subheadline).foregroundStyle(.secondary)
                    Button { showCapture = true } label: {
                        Label("New Photo Session", systemImage: "camera.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).controlSize(.large).padding(.top, 8)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label(cloud.accountMessage, systemImage: "icloud").font(.footnote)
                    if let error = cloud.lastSyncError { Text(error).font(.footnote).foregroundStyle(.orange) }
                    Text("Keep an independent backup using Export. A local save does not confirm an iCloud copy.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                if visibleSessions.isEmpty {
                    ContentUnavailableView("Your timeline starts here", systemImage: "photo.on.rectangle.angled",
                        description: Text("Take a front, side or back photograph. Use consistent lighting and framing each month."))
                } else {
                    HStack {
                        Text("Timeline").font(.headline)
                        Spacer()
                        Button("Compare\(selectedSessions.isEmpty ? "" : " (\(selectedSessions.count)/2)")") { showCompare = true }
                            .disabled(visibleSessions.count < 2)
                    }
                    ForEach(visibleSessions) { session in
                        sessionCard(session)
                    }
                }
                NavigationLink { BodyStatsView() } label: { Label("Body measurements", systemImage: "ruler") }
                Button { showDeleted = true } label: {
                    Label("Recently Deleted (\(photos.filter { $0.deletedAt != nil }.count))", systemImage: "trash")
                }
            }.padding()
        }
        .navigationTitle("Progress")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Export", systemImage: "square.and.arrow.up") { exportAll() }.disabled(photos.isEmpty)
            }
        }
        .fullScreenCover(isPresented: $showCapture) { ProgressCaptureView() }
        .sheet(isPresented: $showCompare) {
            ProgressComparisonView(sessions: visibleSessions, photos: photos,
                initialSelection: Array(selectedSessions))
        }
        .sheet(isPresented: $showDeleted) { ProgressDeletedView() }
        .sheet(item: $export) { export in
            ProgressShareSheet(url: export.url)
                .onDisappear { export.cleanUp() }
        }
        .alert("Progress", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .task { await cloud.refreshAccount() }
        .onReceive(NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)) { cloud.observeSync($0) }
        .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in Task { await cloud.refreshAccount() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await cloud.refreshAccount() } } }
        .overlay { if scenePhase != .active { ProgressPrivacyCover() } }
    }

    private func sessionCard(_ session: ProgressPhotoSession) -> some View {
        let current = ProgressPhotoStore.currentPhotos(photos, sessionID: session.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                NavigationLink {
                    ProgressSessionDetailView(session: session)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.date, format: .dateTime.day().month(.wide).year()).font(.headline)
                        Text("\(current.count) \(current.count == 1 ? "view" : "views") · Saved in Practice")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                Button {
                    if selectedSessions.contains(session.id) { selectedSessions.remove(session.id) }
                    else if selectedSessions.count < 2 { selectedSessions.insert(session.id) }
                } label: {
                    Image(systemName: selectedSessions.contains(session.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                }
                .accessibilityLabel("Select \(session.date.formatted(date: .abbreviated, time: .omitted)) for comparison")
                .accessibilityAddTraits(selectedSessions.contains(session.id) ? .isSelected : [])
                .disabled(selectedSessions.count == 2 && !selectedSessions.contains(session.id))
            }
            NavigationLink { ProgressSessionDetailView(session: session) } label: {
                HStack(spacing: 10) {
                    ForEach(current) { photo in
                        VStack(spacing: 5) {
                            ProgressPhotoDisplay(data: photo.thumbnailData, maxPixel: 360)
                                .frame(height: 140).frame(maxWidth: .infinity)
                                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                            Text(ProgressPhotoView(rawValue: photo.viewRaw)?.title ?? photo.viewRaw).font(.caption)
                        }
                    }
                }
            }.buttonStyle(.plain)
        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
    private func exportAll() {
        do { export = ProgressPhotoExportPresentation(url: try ProgressPhotoBackup.prepare(photos: photos, sessions: sessions)) }
        catch { errorMessage = error.localizedDescription }
    }
}

struct ProgressSessionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var photos: [ProgressPhotoRecord]
    @State private var cloud = ProgressPhotoCloudStatus()
    @State private var selectedView: ProgressPhotoView = .front
    @State private var showCapture = false
    @State private var deleteID: UUID?
    @State private var inspection: ProgressPhotoInspection?
    @State private var errorMessage: String?
    let session: ProgressPhotoSession
    private var current: [ProgressPhotoRecord] { ProgressPhotoStore.currentPhotos(photos, sessionID: session.id) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(current) { photo in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(ProgressPhotoView(rawValue: photo.viewRaw)?.title ?? photo.viewRaw).font(.headline)
                        ProgressPhotoDisplay(data: photo.imageData)
                            .frame(maxWidth: .infinity).aspectRatio(3.0 / 4, contentMode: .fit)
                            .background(.black, in: RoundedRectangle(cornerRadius: 16))
                            .onTapGesture {
                                if let data = photo.imageData { inspection = ProgressPhotoInspection(data: data) }
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("Inspect \(photo.viewRaw) photograph. Double tap to open.")
                        if photo.imageData == nil {
                            Label("Original unavailable on this device. Allow iCloud to finish downloading, then reopen this session.", systemImage: "icloud.and.arrow.down")
                                .font(.caption).foregroundStyle(.secondary)
                        } else if let date = cloud.verified[photo.id] {
                            Label("Verified in iCloud \(date.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.icloud")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Label("Saved in Practice · iCloud copy not verified", systemImage: "internaldrive")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        HStack {
                            Button("Replace") {
                                selectedView = ProgressPhotoView(rawValue: photo.viewRaw) ?? .front
                                showCapture = true
                            }.buttonStyle(.bordered)
                            Spacer()
                            Button("Delete", role: .destructive) { deleteID = photo.id }
                        }
                    }
                }
                let currentIDs = Set(current.map(\.id))
                let otherCaptures = photos.filter { $0.sessionID == session.id && $0.deletedAt == nil && !currentIDs.contains($0.id) }
                if !otherCaptures.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Other captures").font(.headline)
                        Text("These views were also captured for this session. Choose which photograph to use.")
                            .font(.footnote).foregroundStyle(.secondary)
                        ForEach(otherCaptures) { photo in
                            HStack {
                                ProgressPhotoDisplay(data: photo.thumbnailData, maxPixel: 180).frame(width: 65, height: 85)
                                Text(ProgressPhotoView(rawValue: photo.viewRaw)?.title ?? photo.viewRaw)
                                Spacer()
                                Button("Use This Photo") {
                                    do { try ProgressPhotoStore.setDeleted(photo.id, deleted: false, in: context.container) }
                                    catch { errorMessage = error.localizedDescription }
                                }.buttonStyle(.bordered)
                            }
                        }
                    }
                }
                Button { showCapture = true } label: { Label("Add or Retake Views", systemImage: "camera") }
                Button {
                    Task { await cloud.verify(current) }
                } label: {
                    if cloud.isChecking { ProgressView("Checking originals in iCloud…") }
                    else { Label("Verify iCloud Copies", systemImage: "icloud.and.arrow.down") }
                }.buttonStyle(.bordered).disabled(cloud.isChecking || current.isEmpty)
                if let message = cloud.verificationMessage { Text(message).font(.footnote).foregroundStyle(.secondary) }
                Text("Replaced and deleted photographs remain in Recently Deleted until you permanently delete them.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .omitted))
        .fullScreenCover(item: $inspection) { inspection in
            ProgressPhotoInspector(data: inspection.data)
        }
        .fullScreenCover(isPresented: $showCapture) { ProgressCaptureView(existingSession: session, initialView: selectedView) }
        .confirmationDialog("Move this photograph to Recently Deleted?", isPresented: Binding(
            get: { deleteID != nil }, set: { if !$0 { deleteID = nil } }), titleVisibility: .visible) {
            Button("Delete Photo", role: .destructive) {
                guard let id = deleteID else { return }
                do { try ProgressPhotoStore.setDeleted(id, deleted: true, in: context.container) }
                catch { errorMessage = error.localizedDescription }
                deleteID = nil
            }
        }
        .alert("Couldn’t Update Photograph", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in Task { await cloud.refreshAccount() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await cloud.refreshAccount() } } }
        .overlay { if scenePhase != .active { ProgressPrivacyCover() } }
    }
}

struct ProgressDeletedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ProgressPhotoRecord.capturedAt, order: .reverse) private var photos: [ProgressPhotoRecord]
    @State private var permanentID: UUID?
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Photographs stay here until you permanently delete them. Restoring a view moves its current replacement here.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(photos.filter { $0.deletedAt != nil }) { photo in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ProgressPhotoDisplay(data: photo.thumbnailData, maxPixel: 180).frame(width: 65, height: 85)
                            VStack(alignment: .leading) {
                                Text(ProgressPhotoView(rawValue: photo.viewRaw)?.title ?? photo.viewRaw).font(.headline)
                                Text(photo.capturedAt, style: .date).font(.caption)
                            }
                        }
                        HStack {
                            Button("Restore") {
                                do { try ProgressPhotoStore.setDeleted(photo.id, deleted: false, in: context.container) }
                                catch { errorMessage = error.localizedDescription }
                            }.buttonStyle(.bordered)
                            Spacer()
                            Button("Delete Permanently", role: .destructive) { permanentID = photo.id }.buttonStyle(.bordered)
                        }
                    }.padding(.vertical, 6)
                }
            }.navigationTitle("Recently Deleted")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Permanently delete this photograph from Practice and iCloud? This cannot be undone.",
                    isPresented: Binding(get: { permanentID != nil }, set: { if !$0 { permanentID = nil } }), titleVisibility: .visible) {
                    Button("Delete Permanently", role: .destructive) {
                        guard let id = permanentID else { return }
                        do { try ProgressPhotoStore.permanentlyDelete(id, in: context.container) }
                        catch { errorMessage = error.localizedDescription }
                        permanentID = nil
                    }
                }
                .alert("Couldn’t Update Photograph", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                    Button("OK") { errorMessage = nil }
                } message: { Text(errorMessage ?? "") }
        }.overlay { if scenePhase != .active { ProgressPrivacyCover() } }
    }
}

struct ProgressPhotoDisplay: View {
    let data: Data?
    var maxPixel = 1400
    @State private var image: UIImage?
    @State private var loaded = false
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else if loaded {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                    Text("Image unavailable").font(.caption)
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .privacySensitive()
        .task(id: data) {
            loaded = false
            image = nil
            let bytes = data, limit = maxPixel
            let decoded = await Task.detached(priority: .userInitiated) { ProgressPhotoImage.preview(bytes, maxPixel: limit) }.value
            guard !Task.isCancelled else { return }
            image = decoded
            loaded = true
        }
    }
}

struct ProgressPrivacyCover: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            Label("Private Progress Photos", systemImage: "lock.fill").foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProgressShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.excludedActivityTypes = [.saveToCameraRoll]
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
