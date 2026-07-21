import SwiftUI
import AppKit

public struct RootView: View {
    @State private var model: SearchModel
    @State private var store: ResultsStore
    @State private var searchTask: Task<Void, Never>?
    @State private var canUndo: Bool = false
    @State private var searchInResults = false
    @State private var historyItems: [String] = SearchHistory().items()
    private let ops = FileOps()
    private let replaceEngine = ReplaceEngine()
    private let folderMemory = FolderMemory()
    private let searchHistory = SearchHistory()

    public init() {
        let store = ResultsStore()
        self._store = State(initialValue: store)
        let model = SearchModel(
            engine: FffEngine(), store: store,
            fileLinesProvider: { url in
                (try? String(contentsOf: url, encoding: .utf8))?
                    .components(separatedBy: "\n") ?? []
            })
        // Restore the last searched folder if it still exists.
        model.basePath = FolderMemory().loadValidDirectory()
        self._model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            SearchBar(model: model, canUndo: canUndo,
                      onFolderPick: pickFolder, onReplace: runReplace, onUndo: runUndo,
                      onSearchToggle: toggleSearch, onClear: clearSearch,
                      searchInResults: $searchInResults,
                      canSearchInResults: !store.files.isEmpty,
                      history: historyItems, onDeleteHistory: deleteHistoryItem,
                      onClearHistory: clearHistory)
            FiltersPanel(model: model)
            Divider()
            HSplitView {
                ResultsList(store: store, relativeTo: model.basePath,
                            onReveal: { ops.revealInFinder($0) },
                            onOpen: { ops.open($0, withEditor: nil) },
                            onDelete: runDelete,
                            onExcludeFile: { addExclude($0.lastPathComponent) },
                            onExcludeFolder: { addExclude($0.deletingLastPathComponent().lastPathComponent) })
                    .frame(minWidth: 320)
                PreviewPane(store: store, model: model).frame(minWidth: 360)
            }
            Divider()
            StatusBar(store: store, model: model)
        }
    }

    private func toggleSearch() {
        if model.isSearching {
            searchTask?.cancel()
            searchTask = nil
        } else {
            // No folder yet: guide the user through picking one, then search.
            if model.basePath == nil { pickFolder() }
            guard model.basePath != nil else { return }  // picker cancelled
            searchHistory.add(model.pattern)
            historyItems = searchHistory.items()
            // Snapshot the current result files BEFORE runNow resets the store.
            model.restrictToFiles = searchInResults ? Set(store.files.map { $0.file.path }) : nil
            searchTask?.cancel()
            searchTask = Task { await model.runNow() }
        }
    }

    private func clearSearch() {
        searchTask?.cancel()
        searchTask = nil
        model.pattern = ""
        model.lastError = nil
        store.reset()
        searchInResults = false
        model.restrictToFiles = nil
    }

    /// Add a glob to the exclude filter (dedup) and re-run the search if possible.
    private func addExclude(_ glob: String) {
        let g = glob.trimmingCharacters(in: .whitespaces)
        guard !g.isEmpty else { return }
        if !model.excludeGlobs.contains(g) { model.excludeGlobs.append(g) }
        if !model.pattern.isEmpty, model.basePath != nil {
            searchTask?.cancel()
            searchTask = Task { await model.runNow() }
        }
    }

    private func deleteHistoryItem(_ s: String) {
        searchHistory.remove(s)
        historyItems = searchHistory.items()
    }

    private func clearHistory() {
        searchHistory.clear()
        historyItems = []
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            model.basePath = url
            folderMemory.save(url)
        }
    }

    private func runReplace() {
        guard model.mode != .fuzzy else {
            model.lastError = "Замена недоступна в Fuzzy-режиме"
            return
        }
        let files = store.files.map { $0.file }
        let message: String
        do {
            let report = try replaceEngine.replace(in: files, pattern: model.pattern,
                                                   replacement: model.replacement, mode: model.mode)
            message = "Заменено в \(report.changedFiles.count) файлах, пропущено \(report.skipped.count)"
        } catch {
            message = String(describing: error)
        }
        canUndo = replaceEngine.canUndo
        // `runNow()` clears lastError on entry, so surface the summary AFTER it
        // finishes, otherwise the message would be wiped by the refresh search.
        Task { await model.runNow(); model.lastError = message }
    }

    private func runUndo() {
        try? replaceEngine.undo()
        canUndo = replaceEngine.canUndo
        Task { await model.runNow() }
    }

    private func runDelete(_ url: URL) {
        let failure: String?
        do {
            try ops.delete(url); failure = nil
        } catch {
            failure = String(describing: error)
        }
        Task {
            await model.runNow()
            if let failure { model.lastError = failure }
        }
    }
}
