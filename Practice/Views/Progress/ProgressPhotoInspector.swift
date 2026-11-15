import SwiftUI
import UIKit

struct ProgressPhotoInspector: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let data: Data
    @State private var image: UIImage?
    @State private var loaded = false
    var body: some View {
        NavigationStack {
            Group {
                if let image { ProgressZoomImage(image: image).ignoresSafeArea(edges: .bottom) }
                else if loaded {
                    ContentUnavailableView("Image unavailable", systemImage: "photo.badge.exclamationmark",
                        description: Text("Allow iCloud to finish downloading the original and try again."))
                } else { ProgressView("Opening photograph…") }
            }
            .navigationTitle("Photograph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                let bytes = data
                let decoded = await Task.detached(priority: .userInitiated) { ProgressPhotoImage.preview(bytes, maxPixel: 3000) }.value
                guard !Task.isCancelled else { return }
                image = decoded
                loaded = true
            }
        }
        .privacySensitive()
        .overlay { if scenePhase != .active { ProgressPrivacyCover() } }
    }
}

final class ProgressZoomScrollView: UIScrollView {
    let photoView = UIImageView()
    private var fittedSize = CGSize.zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image = photoView.image, bounds.width > 0, bounds.height > 0 else { return }
        // Configure the canvas only when the viewport changes. Updating its frame and
        // contentSize on every layout feeds scroll/zoom changes back into layout.
        if bounds.size != fittedSize {
            fittedSize = bounds.size
            minimumZoomScale = 0.001
            maximumZoomScale = 100
            zoomScale = 1
            photoView.frame = CGRect(origin: .zero, size: image.size)
            contentSize = image.size
            let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
            minimumZoomScale = fit
            maximumZoomScale = fit * 5
            zoomScale = fit
        }
        let vertical = max(0, (bounds.height - photoView.frame.height) / 2)
        let horizontal = max(0, (bounds.width - photoView.frame.width) / 2)
        let inset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        if contentInset != inset { contentInset = inset }
    }
}

private struct ProgressZoomImage: UIViewRepresentable {
    let image: UIImage
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ProgressZoomScrollView {
        let scroll = ProgressZoomScrollView()
        scroll.backgroundColor = .black
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 5
        scroll.bouncesZoom = true
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.delegate = context.coordinator
        scroll.photoView.image = image
        scroll.photoView.contentMode = .scaleAspectFit
        scroll.addSubview(scroll.photoView)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(tap)
        return scroll
    }
    func updateUIView(_ uiView: ProgressZoomScrollView, context: Context) { uiView.photoView.image = image }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { (scrollView as? ProgressZoomScrollView)?.photoView }
        @objc func doubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scroll = recognizer.view as? ProgressZoomScrollView else { return }
            scroll.setZoomScale(scroll.zoomScale > scroll.minimumZoomScale
                ? scroll.minimumZoomScale : scroll.minimumZoomScale * 2.5, animated: true)
        }
    }
}
