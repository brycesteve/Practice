import AVFoundation
import Combine
import Foundation

/// All capture-session mutations run on one queue; UI publications return to the main queue.
final class ProgressCameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    @Published private(set) var isReady = false
    @Published private(set) var isCapturing = false
    @Published var errorMessage: String?
    @Published var capturedData: Data?
    private let queue = DispatchQueue(label: "net.stevebryce.practice.progress-camera")
    private let output = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back
    private var wantsRunning = false
    @MainActor private var lifecycleID = UUID()

    @MainActor func start() {
        let requestID = UUID()
        lifecycleID = requestID
        Task { @MainActor in
            let granted: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: granted = true
            case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
            default: granted = false
            }
            guard lifecycleID == requestID else { return }
            guard granted else {
                publishError("Camera access is disabled. Allow Camera access for Practice in Settings.")
                return
            }
            queue.async { [self] in
                wantsRunning = true
                do {
                    if input == nil { try configure(position: position) }
                    if !session.isRunning { session.startRunning() }
                    DispatchQueue.main.async { self.isReady = true; self.errorMessage = nil }
                } catch { publishError(error.localizedDescription) }
            }
        }
    }

    @MainActor func stop() {
        lifecycleID = UUID()
        isReady = false
        queue.async { [self] in
            wantsRunning = false
            if session.isRunning { session.stopRunning() }
            DispatchQueue.main.async { self.isReady = false }
        }
    }

    @MainActor func switchCamera() {
        queue.async { [self] in
            do {
                try configure(position: position == .back ? .front : .back)
            } catch { publishError(error.localizedDescription) }
        }
    }

    private func configure(position newPosition: AVCaptureDevice.Position) throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            throw NSError(domain: "PracticeCamera", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "This camera is unavailable. Use Practice on an iPhone or iPad with a camera."])
        }
        let next = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        let previous = input
        if let previous { session.removeInput(previous) }
        guard session.canAddInput(next) else {
            if let previous, session.canAddInput(previous) { session.addInput(previous) }
            throw NSError(domain: "PracticeCamera", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not start the camera. Please try again."])
        }
        session.addInput(next)
        input = next
        position = newPosition
        if !session.outputs.contains(output), session.canAddOutput(output) { session.addOutput(output) }
        output.maxPhotoQualityPrioritization = .quality
    }

    @MainActor func capture() {
        isCapturing = true
        queue.async { [self] in
            guard wantsRunning, session.isRunning, !session.isInterrupted else {
                publishError("The camera is paused. Return to the capture screen and try again.")
                return
            }
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            if let connection = output.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
            }
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else {
            publishError(error?.localizedDescription ?? "The photograph could not be captured. Please try again.")
            return
        }
        DispatchQueue.main.async {
            self.capturedData = data
            self.isCapturing = false
        }
    }

    private func publishError(_ message: String) {
        DispatchQueue.main.async { self.errorMessage = message; self.isCapturing = false }
    }
}
