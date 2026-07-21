import SwiftUI
import AppKit

public struct RootView: View {
    @State private var model: SearchModel
    @State private var store: ResultsStore
    @State private var searchTask: Task<Void, Never>?
    private let ops = FileOps()
    private let replaceEngine = ReplaceEngine()

    public init() {
        let store = ResultsStore()
        self._store = State(initialValue: store)
        self._model = State(initialValue: SearchModel(
            engine: FffEngine(), store: store,
            fileLinesProvider: { url in
                (try? String(contentsOf: url, encoding: .utf8))?
                    .components(separatedBy: "\n") ?? []
            }))
    }

    public var body: some View {
        VStack(spacing: 0) {
            SearchBar(model: model, onFolderPick: pickFolder, onReplace: runReplace)
            FiltersPanel(model: model)
            Divider()
            HSplitView {
                ResultsList(store: store,
                            onReveal: { ops.revealInFinder($0) },
                            onOpen: { ops.open($0, withEditor: nil) })
                    .frame(minWidth: 320)
                PreviewPane(store: store).frame(minWidth: 360)
            }
            Divider()
            StatusBar(store: store, model: model)
        }
        .onChange(of: model.pattern) { _, _ in scheduleSearch() }
        .onChange(of: model.mode) { _, _ in scheduleSearch() }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return }
            await model.runNow()
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            model.basePath = url; scheduleSearch()
        }
    }

    private func runReplace() {
        let files = store.files.map { $0.file }
        _ = try? replaceEngine.replace(in: files, pattern: model.pattern,
                                       replacement: model.replacement, mode: model.mode)
        Task { await model.runNow() }
    }
}
