import SwiftUI

struct ProgressComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let sessions: [ProgressPhotoSession]
    let photos: [ProgressPhotoRecord]
    @State private var beforeID: UUID
    @State private var afterID: UUID
    @State private var view: ProgressPhotoView = .front
    @State private var mode = Mode.sideBySide
    @State private var reveal = 0.5
    @State private var opacity = 0.5

    enum Mode: String, CaseIterable, Identifiable {
        case sideBySide = "Side by Side", reveal = "Reveal", overlay = "Overlay"
        var id: String { rawValue }
    }

    init(sessions: [ProgressPhotoSession], photos: [ProgressPhotoRecord], initialSelection: [UUID], initialMode: Mode = .sideBySide) {
        self.sessions = sessions
        self.photos = photos
        _mode = State(initialValue: initialMode)
        let selected = sessions.filter { initialSelection.contains($0.id) }.sorted { $0.date < $1.date }
        let ordered = sessions.sorted { $0.date < $1.date }
        let before = selected.first?.id ?? ordered.first?.id ?? UUID()
        let after = selected.count > 1 ? selected.last!.id : ordered.last?.id ?? UUID()
        _beforeID = State(initialValue: before)
        _afterID = State(initialValue: after)
        let beforeViews = Set(ProgressPhotoStore.currentPhotos(photos, sessionID: before).map(\.viewRaw))
        let afterViews = Set(ProgressPhotoStore.currentPhotos(photos, sessionID: after).map(\.viewRaw))
        _view = State(initialValue: ProgressPhotoView.allCases.first { beforeViews.contains($0.rawValue) && afterViews.contains($0.rawValue) } ?? .front)
    }

    private func photo(_ sessionID: UUID) -> ProgressPhotoRecord? {
        ProgressPhotoStore.currentPhotos(photos, sessionID: sessionID).first { $0.viewRaw == view.rawValue }
    }
    private func date(_ id: UUID) -> String {
        sessions.first { $0.id == id }?.date.formatted(date: .abbreviated, time: .omitted) ?? "Session unavailable"
    }
    private var commonViews: [ProgressPhotoView] {
        let before = Set(ProgressPhotoStore.currentPhotos(photos, sessionID: beforeID).map(\.viewRaw))
        let after = Set(ProgressPhotoStore.currentPhotos(photos, sessionID: afterID).map(\.viewRaw))
        return ProgressPhotoView.allCases.filter { before.contains($0.rawValue) && after.contains($0.rawValue) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack {
                        sessionPicker("Before", selection: $beforeID)
                        sessionPicker("After", selection: $afterID)
                    }
                    Picker("Photographic view", selection: $view) {
                        ForEach(ProgressPhotoView.allCases) { item in Text(item.title).tag(item) }
                    }.pickerStyle(.segmented)
                    Picker("Comparison", selection: $mode) {
                        ForEach(Mode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                    }.pickerStyle(.segmented)
                    if beforeID == afterID {
                        ContentUnavailableView("Choose two sessions", systemImage: "calendar",
                            description: Text("Select different dates to compare your progress."))
                    } else if let before = photo(beforeID), let after = photo(afterID) {
                        comparison(before: before, after: after)
                        HStack {
                            Text(date(beforeID))
                            Spacer()
                            Text(date(afterID))
                        }.font(.caption).foregroundStyle(.secondary)
                        if mode == .reveal {
                            Slider(value: $reveal, in: 0...1) { Text("Before and after reveal") }
                            Text("Drag the divider to reveal each photograph.").font(.footnote).foregroundStyle(.secondary)
                        } else if mode == .overlay {
                            Slider(value: $opacity, in: 0...1) { Text("After photograph opacity") }
                            Text("After photo opacity: \(Int(opacity * 100))%")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Text("Original proportions are preserved. Differences in pose and camera distance can affect comparison.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView("This view is missing", systemImage: "photo.on.rectangle",
                            description: Text("Both sessions need a \(view.title.lowercased()) photograph. Choose another view or add one to the session."))
                    }
                }.padding()
            }.navigationTitle("Compare Photos")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onChange(of: beforeID) { selectCommonView() }
                .onChange(of: afterID) { selectCommonView() }
        }.overlay { if scenePhase != .active { ProgressPrivacyCover() } }
    }
    private func selectCommonView() {
        if !commonViews.contains(view), let first = commonViews.first { view = first }
    }
    private func sessionPicker(_ label: String, selection: Binding<UUID>) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Picker(label, selection: selection) {
                ForEach(sessions) { session in
                    Text(session.date, format: .dateTime.day().month(.abbreviated).year().hour().minute()).tag(session.id)
                }
            }.labelsHidden().pickerStyle(.menu)
        }
    }
    private func comparison(before: ProgressPhotoRecord, after: ProgressPhotoRecord) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .leading) {
                Color.black
                if mode == .sideBySide {
                    HStack(spacing: 2) {
                        ProgressPhotoDisplay(data: before.imageData)
                            .frame(width: (size.width - 2) / 2, height: size.height)
                        ProgressPhotoDisplay(data: after.imageData)
                            .frame(width: (size.width - 2) / 2, height: size.height)
                    }
                } else {
                    ProgressPhotoDisplay(data: before.imageData).frame(width: size.width, height: size.height)
                    ProgressPhotoDisplay(data: after.imageData).frame(width: size.width, height: size.height)
                        .opacity(mode == .overlay ? opacity : 1)
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: mode == .reveal ? size.width * reveal : size.width)
                        }
                    if mode == .reveal {
                        Rectangle().fill(.white).frame(width: 2, height: size.height)
                            .position(x: size.width * reveal, y: size.height / 2)
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption.bold()).foregroundStyle(.black)
                            .padding(10).background(.white, in: Circle())
                            .position(x: min(max(size.width * reveal, 18), size.width - 18), y: size.height / 2)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                if mode == .reveal { reveal = min(max(value.location.x / max(size.width, 1), 0), 1) }
            }, including: mode == .reveal ? .all : .none)
        }
        .containerRelativeFrame(.vertical) { length, _ in min(length * 0.52, 480) }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
