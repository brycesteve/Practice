import SwiftUI
import SwiftData
import AVFoundation
import UIKit

struct ProgressCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ProgressPhotoRecord.capturedAt, order: .reverse) private var photos: [ProgressPhotoRecord]
    @StateObject private var camera = ProgressCameraController()
    @AppStorage("progressCameraTimer") private var timerSeconds = 5
    @AppStorage("progressCameraGuide") private var guide = "outline"
    @State private var sessionID = UUID()
    @State private var sessionDate = Date()
    @State private var selectedView: ProgressPhotoView = .front
    @State private var drafts: [ProgressPhotoView: ProgressPhotoDraft] = [:]
    @State private var overlayEnabled = false
    @State private var overlayOpacity = 0.3
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var confirmDiscard = false
    @State private var confirmRetake = false
    @State private var confirmReplaceDraft = false
    @State private var reviewImage: UIImage?
    @State private var previousOverlay: UIImage?
    var existingSession: ProgressPhotoSession?
    var initialView: ProgressPhotoView = .front

    private var previous: ProgressPhotoRecord? {
        photos.first { $0.viewRaw == selectedView.rawValue && $0.deletedAt == nil && $0.sessionID != sessionID }
    }
    private var busy: Bool { countdown != nil || camera.isCapturing || saving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Photographic view", selection: $selectedView) {
                        ForEach(ProgressPhotoView.allCases) { view in
                            Text(drafts[view] == nil ? view.title : "\(view.title) ✓").tag(view)
                        }
                    }.pickerStyle(.segmented).disabled(busy || camera.capturedData != nil)
                    Text("Use the same distance, lighting and pose each time.")
                        .font(.footnote).foregroundStyle(.secondary)
                    ZStack {
                        Color.black
                        if let reviewImage {
                            Image(uiImage: reviewImage).resizable().scaledToFit()
                        } else {
                            ProgressCameraPreview(session: camera.session)
                            if overlayEnabled, let image = previousOverlay {
                                Image(uiImage: image).resizable().scaledToFit().opacity(overlayOpacity)
                            }
                            ProgressAlignmentGuide(style: guide)
                            if let countdown {
                                Text("\(countdown)").font(.system(size: 76, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white).shadow(radius: 6)
                                    .accessibilityLabel("Capture in \(countdown) seconds")
                            }
                        }
                    }
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel(reviewImage == nil ? "Camera preview" : "Photograph review")
                    if camera.capturedData != nil {
                        HStack {
                            Button("Retake") { confirmRetake = true }
                                .buttonStyle(.bordered)
                            Button("Use \(selectedView.title) Photo") {
                                if drafts[selectedView] != nil { confirmReplaceDraft = true }
                                else { acceptPhoto() }
                            }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        captureControls
                    }
                    if !drafts.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(ProgressPhotoView.allCases) { view in
                                if let draft = drafts[view], let image = ProgressPhotoImage.preview(draft.data, maxPixel: 180) {
                                    Button { selectedView = view } label: {
                                        VStack {
                                            Image(uiImage: image).resizable().scaledToFit().frame(height: 70)
                                            Text(view.title).font(.caption)
                                        }
                                    }.disabled(busy || camera.capturedData != nil)
                                }
                            }
                        }
                        Text("Capture any or all views. Photos are saved together when you tap Save.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let message = errorMessage ?? camera.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.red)
                        Button("Retry Camera") { camera.start() }.disabled(busy)
                        if !camera.isReady {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                        }
                    }
                }.padding()
            }
            .navigationTitle(existingSession == nil ? "New Photo Session" : "Update Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelCountdown()
                        if drafts.isEmpty && camera.capturedData == nil { dismiss() }
                        else { confirmDiscard = true }
                    }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(drafts.isEmpty || busy || camera.capturedData != nil)
                }
            }
            .confirmationDialog("Discard these unsaved photographs?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard Photos", role: .destructive) { dismiss() }
            }
            .confirmationDialog("Discard this unsaved photograph and retake it?", isPresented: $confirmRetake, titleVisibility: .visible) {
                Button("Retake Photo", role: .destructive) { camera.capturedData = nil; reviewImage = nil }
                Button("Keep Photo", role: .cancel) {}
            }
            .confirmationDialog("Replace the unsaved photograph for this view?", isPresented: $confirmReplaceDraft, titleVisibility: .visible) {
                Button("Replace Draft", role: .destructive) { acceptPhoto() }
                Button("Keep Earlier Draft", role: .cancel) {}
            }
            .interactiveDismissDisabled(!drafts.isEmpty || camera.capturedData != nil)
            .onAppear {
                if let existingSession { sessionID = existingSession.id; sessionDate = existingSession.date }
                selectedView = initialView
                camera.start()
            }
            .onDisappear { cancelCountdown(); camera.stop() }
            .task(id: previous?.id) {
                previousOverlay = nil
                let bytes = previous?.imageData
                let decoded = await Task.detached(priority: .userInitiated) { ProgressPhotoImage.preview(bytes) }.value
                guard !Task.isCancelled else { return }
                previousOverlay = decoded
            }
            .onChange(of: camera.capturedData) { _, data in reviewImage = ProgressPhotoImage.preview(data) }
            .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.wasInterruptedNotification, object: camera.session)) { _ in
                cancelCountdown()
                camera.errorMessage = "The camera was interrupted. Try again when it becomes available."
            }
            .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.interruptionEndedNotification, object: camera.session)) { _ in
                if scenePhase == .active { camera.start() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.runtimeErrorNotification, object: camera.session)) { _ in
                cancelCountdown()
                camera.errorMessage = "The camera stopped unexpectedly. Tap Retry Camera."
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { camera.start() }
                else { cancelCountdown(); camera.stop() }
            }
        }
        .overlay { if scenePhase != .active { ProgressPrivacyCover() } }
        // The guide and preview use a consistent portrait frame; saved EXIF remains intact.
    }

    private var captureControls: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("Timer", selection: $timerSeconds) {
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                }
                Spacer()
                Button { camera.switchCamera() } label: {
                    Label("Switch camera", systemImage: "arrow.triangle.2.circlepath.camera")
                        .labelStyle(.iconOnly)
                }.buttonStyle(.bordered)
            }.disabled(busy)
            Picker("Alignment guide", selection: $guide) {
                Text("No guide").tag("none")
                Text("Grid").tag("grid")
                Text("Outline").tag("outline")
            }.pickerStyle(.segmented).disabled(busy)
            Toggle("Overlay previous \(selectedView.title.lowercased()) photo", isOn: $overlayEnabled)
                .font(.subheadline).disabled(previous == nil || busy)
            if overlayEnabled && previous != nil {
                Slider(value: $overlayOpacity, in: 0.1...0.7) { Text("Previous photo opacity") }
            }
            if countdown != nil {
                Button("Cancel Timer") { cancelCountdown() }.buttonStyle(.bordered)
            } else {
                Button { beginCountdown() } label: {
                    Label(camera.isCapturing ? "Capturing…" : "Take \(selectedView.title) Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(!camera.isReady || busy)
            }
        }
    }

    private func beginCountdown() {
        errorMessage = nil
        camera.errorMessage = nil
        let seconds = timerSeconds == 10 ? 10 : 5
        countdown = seconds
        countdownTask = Task { @MainActor in
            do {
                for remaining in stride(from: seconds, through: 1, by: -1) {
                    countdown = remaining
                    try await Task.sleep(for: .seconds(1))
                }
                try Task.checkCancellation()
                countdown = nil
                camera.capture()
            } catch { countdown = nil }
        }
    }
    private func cancelCountdown() { countdownTask?.cancel(); countdownTask = nil; countdown = nil }
    private func acceptPhoto() {
        guard let data = camera.capturedData else { return }
        drafts[selectedView] = ProgressPhotoDraft(view: selectedView, data: data)
        camera.capturedData = nil
        reviewImage = nil
        if let next = ProgressPhotoView.allCases.first(where: { drafts[$0] == nil }) { selectedView = next }
    }
    private func save() {
        saving = true
        do {
            try ProgressPhotoStore.save(sessionID: sessionID, date: sessionDate,
                drafts: Array(drafts.values), into: context.container)
            dismiss()
        } catch { errorMessage = error.localizedDescription; saving = false }
    }
}

private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        if let connection = previewLayer.connection {
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
    }
}

private struct ProgressCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        return view
    }
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) { uiView.setNeedsLayout() }
}

private struct ProgressAlignmentGuide: View {
    let style: String
    var body: some View {
        GeometryReader { geometry in
            if style == "grid" {
                Path { path in
                    for fraction in [1.0 / 3, 2.0 / 3] {
                        let x = geometry.size.width * fraction, y = geometry.size.height * fraction
                        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }.stroke(.white.opacity(0.6), lineWidth: 1)
            } else if style == "outline" {
                VStack(spacing: geometry.size.height * 0.025) {
                    Ellipse().stroke(.white.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .frame(width: geometry.size.width * 0.19, height: geometry.size.height * 0.14)
                    RoundedRectangle(cornerRadius: 36)
                        .stroke(.white.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .frame(width: geometry.size.width * 0.43, height: geometry.size.height * 0.66)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
