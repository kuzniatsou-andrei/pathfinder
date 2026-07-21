import Foundation
import Observation

@Observable
@MainActor
public final class SearchModel {
    public var pattern: String = ""
    public var mode: SearchMode = .text
    public var basePath: URL?
    public var includeGlobs: [String] = []
    public var excludeGlobs: [String] = []
    public var maxFileSizeBytes: Int?
    public var excludeBinary: Bool = true
    public var contextBefore: Int = 1
    public var contextAfter: Int = 1
    public private(set) var isSearching: Bool = false
    public var lastError: String?
    public var replacement: String = ""
    public var restrictToFiles: Set<String>? = nil

    private let engine: SearchEngine
    private let store: ResultsStore
    private let fileLinesProvider: @Sendable (URL) -> [String]
    private let assembler = ContextAssembler()
    private var generation = 0

    public init(engine: SearchEngine, store: ResultsStore,
                fileLinesProvider: @escaping @Sendable (URL) -> [String]) {
        self.engine = engine; self.store = store
        self.fileLinesProvider = fileLinesProvider
    }

    public var regexError: String? {
        guard mode == .regex, !pattern.isEmpty else { return nil }
        do { _ = try NSRegularExpression(pattern: pattern); return nil }
        catch { return "Некорректный regex" }
    }

    /// Build a query from current state, or nil if not runnable.
    private func makeQuery() -> SearchQuery? {
        guard !pattern.isEmpty, let base = basePath else { return nil }
        if mode == .regex, regexError != nil { return nil }
        return SearchQuery(pattern: pattern, mode: mode, basePath: base,
                           includeGlobs: includeGlobs, excludeGlobs: excludeGlobs,
                           maxFileSizeBytes: maxFileSizeBytes, excludeBinary: excludeBinary,
                           contextBefore: contextBefore, contextAfter: contextAfter)
    }

    public func runNow() async {
        guard let query = makeQuery() else { store.reset(); return }
        generation &+= 1; let gen = generation
        isSearching = true; lastError = nil; store.reset()
        defer { if gen == generation { isSearching = false } }
        do {
            for try await raw in engine.grep(query) {
                if Task.isCancelled { return }
                if gen == generation {
                    if let restrictToFiles, !restrictToFiles.contains(raw.file.path) {
                        continue
                    }
                    if store.canDisplayMore {
                        let lines = fileLinesProvider(raw.file)
                        let match = assembler.assemble(raw, fileLines: lines,
                                                       before: query.contextBefore, after: query.contextAfter)
                        store.add(match)
                    } else {
                        store.countOverflow()
                    }
                }
            }
        } catch is CancellationError {
            // superseded by a newer search; leave partial results
        } catch {
            if gen == generation { lastError = String(describing: error) }
        }
    }
}
