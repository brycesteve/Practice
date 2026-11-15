#if DEBUG
import SwiftUI
import SwiftData
import UIKit

/// Preview-only photographs in an isolated memory store. Never accessed by TrainingApp.
@MainActor
private enum ProgressPhotoPreviews {
    static let container: ModelContainer = {
        let schema = Schema(CurrentSchema.models)
        let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        for month in [0, -3] {
            let date = Calendar.current.date(byAdding: .month, value: month, to: .now)!
            let id = UUID()
            let drafts = ProgressPhotoView.allCases.map { view in
                ProgressPhotoDraft(view: view, capturedAt: date, data: sampleImage(earlier: month < 0))
            }
            try! ProgressPhotoStore.save(sessionID: id, date: date, drafts: drafts, into: container)
        }
        return container
    }()
    static func sampleImage(earlier: Bool) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400), format: format)
            .jpegData(withCompressionQuality: 0.9) { context in
                UIColor(white: 0.86, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
                UIColor(white: 0.79, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 320, width: 300, height: 80))
                UIColor(white: 0.35, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: 127, y: 35, width: 46, height: 55)).fill()
                UIBezierPath(roundedRect: CGRect(x: earlier ? 103 : 110, y: 100, width: earlier ? 94 : 80, height: 135), cornerRadius: 24).fill()
                UIBezierPath(roundedRect: CGRect(x: 80, y: 108, width: 19, height: 144), cornerRadius: 9).fill()
                UIBezierPath(roundedRect: CGRect(x: 201, y: 108, width: 19, height: 144), cornerRadius: 9).fill()
                UIBezierPath(roundedRect: CGRect(x: 111, y: 222, width: 31, height: 138), cornerRadius: 12).fill()
                UIBezierPath(roundedRect: CGRect(x: 158, y: 222, width: 31, height: 138), cornerRadius: 12).fill()
            }
    }
}

#Preview("Photo inspector") {
    ProgressPhotoInspector(data: ProgressPhotoPreviews.sampleImage(earlier: false))
        .environment(\.scenePhase, .active)
}

#Preview("Locked progress") {
    ProgressPhotosView().modelContainer(ProgressPhotoPreviews.container)
}

#Preview("Progress timeline") {
    NavigationStack { ProgressPhotoLibraryView() }.modelContainer(ProgressPhotoPreviews.container)
}

#Preview("Photo comparison") {
    let container = ProgressPhotoPreviews.container
    let sessions = try! container.mainContext.fetch(FetchDescriptor<ProgressPhotoSession>())
    let photos = try! container.mainContext.fetch(FetchDescriptor<ProgressPhotoRecord>())
    ProgressComparisonView(sessions: sessions, photos: photos, initialSelection: [])
}
#Preview("Reveal comparison") {
    let container = ProgressPhotoPreviews.container
    let sessions = try! container.mainContext.fetch(FetchDescriptor<ProgressPhotoSession>())
    let photos = try! container.mainContext.fetch(FetchDescriptor<ProgressPhotoRecord>())
    ProgressComparisonView(sessions: sessions, photos: photos, initialSelection: [], initialMode: .reveal)
}

#Preview("Opacity comparison") {
    let container = ProgressPhotoPreviews.container
    let sessions = try! container.mainContext.fetch(FetchDescriptor<ProgressPhotoSession>())
    let photos = try! container.mainContext.fetch(FetchDescriptor<ProgressPhotoRecord>())
    ProgressComparisonView(sessions: sessions, photos: photos, initialSelection: [], initialMode: .overlay)
}
#endif
