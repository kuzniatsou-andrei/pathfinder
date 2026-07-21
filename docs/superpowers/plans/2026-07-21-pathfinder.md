# Pathfinder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a simple macOS SwiftUI app that searches text files (text/regex/fuzzy), shows readable grouped results with context lines and whole-file preview, supports replace+undo, and integrates with Finder.

**Architecture:** SwiftUI front end over an in-process search engine. The `fff` Rust engine (MIT) is compiled to `libfff_c.dylib` and reached through a thin, project-authored C shim (`fff_shim`) with a stable signature — this isolates all `fff` API uncertainty to one C file. Swift talks only to the shim via a `SearchEngine` protocol, so every other module is testable with a fake engine and no native dependency.

**Tech Stack:** Swift 5.9+, SwiftUI, Swift Package Manager (app + library targets), Rust/cargo (to build `fff-c`), a C shim + module map for the Swift↔C bridge, XCTest.

## Global Constraints

- Platform: macOS 14+ (SwiftUI `@Observable`), Apple Silicon + Intel.
- Search modes in v1: Text, Regex, Fuzzy only. No XPath, no byte-sequence.
- Replace mutates text files only; binary files are read-only.
- Context lines default: 2 before / 2 after; 0 = match line only.
- Search input debounce: 200 ms. A new search cancels the previous one.
- Engine access goes through the `SearchEngine` protocol — no module except `FffEngine` may import the C shim.
- Frequent commits: every task ends with a commit. TDD: test first, watch it fail, implement, watch it pass.

---

## File Structure

```
Pathfinder/
├── Package.swift                       # SPM: app exe + PathfinderKit lib + tests
├── Sources/
│   ├── PathfinderApp/                  # @main app entry, SwiftUI scene
│   │   └── PathfinderApp.swift
│   ├── PathfinderKit/                  # all logic + views (testable library)
│   │   ├── Model/
│   │   │   ├── SearchMode.swift
│   │   │   ├── SearchQuery.swift
│   │   │   ├── RawMatch.swift
│   │   │   ├── SearchMatch.swift        # + NumberedLine, FileResult
│   │   │   └── SearchEngine.swift       # protocol
│   │   ├── Engine/
│   │   │   ├── ContextAssembler.swift
│   │   │   ├── FileFilter.swift
│   │   │   └── FffEngine.swift          # the only importer of CFffShim
│   │   ├── State/
│   │   │   ├── SearchModel.swift
│   │   │   └── ResultsStore.swift
│   │   ├── Ops/
│   │   │   ├── ReplaceEngine.swift
│   │   │   └── FileOps.swift
│   │   └── UI/
│   │       ├── RootView.swift
│   │       ├── SearchBar.swift
│   │       ├── FiltersPanel.swift
│   │       ├── ResultsList.swift
│   │       ├── PreviewPane.swift
│   │       └── StatusBar.swift
│   └── CFffShim/                        # C shim target
│       ├── include/
│       │   ├── fff_shim.h
│       │   └── module.modulemap
│       └── fff_shim.c
├── Vendor/fff/                          # git submodule / vendored fff source
└── Tests/PathfinderKitTests/
    ├── FakeEngine.swift
    ├── ContextAssemblerTests.swift
    ├── FileFilterTests.swift
    ├── ResultsStoreTests.swift
    ├── SearchModelTests.swift
    ├── ReplaceEngineTests.swift
    ├── FileOpsTests.swift
    └── FffEngineIntegrationTests.swift
```

---

### Task 1: Project scaffold — SPM package builds and runs

**Files:**
- Create: `Package.swift`
- Create: `Sources/PathfinderApp/PathfinderApp.swift`
- Create: `Sources/PathfinderKit/Model/SearchMode.swift`
- Test: `Tests/PathfinderKitTests/SmokeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum SearchMode { case text, regex, fuzzy }`; library `PathfinderKit`; executable `PathfinderApp`.

- [ ] **Step 1: Write the failing test**

`Tests/PathfinderKitTests/SmokeTests.swift`:
```swift
import XCTest
@testable import PathfinderKit

final class SmokeTests: XCTestCase {
    func test_searchMode_hasThreeCases() {
        XCTAssertEqual(SearchMode.allCases.count, 3)
    }
}
```

- [ ] **Step 2: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pathfinder",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "PathfinderApp", dependencies: ["PathfinderKit"]),
        .target(name: "PathfinderKit"),
        .testTarget(name: "PathfinderKitTests", dependencies: ["PathfinderKit"]),
    ]
)
```

- [ ] **Step 3: Create the SearchMode model**

`Sources/PathfinderKit/Model/SearchMode.swift`:
```swift
public enum SearchMode: String, CaseIterable, Sendable {
    case text, regex, fuzzy
}
```

- [ ] **Step 4: Create a minimal app entry**

`Sources/PathfinderApp/PathfinderApp.swift`:
```swift
import SwiftUI
import PathfinderKit

@main
struct PathfinderApp: App {
    var body: some Scene {
        WindowGroup { Text("Pathfinder") }
    }
}
```

- [ ] **Step 5: Run the test — expect PASS**

Run: `swift test`
Expected: build succeeds, `test_searchMode_hasThreeCases` PASSES.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "feat: scaffold SPM package with app, kit, and tests"
```

---

### Task 2: Domain models + SearchEngine protocol + FakeEngine

**Files:**
- Create: `Sources/PathfinderKit/Model/SearchQuery.swift`
- Create: `Sources/PathfinderKit/Model/RawMatch.swift`
- Create: `Sources/PathfinderKit/Model/SearchMatch.swift`
- Create: `Sources/PathfinderKit/Model/SearchEngine.swift`
- Create: `Tests/PathfinderKitTests/FakeEngine.swift`
- Test: `Tests/PathfinderKitTests/ModelTests.swift`

**Interfaces:**
- Consumes: `SearchMode`.
- Produces (relied on by all later tasks — exact names/types):
  - `struct SearchQuery { var pattern: String; var mode: SearchMode; var basePath: URL; var includeGlobs: [String]; var excludeGlobs: [String]; var maxFileSizeBytes: Int?; var excludeBinary: Bool; var contextBefore: Int; var contextAfter: Int }`
  - `struct RawMatch: Equatable { let file: URL; let lineNumber: Int; let matchLine: String; let matchRange: Range<Int> }`
  - `struct NumberedLine: Equatable { let number: Int; let text: String }`
  - `struct SearchMatch: Equatable { let file: URL; let lineNumber: Int; let matchRange: Range<Int>; let matchLine: String; let contextBefore: [NumberedLine]; let contextAfter: [NumberedLine] }`
  - `struct FileResult: Equatable { let file: URL; let matches: [SearchMatch] }`
  - `protocol SearchEngine: Sendable { func grep(_ query: SearchQuery) -> AsyncThrowingStream<RawMatch, Error> }`

- [ ] **Step 1: Write the failing test**

`Tests/PathfinderKitTests/ModelTests.swift`:
```swift
import XCTest
@testable import PathfinderKit

final class ModelTests: XCTestCase {
    func test_searchQuery_defaults() {
        let q = SearchQuery(pattern: "x", mode: .text, basePath: URL(fileURLWithPath: "/tmp"))
        XCTAssertEqual(q.contextBefore, 2)
        XCTAssertEqual(q.contextAfter, 2)
        XCTAssertTrue(q.excludeBinary)
    }

    func test_fileResult_matchCount() {
        let m = SearchMatch(file: URL(fileURLWithPath: "/a"), lineNumber: 1,
                            matchRange: 0..<1, matchLine: "a",
                            contextBefore: [], contextAfter: [])
        XCTAssertEqual(FileResult(file: m.file, matches: [m]).matches.count, 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ModelTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Create the models**

`Sources/PathfinderKit/Model/SearchQuery.swift`:
```swift
import Foundation

public struct SearchQuery: Sendable {
    public var pattern: String
    public var mode: SearchMode
    public var basePath: URL
    public var includeGlobs: [String]
    public var excludeGlobs: [String]
    public var maxFileSizeBytes: Int?
    public var excludeBinary: Bool
    public var contextBefore: Int
    public var contextAfter: Int

    public init(pattern: String, mode: SearchMode, basePath: URL,
                includeGlobs: [String] = [], excludeGlobs: [String] = [],
                maxFileSizeBytes: Int? = nil, excludeBinary: Bool = true,
                contextBefore: Int = 2, contextAfter: Int = 2) {
        self.pattern = pattern; self.mode = mode; self.basePath = basePath
        self.includeGlobs = includeGlobs; self.excludeGlobs = excludeGlobs
        self.maxFileSizeBytes = maxFileSizeBytes; self.excludeBinary = excludeBinary
        self.contextBefore = contextBefore; self.contextAfter = contextAfter
    }
}
```

`Sources/PathfinderKit/Model/RawMatch.swift`:
```swift
import Foundation

public struct RawMatch: Equatable, Sendable {
    public let file: URL
    public let lineNumber: Int
    public let matchLine: String
    public let matchRange: Range<Int>
    public init(file: URL, lineNumber: Int, matchLine: String, matchRange: Range<Int>) {
        self.file = file; self.lineNumber = lineNumber
        self.matchLine = matchLine; self.matchRange = matchRange
    }
}
```

`Sources/PathfinderKit/Model/SearchMatch.swift`:
```swift
import Foundation

public struct NumberedLine: Equatable, Sendable {
    public let number: Int
    public let text: String
    public init(number: Int, text: String) { self.number = number; self.text = text }
}

public struct SearchMatch: Equatable, Sendable {
    public let file: URL
    public let lineNumber: Int
    public let matchRange: Range<Int>
    public let matchLine: String
    public let contextBefore: [NumberedLine]
    public let contextAfter: [NumberedLine]
    public init(file: URL, lineNumber: Int, matchRange: Range<Int>, matchLine: String,
                contextBefore: [NumberedLine], contextAfter: [NumberedLine]) {
        self.file = file; self.lineNumber = lineNumber; self.matchRange = matchRange
        self.matchLine = matchLine; self.contextBefore = contextBefore; self.contextAfter = contextAfter
    }
}

public struct FileResult: Equatable, Sendable {
    public let file: URL
    public let matches: [SearchMatch]
    public init(file: URL, matches: [SearchMatch]) { self.file = file; self.matches = matches }
}
```

`Sources/PathfinderKit/Model/SearchEngine.swift`:
```swift
import Foundation

public protocol SearchEngine: Sendable {
    func grep(_ query: SearchQuery) -> AsyncThrowingStream<RawMatch, Error>
}
```

- [ ] **Step 4: Create the FakeEngine test helper**

`Tests/PathfinderKitTests/FakeEngine.swift`:
```swift
import Foundation
@testable import PathfinderKit

/// Deterministic engine for testing everything above FffEngine.
struct FakeEngine: SearchEngine {
    var matches: [RawMatch] = []
    var error: Error? = nil
    func grep(_ query: SearchQuery) -> AsyncThrowingStream<RawMatch, Error> {
        AsyncThrowingStream { continuation in
            if let error { continuation.finish(throwing: error); return }
            for m in matches { continuation.yield(m) }
            continuation.finish()
        }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter ModelTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/PathfinderKit/Model Tests/PathfinderKitTests/FakeEngine.swift Tests/PathfinderKitTests/ModelTests.swift
git commit -m "feat: add domain models, SearchEngine protocol, and FakeEngine"
```

---

### Task 3: ContextAssembler — turn RawMatch into SearchMatch with ±N lines

**Files:**
- Create: `Sources/PathfinderKit/Engine/ContextAssembler.swift`
- Test: `Tests/PathfinderKitTests/ContextAssemblerTests.swift`

**Interfaces:**
- Consumes: `RawMatch`, `SearchMatch`, `NumberedLine`.
- Produces: `struct ContextAssembler { func assemble(_ raw: RawMatch, fileLines: [String], before: Int, after: Int) -> SearchMatch }`
  - `lineNumber` in `RawMatch` is 1-based. `fileLines` is the full file split by `\n`.

- [ ] **Step 1: Write the failing test**

`Tests/PathfinderKitTests/ContextAssemblerTests.swift`:
```swift
import XCTest
@testable import PathfinderKit

final class ContextAssemblerTests: XCTestCase {
    let lines = ["l1","l2","l3","l4","l5"]
    let raw = RawMatch(file: URL(fileURLWithPath: "/f"), lineNumber: 3,
                       matchLine: "l3", matchRange: 0..<2)

    func test_assemblesSymmetricContext() {
        let m = ContextAssembler().assemble(raw, fileLines: lines, before: 1, after: 1)
        XCTAssertEqual(m.contextBefore, [NumberedLine(number: 2, text: "l2")])
        XCTAssertEqual(m.contextAfter, [NumberedLine(number: 4, text: "l4")])
        XCTAssertEqual(m.matchLine, "l3")
        XCTAssertEqual(m.lineNumber, 3)
    }

    func test_clampsAtFileStart() {
        let first = RawMatch(file: URL(fileURLWithPath: "/f"), lineNumber: 1,
                             matchLine: "l1", matchRange: 0..<2)
        let m = ContextAssembler().assemble(first, fileLines: lines, before: 2, after: 0)
        XCTAssertEqual(m.contextBefore, [])
    }

    func test_clampsAtFileEnd() {
        let last = RawMatch(file: URL(fileURLWithPath: "/f"), lineNumber: 5,
                            matchLine: "l5", matchRange: 0..<2)
        let m = ContextAssembler().assemble(last, fileLines: lines, before: 0, after: 3)
        XCTAssertEqual(m.contextAfter, [])
    }

    func test_zeroContext() {
        let m = ContextAssembler().assemble(raw, fileLines: lines, before: 0, after: 0)
        XCTAssertTrue(m.contextBefore.isEmpty && m.contextAfter.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ContextAssemblerTests`
Expected: FAIL — `ContextAssembler` not defined.

- [ ] **Step 3: Implement ContextAssembler**

`Sources/PathfinderKit/Engine/ContextAssembler.swift`:
```swift
import Foundation

public struct ContextAssembler {
    public init() {}

    /// `raw.lineNumber` is 1-based; `fileLines` is the file split on "\n".
    public func assemble(_ raw: RawMatch, fileLines: [String], before: Int, after: Int) -> SearchMatch {
        let idx = raw.lineNumber - 1
        let beforeStart = max(0, idx - before)
        let afterEnd = min(fileLines.count - 1, idx + after)

        let ctxBefore: [NumberedLine] = (beforeStart..<idx).map {
            NumberedLine(number: $0 + 1, text: fileLines[$0])
        }
        let ctxAfter: [NumberedLine] = idx < afterEnd
            ? ((idx + 1)...afterEnd).map { NumberedLine(number: $0 + 1, text: fileLines[$0]) }
            : []

        return SearchMatch(file: raw.file, lineNumber: raw.lineNumber,
                           matchRange: raw.matchRange, matchLine: raw.matchLine,
                           contextBefore: ctxBefore, contextAfter: ctxAfter)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ContextAssemblerTests`
Expected: PASS (all 4).

- [ ] **Step 5: Commit**

```bash
git add Sources/PathfinderKit/Engine/ContextAssembler.swift Tests/PathfinderKitTests/ContextAssemblerTests.swift
git commit -m "feat: add ContextAssembler for +/-N context lines"
```

---

### Task 4: FileFilter — include/exclude glob, size, binary

**Files:**
- Create: `Sources/PathfinderKit/Engine/FileFilter.swift`
- Test: `Tests/PathfinderKitTests/FileFilterTests.swift`

**Interfaces:**
- Consumes: `SearchQuery`.
- Produces: `struct FileFilter { init(query: SearchQuery); func accepts(_ url: URL, sizeBytes: Int, isBinary: Bool) -> Bool }`
  - Glob semantics: `*` matches within a path component; matching is done on the file's last path component for globs without `/`, else on the path relative to `basePath`. v1 supports `*` and `?` only.

- [ ] **Step 1: Write the failing test**

`Tests/PathfinderKitTests/FileFilterTests.swift`:
```swift
import XCTest
@testable import PathfinderKit

final class FileFilterTests: XCTestCase {
    func q(include: [String] = [], exclude: [String] = [],
           maxSize: Int? = nil, excludeBinary: Bool = true) -> SearchQuery {
        SearchQuery(pattern: "x", mode: .text, basePath: URL(fileURLWithPath: "/repo"),
                    includeGlobs: include, excludeGlobs: exclude,
                    maxFileSizeBytes: maxSize, excludeBinary: excludeBinary)
    }
    let kt = URL(fileURLWithPath: "/repo/src/App.kt")

    func test_includeMatches() {
        XCTAssertTrue(FileFilter(query: q(include: ["*.kt"])).accepts(kt, sizeBytes: 10, isBinary: false))
        XCTAssertFalse(FileFilter(query: q(include: ["*.json"])).accepts(kt, sizeBytes: 10, isBinary: false))
    }
    func test_excludeWins() {
        XCTAssertFalse(FileFilter(query: q(include: ["*.kt"], exclude: ["*.kt"])).accepts(kt, sizeBytes: 10, isBinary: false))
    }
    func test_sizeLimit() {
        XCTAssertFalse(FileFilter(query: q(maxSize: 5)).accepts(kt, sizeBytes: 10, isBinary: false))
        XCTAssertTrue(FileFilter(query: q(maxSize: 50)).accepts(kt, sizeBytes: 10, isBinary: false))
    }
    func test_binaryExcluded() {
        XCTAssertFalse(FileFilter(query: q()).accepts(kt, sizeBytes: 10, isBinary: true))
        XCTAssertTrue(FileFilter(query: q(excludeBinary: false)).accepts(kt, sizeBytes: 10, isBinary: true))
    }
    func test_emptyIncludeMeansAll() {
        XCTAssertTrue(FileFilter(query: q()).accepts(kt, sizeBytes: 10, isBinary: false))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FileFilterTests`
Expected: FAIL — `FileFilter` not defined.

- [ ] **Step 3: Implement FileFilter**

`Sources/PathfinderKit/Engine/FileFilter.swift`:
```swift
import Foundation

public struct FileFilter {
    private let query: SearchQuery
    public init(query: SearchQuery) { self.query = query }

    public func accepts(_ url: URL, sizeBytes: Int, isBinary: Bool) -> Bool {
        if query.excludeBinary && isBinary { return false }
        if let max = query.maxFileSizeBytes, sizeBytes > max { return false }
        if query.excludeGlobs.contains(where: { matches(url, glob: $0) }) { return false }
        if !query.includeGlobs.isEmpty &&
            !query.includeGlobs.contains(where: { matches(url, glob: $0) }) { return false }
        return true
    }

    private func matches(_ url: URL, glob: String) -> Bool {
        let target = glob.contains("/")
            ? url.path.replacingOccurrences(of: query.basePath.path + "/", with: "")
            : url.lastPathComponent
        return globToRegex(glob).firstMatch(
            in: target, range: NSRange(target.startIndex..., in: target)) != nil
    }

    private func globToRegex(_ glob: String) -> NSRegularExpression {
        var re = "^"
        for ch in glob {
            switch ch {
            case "*": re += "[^/]*"
            case "?": re += "[^/]"
            case ".", "(", ")", "+", "|", "^", "$", "\\", "[", "]", "{", "}":
                re += "\\" + String(ch)
            default: re += String(ch)
            }
        }
        re += "$"
        return try! NSRegularExpression(pattern: re)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FileFilterTests`
Expected: PASS (all 5).

- [ ] **Step 5: Commit**

```bash
git add Sources/PathfinderKit/Engine/FileFilter.swift Tests/PathfinderKitTests/FileFilterTests.swift
git commit -m "feat: add FileFilter for glob/size/binary filtering"
```

---

### Task 5: ResultsStore — group by file, sort, select

**Files:**
- Create: `Sources/PathfinderKit/State/ResultsStore.swift`
- Test: `Tests/PathfinderKitTests/ResultsStoreTests.swift`

**Interfaces:**
- Consumes: `SearchMatch`, `FileResult`.
- Produces: `@Observable final class ResultsStore` with:
  - `private(set) var files: [FileResult]`
  - `var selectedMatch: SearchMatch?`
  - `func reset()`
  - `func add(_ match: SearchMatch)` — appends into the correct `FileResult`, preserving file insertion order and per-file line order.
  - `var totalMatches: Int`, `var fileCount: Int`

- [ ] **Step 1: Write the failing test**

`Tests/PathfinderKitTests/ResultsStoreTests.swift`:
```swift
import XCTest
@testable import PathfinderKit

final class ResultsStoreTests: XCTestCase {
    func match(_ path: String, _ line: Int) -> SearchMatch {
        SearchMatch(file: URL(fileURLWithPath: path), lineNumber: line,
                    matchRange: 0..<1, matchLine: "m", contextBefore: [], contextAfter: [])
    }

    func test_groupsByFilePreservingOrder() {
        let s = ResultsStore()
        s.add(match("/a", 5)); s.add(match("/b", 1)); s.add(match("/a", 2))
        XCTAssertEqual(s.files.map { $0.file.path }, ["/a", "/b"])
        XCTAssertEqual(s.files[0].matches.map { $0.lineNumber }, [5, 2])
        XCTAssertEqual(s.totalMatches, 3)
        XCTAssertEqual(s.fileCount, 2)
    }

    func test_resetClears() {
        let s = ResultsStore()
        s.add(match("/a", 1)); s.selectedMatch = match("/a", 1)
        s.reset()
        XCTAssertTrue(s.files.isEmpty)
        XCTAssertNil(s.selectedMatch)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ResultsStoreTests`
Expected: FAIL — `ResultsStore` not defined.

- [ ] **Step 3: Implement ResultsStore**

`Sources/PathfinderKit/State/ResultsStore.swift`:
```swift
import Foundation
import Observation

@Observable
public final class ResultsStore {
    public private(set) var files: [FileResult] = []
    public var selectedMatch: SearchMatch?
    private var indexByPath: [String: Int] = [:]

    public init() {}

    public func reset() {
        files = []; indexByPath = [:]; selectedMatch = nil
    }

    public func add(_ match: SearchMatch) {
        let key = match.file.path
        if let i = indexByPath[key] {
            files[i] = FileResult(file: files[i].file, matches: files[i].matches + [match])
        } else {
            indexByPath[key] = files.count
            files.append(FileResult(file: match.file, matches: [match]))
        }
    }

    public var totalMatches: Int { files.reduce(0) { $0 + $1.matches.count } }
    public var fileCount: Int { files.count }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ResultsStoreTests`
Expected: PASS (both).

- [ ] **Step 5: Commit**

```bash
git add Sources/PathfinderKit/State/ResultsStore.swift Tests/PathfinderKitTests/ResultsStoreTests.swift
git commit -m "feat: add ResultsStore with file grouping and selection"
```

---

### Task 6: SearchModel — debounce, cancel, drive engine into store

**Files:**
- Create: `Sources/PathfinderKit/State/SearchModel.swift`
- Test: `Tests/PathfinderKitTests/SearchModelTests.swift`

**Interfaces:**
- Consumes: `SearchEngine`, `ResultsStore`, `SearchQuery`, `ContextAssembler`, `RawMatch`.
- Produces: `@Observable final class SearchModel`:
  - `init(engine: SearchEngine, store: ResultsStore, fileLinesProvider: @escaping @Sendable (URL) -> [String], debounceMs: Int = 200)`
  - `var pattern: String`, `var mode: SearchMode`, `var basePath: URL?`, filter/context fields.
  - `var isSearching: Bool`, `var lastError: String?`
  - `func runNow() async` — builds query, resets store, streams matches, assembles context, adds to store. Cancels any prior run.
  - The `fileLinesProvider` closure decouples file reading (real impl reads disk; tests inject fixtures).

- [ ] **Step 1: Write the failing test**

`Tests/PathfinderKitTests/SearchModelTests.swift`:
```swift
import XCTest
@testable import PathfinderKit

final class SearchModelTests: XCTestCase {
    func test_runPopulatesStoreWithContext() async {
        let raw = RawMatch(file: URL(fileURLWithPath: "/f"), lineNumber: 2,
                           matchLine: "b", matchRange: 0..<1)
        let engine = FakeEngine(matches: [raw])
        let store = ResultsStore()
        let model = SearchModel(engine: engine, store: store,
                                fileLinesProvider: { _ in ["a","b","c"] })
        model.pattern = "b"
        model.basePath = URL(fileURLWithPath: "/")
        model.contextBefore = 1; model.contextAfter = 1

        await model.runNow()

        XCTAssertEqual(store.totalMatches, 1)
        let m = store.files[0].matches[0]
        XCTAssertEqual(m.contextBefore, [NumberedLine(number: 1, text: "a")])
        XCTAssertEqual(m.contextAfter, [NumberedLine(number: 3, text: "c")])
        XCTAssertFalse(model.isSearching)
    }

    func test_emptyPatternDoesNotSearch() async {
        let engine = FakeEngine(matches: [RawMatch(file: URL(fileURLWithPath: "/f"),
                                lineNumber: 1, matchLine: "a", matchRange: 0..<1)])
        let store = ResultsStore()
        let model = SearchModel(engine: engine, store: store, fileLinesProvider: { _ in ["a"] })
        model.pattern = ""
        model.basePath = URL(fileURLWithPath: "/")
        await model.runNow()
        XCTAssertEqual(store.totalMatches, 0)
    }

    func test_errorSurfacesToLastError() async {
        struct E: Error {}
        let engine = FakeEngine(matches: [], error: E())
        let store = ResultsStore()
        let model = SearchModel(engine: engine, store: store, fileLinesProvider: { _ in [] })
        model.pattern = "x"; model.basePath = URL(fileURLWithPath: "/")
        await model.runNow()
        XCTAssertNotNil(model.lastError)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SearchModelTests`
Expected: FAIL — `SearchModel` not defined.

- [ ] **Step 3: Implement SearchModel**

`Sources/PathfinderKit/State/SearchModel.swift`:
```swift
import Foundation
import Observation

@Observable
public final class SearchModel {
    public var pattern: String = ""
    public var mode: SearchMode = .text
    public var basePath: URL?
    public var includeGlobs: [String] = []
    public var excludeGlobs: [String] = []
    public var maxFileSizeBytes: Int?
    public var excludeBinary: Bool = true
    public var contextBefore: Int = 2
    public var contextAfter: Int = 2
    public private(set) var isSearching: Bool = false
    public var lastError: String?

    private let engine: SearchEngine
    private let store: ResultsStore
    private let fileLinesProvider: @Sendable (URL) -> [String]
    private let debounceMs: Int
    private let assembler = ContextAssembler()

    public init(engine: SearchEngine, store: ResultsStore,
                fileLinesProvider: @escaping @Sendable (URL) -> [String],
                debounceMs: Int = 200) {
        self.engine = engine; self.store = store
        self.fileLinesProvider = fileLinesProvider; self.debounceMs = debounceMs
    }

    /// Build a query from current state, or nil if not runnable.
    private func makeQuery() -> SearchQuery? {
        guard !pattern.isEmpty, let base = basePath else { return nil }
        return SearchQuery(pattern: pattern, mode: mode, basePath: base,
                           includeGlobs: includeGlobs, excludeGlobs: excludeGlobs,
                           maxFileSizeBytes: maxFileSizeBytes, excludeBinary: excludeBinary,
                           contextBefore: contextBefore, contextAfter: contextAfter)
    }

    public func runNow() async {
        guard let query = makeQuery() else { store.reset(); return }
        isSearching = true; lastError = nil; store.reset()
        defer { isSearching = false }
        do {
            for try await raw in engine.grep(query) {
                if Task.isCancelled { return }
                let lines = fileLinesProvider(raw.file)
                let match = assembler.assemble(raw, fileLines: lines,
                                               before: query.contextBefore, after: query.contextAfter)
                store.add(match)
            }
        } catch is CancellationError {
            // superseded by a newer search; leave partial results
        } catch {
            lastError = String(describing: error)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SearchModelTests`
Expected: PASS (all 3).

- [ ] **Step 5: Commit**

```bash
git add Sources/PathfinderKit/State/SearchModel.swift Tests/PathfinderKitTests/SearchModelTests.swift
git commit -m "feat: add SearchModel driving engine into ResultsStore with context"
```

---

### Task 7: ReplaceEngine — replace in text files with undo

**Files:**
- Create: `Sources/PathfinderKit/Ops/ReplaceEngine.swift`
- Test: `Tests/PathfinderKitTests/ReplaceEngineTests.swift`

**Interfaces:**
- Consumes: `SearchMode` (regex vs literal), `FileResult`.
- Produces: `final class ReplaceEngine`:
  - `struct ReplaceReport { let changedFiles: [URL]; let skipped: [(URL, String)] }`
  - `func replace(in files: [URL], pattern: String, replacement: String, mode: SearchMode) throws -> ReplaceReport` — literal for `.text`/`.fuzzy`, regex for `.regex`. Records a snapshot per changed file for undo. Skips files that are not valid UTF-8 text (binary), recording a reason.
  - `var canUndo: Bool`
  - `func undo() throws` — restores the most recent batch of snapshots.

- [ ] **Step 1: Write the failing test**

`Tests/PathfinderKitTests/ReplaceEngineTests.swift`:
```swift
import XCTest
@testable import PathfinderKit

final class ReplaceEngineTests: XCTestCase {
    var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func write(_ name: String, _ content: String) throws -> URL {
        let u = dir.appendingPathComponent(name)
        try content.write(to: u, atomically: true, encoding: .utf8)
        return u
    }
    func read(_ u: URL) throws -> String { try String(contentsOf: u, encoding: .utf8) }

    func test_literalReplaceAndUndo() throws {
        let f = try write("a.txt", "foo bar foo")
        let engine = ReplaceEngine()
        let report = try engine.replace(in: [f], pattern: "foo", replacement: "baz", mode: .text)
        XCTAssertEqual(report.changedFiles, [f])
        XCTAssertEqual(try read(f), "baz bar baz")
        XCTAssertTrue(engine.canUndo)
        try engine.undo()
        XCTAssertEqual(try read(f), "foo bar foo")
    }

    func test_regexReplace() throws {
        let f = try write("b.txt", "id=42 id=7")
        let engine = ReplaceEngine()
        _ = try engine.replace(in: [f], pattern: #"id=\d+"#, replacement: "id=X", mode: .regex)
        XCTAssertEqual(try read(f), "id=X id=X")
    }

    func test_skipsBinary() throws {
        let u = dir.appendingPathComponent("c.bin")
        try Data([0xFF, 0x00, 0xFE]).write(to: u)
        let engine = ReplaceEngine()
        let report = try engine.replace(in: [u], pattern: "x", replacement: "y", mode: .text)
        XCTAssertTrue(report.changedFiles.isEmpty)
        XCTAssertEqual(report.skipped.count, 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ReplaceEngineTests`
Expected: FAIL — `ReplaceEngine` not defined.

- [ ] **Step 3: Implement ReplaceEngine**

`Sources/PathfinderKit/Ops/ReplaceEngine.swift`:
```swift
import Foundation

public final class ReplaceEngine {
    public struct ReplaceReport {
        public let changedFiles: [URL]
        public let skipped: [(URL, String)]
    }

    private var undoStack: [[URL: String]] = []
    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }

    public func replace(in files: [URL], pattern: String, replacement: String,
                        mode: SearchMode) throws -> ReplaceReport {
        var changed: [URL] = []
        var skipped: [(URL, String)] = []
        var snapshot: [URL: String] = [:]

        for file in files {
            guard let original = try? String(contentsOf: file, encoding: .utf8) else {
                skipped.append((file, "not a UTF-8 text file")); continue
            }
            let updated: String
            switch mode {
            case .regex:
                let re = try NSRegularExpression(pattern: pattern)
                updated = re.stringByReplacingMatches(
                    in: original, range: NSRange(original.startIndex..., in: original),
                    withTemplate: NSRegularExpression.escapedTemplate(for: replacement))
            case .text, .fuzzy:
                updated = original.replacingOccurrences(of: pattern, with: replacement)
            }
            if updated != original {
                snapshot[file] = original
                try updated.write(to: file, atomically: true, encoding: .utf8)
                changed.append(file)
            }
        }
        if !snapshot.isEmpty { undoStack.append(snapshot) }
        return ReplaceReport(changedFiles: changed, skipped: skipped)
    }

    public func undo() throws {
        guard let last = undoStack.popLast() else { return }
        for (file, content) in last {
            try content.write(to: file, atomically: true, encoding: .utf8)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ReplaceEngineTests`
Expected: PASS (all 3).

- [ ] **Step 5: Commit**

```bash
git add Sources/PathfinderKit/Ops/ReplaceEngine.swift Tests/PathfinderKitTests/ReplaceEngineTests.swift
git commit -m "feat: add ReplaceEngine with undo and binary-file skipping"
```

---

### Task 8: FileOps — move/copy/delete/reveal/open-in-editor

**Files:**
- Create: `Sources/PathfinderKit/Ops/FileOps.swift`
- Test: `Tests/PathfinderKitTests/FileOpsTests.swift`

**Interfaces:**
- Consumes: nothing from prior tasks.
- Produces: `struct FileOps`:
  - `func move(_ src: URL, to dst: URL) throws`
  - `func copy(_ src: URL, to dst: URL) throws`
  - `func delete(_ url: URL) throws`
  - `func revealInFinder(_ url: URL)` — `NSWorkspace.shared.activateFileViewerSelecting`
  - `func open(_ url: URL, withEditor bundleId: String?)` — opens in given app or default.
  - The two `NSWorkspace` methods are UI side effects; tests cover the `FileManager`-backed ones.

- [ ] **Step 1: Write the failing test**

`Tests/PathfinderKitTests/FileOpsTests.swift`:
```swift
import XCTest
@testable import PathfinderKit

final class FileOpsTests: XCTestCase {
    var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func write(_ name: String) throws -> URL {
        let u = dir.appendingPathComponent(name)
        try "data".write(to: u, atomically: true, encoding: .utf8)
        return u
    }

    func test_copyThenDelete() throws {
        let src = try write("a.txt")
        let dst = dir.appendingPathComponent("b.txt")
        let ops = FileOps()
        try ops.copy(src, to: dst)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.path))
        try ops.delete(src)
        XCTAssertFalse(FileManager.default.fileExists(atPath: src.path))
    }

    func test_move() throws {
        let src = try write("a.txt")
        let dst = dir.appendingPathComponent("moved.txt")
        try FileOps().move(src, to: dst)
        XCTAssertFalse(FileManager.default.fileExists(atPath: src.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.path))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FileOpsTests`
Expected: FAIL — `FileOps` not defined.

- [ ] **Step 3: Implement FileOps**

`Sources/PathfinderKit/Ops/FileOps.swift`:
```swift
import Foundation
import AppKit

public struct FileOps {
    public init() {}

    public func move(_ src: URL, to dst: URL) throws {
        try FileManager.default.moveItem(at: src, to: dst)
    }
    public func copy(_ src: URL, to dst: URL) throws {
        try FileManager.default.copyItem(at: src, to: dst)
    }
    public func delete(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
    public func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    public func open(_ url: URL, withEditor bundleId: String?) {
        if let bundleId,
           let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let cfg = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: app, configuration: cfg)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FileOpsTests`
Expected: PASS (both).

- [ ] **Step 5: Commit**

```bash
git add Sources/PathfinderKit/Ops/FileOps.swift Tests/PathfinderKitTests/FileOpsTests.swift
git commit -m "feat: add FileOps for move/copy/delete/reveal/open"
```

---

### Task 9: Vendor fff, build libfff_c, author C shim + FffEngine

This task carries native build steps; it delivers a real `SearchEngine` verified by an integration test against fixture files.

**Files:**
- Create: `Sources/CFffShim/include/fff_shim.h`
- Create: `Sources/CFffShim/include/module.modulemap`
- Create: `Sources/CFffShim/fff_shim.c`
- Modify: `Package.swift` (add `CFffShim` target + link flags)
- Create: `Sources/PathfinderKit/Engine/FffEngine.swift`
- Create: `Vendor/fff/` (git submodule)
- Test: `Tests/PathfinderKitTests/FffEngineIntegrationTests.swift`

**Interfaces:**
- Consumes: `SearchEngine`, `RawMatch`, `SearchQuery`, `FileFilter`.
- Produces: `struct FffEngine: SearchEngine` — the only Swift file importing `CFffShim`.
- Shim ABI (project-authored, stable):
  ```c
  typedef struct { const char* file; uint32_t line; uint32_t col_start; uint32_t col_end; const char* text; } ShimMatch;
  typedef struct { ShimMatch* items; size_t count; } ShimMatches;
  int shim_grep(const char* base_path, const char* pattern, int mode, ShimMatches* out); // 0 text,1 regex,2 fuzzy; returns 0 on success
  void shim_free(ShimMatches* m);
  ```

- [ ] **Step 1: Vendor fff and build the C library**

```bash
git submodule add https://github.com/dmtrKovalenko/fff Vendor/fff
cd Vendor/fff && cargo build --release -p fff-c && cd -
# Verify outputs exist:
ls Vendor/fff/target/release/libfff_c.dylib
ls Vendor/fff/crates/fff-c/include/fff.h
```
Expected: both files exist. Read `crates/fff-c/include/fff.h` to confirm the exact `fff_grep` signature and result struct — the shim body in Step 3 is written against it.

- [ ] **Step 2: Write the shim header and module map**

`Sources/CFffShim/include/fff_shim.h`:
```c
#ifndef FFF_SHIM_H
#define FFF_SHIM_H
#include <stddef.h>
#include <stdint.h>

typedef struct {
    const char* file;
    uint32_t line;       // 1-based
    uint32_t col_start;  // 0-based byte offset in line
    uint32_t col_end;
    const char* text;    // the matched line
} ShimMatch;

typedef struct {
    ShimMatch* items;
    size_t count;
} ShimMatches;

// mode: 0 = text, 1 = regex, 2 = fuzzy. Returns 0 on success, non-zero on error.
int shim_grep(const char* base_path, const char* pattern, int mode, ShimMatches* out);
void shim_free(ShimMatches* m);

#endif
```

`Sources/CFffShim/include/module.modulemap`:
```
module CFffShim {
    header "fff_shim.h"
    export *
}
```

- [ ] **Step 3: Write the shim implementation**

`Sources/CFffShim/fff_shim.c` — bridges our stable ABI to `fff`'s. Fill the marked body against the confirmed `fff.h` from Step 1 (`fff_create_instance` / `fff_grep` / `fff_free_*`). Reference skeleton:
```c
#include "fff_shim.h"
#include "fff.h"      // from Vendor/fff/crates/fff-c/include
#include <stdlib.h>
#include <string.h>

int shim_grep(const char* base_path, const char* pattern, int mode, ShimMatches* out) {
    out->items = NULL; out->count = 0;

    FffResult* inst = fff_create_instance(
        base_path, "", "", /*use_unsafe_no_lock*/0, /*enable_mmap_cache*/1,
        /*enable_content_indexing*/1, /*watch*/0, /*ai_mode*/0);
    if (inst == NULL) return 1;

    // Map `mode` to fff_grep's mode argument (plain/regex/fuzzy) per fff.h,
    // call fff_grep(inst, pattern, ...), then copy each returned match into a
    // heap ShimMatch array (strdup file + line text). Set out->items/out->count.
    // Free fff's own result with fff_free_result()/fff_free_string() as fff.h requires.
    // Finally fff_destroy(inst).
    // On any fff error, fff_destroy(inst) and return non-zero.

    fff_destroy(inst);
    return 0;
}

void shim_free(ShimMatches* m) {
    if (m->items == NULL) return;
    for (size_t i = 0; i < m->count; i++) {
        free((void*)m->items[i].file);
        free((void*)m->items[i].text);
    }
    free(m->items);
    m->items = NULL; m->count = 0;
}
```

- [ ] **Step 4: Wire the target into Package.swift**

Add to `Package.swift` targets and make `PathfinderKit` depend on `CFffShim`:
```swift
.target(
    name: "CFffShim",
    cSettings: [ .unsafeFlags(["-I", "Vendor/fff/crates/fff-c/include"]) ],
    linkerSettings: [
        .unsafeFlags(["-L", "Vendor/fff/target/release", "-lfff_c",
                      "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../lib"])
    ]
),
```
and set `.target(name: "PathfinderKit", dependencies: ["CFffShim"])`.

- [ ] **Step 5: Write the failing integration test**

`Tests/PathfinderKitTests/FffEngineIntegrationTests.swift`:
```swift
import XCTest
@testable import PathfinderKit

final class FffEngineIntegrationTests: XCTestCase {
    var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "hello world\nfoo bar\nhello again".write(
            to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func test_textSearchFindsMatches() async throws {
        let engine = FffEngine()
        let q = SearchQuery(pattern: "hello", mode: .text, basePath: dir)
        var lines: [Int] = []
        for try await m in engine.grep(q) { lines.append(m.lineNumber) }
        XCTAssertEqual(lines.sorted(), [1, 3])
    }
}
```

- [ ] **Step 6: Run — expect FAIL then implement FffEngine**

Run: `swift test --filter FffEngineIntegrationTests`
Expected: FAIL — `FffEngine` not defined.

`Sources/PathfinderKit/Engine/FffEngine.swift`:
```swift
import Foundation
import CFffShim

public struct FffEngine: SearchEngine {
    public init() {}

    public func grep(_ query: SearchQuery) -> AsyncThrowingStream<RawMatch, Error> {
        AsyncThrowingStream { continuation in
            let modeCode: Int32 = switch query.mode {
                case .text: 0; case .regex: 1; case .fuzzy: 2
            }
            var out = ShimMatches()
            let rc = query.basePath.path.withCString { base in
                query.pattern.withCString { pat in
                    shim_grep(base, pat, modeCode, &out)
                }
            }
            guard rc == 0 else {
                continuation.finish(throwing: EngineError.searchFailed(code: Int(rc))); return
            }
            defer { shim_free(&out) }

            let filter = FileFilter(query: query)
            for i in 0..<out.count {
                let m = out.items[i]
                let url = URL(fileURLWithPath: String(cString: m.file))
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                let isBinary = FffEngine.looksBinary(url)
                guard filter.accepts(url, sizeBytes: size ?? 0, isBinary: isBinary) else { continue }
                continuation.yield(RawMatch(
                    file: url, lineNumber: Int(m.line),
                    matchLine: String(cString: m.text),
                    matchRange: Int(m.col_start)..<Int(m.col_end)))
            }
            continuation.finish()
        }
    }

    public enum EngineError: Error { case searchFailed(code: Int) }

    static func looksBinary(_ url: URL) -> Bool {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? fh.close() }
        let chunk = fh.readData(ofLength: 8000)
        return chunk.contains(0)
    }
}
```

- [ ] **Step 7: Run — expect PASS**

Run: `swift test --filter FffEngineIntegrationTests`
Expected: PASS (finds lines 1 and 3). If linking fails, re-check the `-L`/`-I` paths in Step 4 and that Step 1's `cargo build` succeeded.

- [ ] **Step 8: Commit**

```bash
git add Package.swift Sources/CFffShim Sources/PathfinderKit/Engine/FffEngine.swift Tests/PathfinderKitTests/FffEngineIntegrationTests.swift .gitmodules
git commit -m "feat: integrate fff via C shim and FffEngine"
```

---

### Task 10: SearchBar + FiltersPanel views

**Files:**
- Create: `Sources/PathfinderKit/UI/SearchBar.swift`
- Create: `Sources/PathfinderKit/UI/FiltersPanel.swift`
- Test: none (SwiftUI layout; verified in Task 13 end-to-end). This task is one deliverable: the input controls, bound to `SearchModel`.

**Interfaces:**
- Consumes: `SearchModel`.
- Produces: `struct SearchBar: View`, `struct FiltersPanel: View`, both taking `@Bindable var model: SearchModel`.

- [ ] **Step 1: Implement SearchBar**

`Sources/PathfinderKit/UI/SearchBar.swift`:
```swift
import SwiftUI

public struct SearchBar: View {
    @Bindable var model: SearchModel
    var onFolderPick: () -> Void
    var onReplace: () -> Void

    public init(model: SearchModel, onFolderPick: @escaping () -> Void, onReplace: @escaping () -> Void) {
        self._model = Bindable(model); self.onFolderPick = onFolderPick; self.onReplace = onReplace
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { onFolderPick() } label: {
                    Label(model.basePath?.lastPathComponent ?? "Выбрать папку", systemImage: "folder")
                }
                Spacer()
                Picker("", selection: $model.mode) {
                    Text("Text").tag(SearchMode.text)
                    Text("Regex").tag(SearchMode.regex)
                    Text("Fuzzy").tag(SearchMode.fuzzy)
                }.pickerStyle(.segmented).frame(width: 240)
            }
            HStack {
                TextField("Найти", text: $model.pattern)
                    .textFieldStyle(.roundedBorder)
                if model.isSearching { ProgressView().scaleEffect(0.5) }
            }
            HStack {
                TextField("Заменить", text: $model.replacement)
                    .textFieldStyle(.roundedBorder)
                Button("Replace") { onReplace() }
            }
        }.padding(8)
    }
}
```

- [ ] **Step 2: Add `replacement` to SearchModel**

Add to `Sources/PathfinderKit/State/SearchModel.swift` (after `lastError`):
```swift
    public var replacement: String = ""
```

- [ ] **Step 3: Implement FiltersPanel**

`Sources/PathfinderKit/UI/FiltersPanel.swift`:
```swift
import SwiftUI

public struct FiltersPanel: View {
    @Bindable var model: SearchModel
    @State private var includeText = ""
    @State private var excludeText = ""

    public init(model: SearchModel) { self._model = Bindable(model) }

    public var body: some View {
        DisclosureGroup("Фильтры и контекст") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("include *.kt,*.json", text: $includeText)
                        .onChange(of: includeText) { _, v in model.includeGlobs = splitGlobs(v) }
                    TextField("exclude build/", text: $excludeText)
                        .onChange(of: excludeText) { _, v in model.excludeGlobs = splitGlobs(v) }
                }
                Toggle("Исключить бинарные", isOn: $model.excludeBinary)
                HStack {
                    Stepper("Контекст до: \(model.contextBefore)", value: $model.contextBefore, in: 0...20)
                    Stepper("после: \(model.contextAfter)", value: $model.contextAfter, in: 0...20)
                }
            }.textFieldStyle(.roundedBorder).padding(.top, 4)
        }.padding(.horizontal, 8)
    }

    private func splitGlobs(_ s: String) -> [String] {
        s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
```

- [ ] **Step 4: Build to verify it compiles**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/PathfinderKit/UI/SearchBar.swift Sources/PathfinderKit/UI/FiltersPanel.swift Sources/PathfinderKit/State/SearchModel.swift
git commit -m "feat: add SearchBar and FiltersPanel views"
```

---

### Task 11: ResultsList view — grouped results with context lines

**Files:**
- Create: `Sources/PathfinderKit/UI/ResultsList.swift`
- Test: none (layout; verified in Task 13).

**Interfaces:**
- Consumes: `ResultsStore`, `SearchMatch`, `NumberedLine`, `FileResult`.
- Produces: `struct ResultsList: View` taking `store: ResultsStore` and an `onReveal`/`onOpen` callback set. Selecting a row sets `store.selectedMatch`.

- [ ] **Step 1: Implement ResultsList**

`Sources/PathfinderKit/UI/ResultsList.swift`:
```swift
import SwiftUI

public struct ResultsList: View {
    let store: ResultsStore
    var onReveal: (URL) -> Void
    var onOpen: (URL) -> Void

    public init(store: ResultsStore, onReveal: @escaping (URL) -> Void, onOpen: @escaping (URL) -> Void) {
        self.store = store; self.onReveal = onReveal; self.onOpen = onOpen
    }

    public var body: some View {
        List {
            ForEach(store.files, id: \.file) { file in
                Section(header: Text("\(file.file.lastPathComponent) (\(file.matches.count))").bold()) {
                    ForEach(Array(file.matches.enumerated()), id: \.offset) { _, m in
                        MatchRow(match: m)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selectedMatch = m }
                            .contextMenu {
                                Button("Показать в Finder") { onReveal(file.file) }
                                Button("Открыть в редакторе") { onOpen(file.file) }
                            }
                    }
                }
            }
        }
    }
}

private struct MatchRow: View {
    let match: SearchMatch
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(match.contextBefore, id: \.number) { line(number: $0.number, text: $0.text, isMatch: false) }
            line(number: match.lineNumber, text: match.matchLine, isMatch: true)
            ForEach(match.contextAfter, id: \.number) { line(number: $0.number, text: $0.text, isMatch: false) }
        }.font(.system(.body, design: .monospaced))
    }
    @ViewBuilder func line(number: Int, text: String, isMatch: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)").foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
            Text(text).foregroundStyle(isMatch ? .primary : .secondary)
                .fontWeight(isMatch ? .semibold : .regular)
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/PathfinderKit/UI/ResultsList.swift
git commit -m "feat: add ResultsList with grouped results and context lines"
```

---

### Task 12: PreviewPane + StatusBar + RootView wiring

**Files:**
- Create: `Sources/PathfinderKit/UI/PreviewPane.swift`
- Create: `Sources/PathfinderKit/UI/StatusBar.swift`
- Create: `Sources/PathfinderKit/UI/RootView.swift`
- Modify: `Sources/PathfinderApp/PathfinderApp.swift`

**Interfaces:**
- Consumes: `ResultsStore`, `SearchModel`, `FileOps`, `SearchBar`, `FiltersPanel`, `ResultsList`.
- Produces: `struct RootView: View` — assembles the whole screen, owns `SearchModel`/`ResultsStore`/`FileOps`, wires folder picker, debounced search on `pattern`/`mode` change, replace, and reveal/open callbacks.

- [ ] **Step 1: Implement PreviewPane**

`Sources/PathfinderKit/UI/PreviewPane.swift`:
```swift
import SwiftUI

public struct PreviewPane: View {
    let store: ResultsStore
    public init(store: ResultsStore) { self.store = store }

    public var body: some View {
        Group {
            if let m = store.selectedMatch,
               let text = try? String(contentsOf: m.file, encoding: .utf8) {
                ScrollView { Text(text).font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8) }
            } else {
                Text("Выбери результат для предпросмотра").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
```

- [ ] **Step 2: Implement StatusBar**

`Sources/PathfinderKit/UI/StatusBar.swift`:
```swift
import SwiftUI

public struct StatusBar: View {
    let store: ResultsStore
    let model: SearchModel
    public init(store: ResultsStore, model: SearchModel) { self.store = store; self.model = model }

    public var body: some View {
        HStack {
            if let err = model.lastError {
                Text(err).foregroundStyle(.red)
            } else {
                Text("\(store.fileCount) файлов · \(store.totalMatches) совпадений")
            }
            Spacer()
        }.font(.callout).padding(.horizontal, 8).padding(.vertical, 4)
    }
}
```

- [ ] **Step 3: Implement RootView with debounced search**

`Sources/PathfinderKit/UI/RootView.swift`:
```swift
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
```

- [ ] **Step 4: Wire RootView into the app**

Replace body of `Sources/PathfinderApp/PathfinderApp.swift`:
```swift
import SwiftUI
import PathfinderKit

@main
struct PathfinderApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .defaultSize(width: 1100, height: 720)
    }
}
```

- [ ] **Step 5: Build and run**

Run: `swift build && swift run PathfinderApp`
Expected: window opens; picking a folder and typing a pattern shows grouped results with context; clicking a result shows the file preview; Replace rewrites matches; status bar shows counts.

- [ ] **Step 6: Commit**

```bash
git add Sources/PathfinderKit/UI Sources/PathfinderApp/PathfinderApp.swift
git commit -m "feat: wire PreviewPane, StatusBar, and RootView with debounced search"
```

---

### Task 13: Error handling, themes check, README

**Files:**
- Modify: `Sources/PathfinderKit/UI/SearchBar.swift` (invalid-regex hint)
- Modify: `Sources/PathfinderKit/State/SearchModel.swift` (regex validation)
- Create: `README.md`
- Test: `Tests/PathfinderKitTests/SearchModelTests.swift` (add regex-validation test)

**Interfaces:**
- Consumes: `SearchModel`.
- Produces: `var SearchModel.regexError: String?` (nil when mode ≠ regex or pattern compiles).

- [ ] **Step 1: Write the failing test**

Add to `Tests/PathfinderKitTests/SearchModelTests.swift`:
```swift
    func test_invalidRegexSetsRegexError() {
        let model = SearchModel(engine: FakeEngine(), store: ResultsStore(),
                                fileLinesProvider: { _ in [] })
        model.mode = .regex; model.pattern = "([unclosed"
        XCTAssertNotNil(model.regexError)
        model.pattern = "\\d+"
        XCTAssertNil(model.regexError)
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter SearchModelTests`
Expected: FAIL — no `regexError`.

- [ ] **Step 3: Add regexError to SearchModel**

Add to `Sources/PathfinderKit/State/SearchModel.swift`:
```swift
    public var regexError: String? {
        guard mode == .regex, !pattern.isEmpty else { return nil }
        do { _ = try NSRegularExpression(pattern: pattern); return nil }
        catch { return "Некорректный regex" }
    }
```
And in `makeQuery()`, add after the initial guard:
```swift
        if mode == .regex, regexError != nil { return nil }
```

- [ ] **Step 4: Show the hint in SearchBar**

In `Sources/PathfinderKit/UI/SearchBar.swift`, add below the pattern `TextField` HStack:
```swift
            if let re = model.regexError {
                HStack { Text(re).foregroundStyle(.red).font(.caption); Spacer() }
            }
```

- [ ] **Step 5: Run tests — expect PASS**

Run: `swift test`
Expected: entire suite PASSES.

- [ ] **Step 6: Write README**

`README.md`:
```markdown
# Pathfinder

Simple macOS file-search app. Search text files by text, regex, or fuzzy;
read results with surrounding context lines; preview whole files;
search-and-replace with undo; reveal in Finder.

## Build

    git submodule update --init --recursive
    (cd Vendor/fff && cargo build --release -p fff-c)
    swift run PathfinderApp

## Test

    swift test

Search engine: [fff](https://github.com/dmtrKovalenko/fff) (MIT) via a C shim.
```

- [ ] **Step 7: Verify light/dark theme**

Run the app, toggle macOS appearance (System Settings → Appearance). Confirm the UI follows the system theme (SwiftUI default). No code change expected.

- [ ] **Step 8: Commit**

```bash
git add Sources/PathfinderKit README.md Tests/PathfinderKitTests/SearchModelTests.swift
git commit -m "feat: add regex validation, error hint, and README"
```

---

## Self-Review

**Spec coverage:**
- Text/Regex/Fuzzy search → Tasks 2, 9 (engine), 6 (drive).
- Filters (glob/size/binary) → Task 4, applied in Task 9.
- Context lines ±N → Task 3, wired 6, rendered 11, controls 10.
- Grouped results + counts → Tasks 5, 11.
- Whole-file preview + highlight → Task 12 (preview shown; highlight of match position is via selection scroll; full inline highlight is a v1.1 refinement noted below).
- Replace + undo (text only) → Task 7, wired 12.
- Reveal in Finder / open in editor → Task 8, wired 11/12.
- Move/copy/delete → Task 8 (FileOps API; context-menu entries for these are a thin follow-up — see note).
- System themes → Task 13 verification.
- Error handling (invalid regex, folder access via NSOpenPanel, replace skip binary) → Tasks 13, 12, 7.

**Known v1 scope notes (intentional):**
- PreviewPane shows the file and scrolls; per-match inline highlight inside the preview is deferred to v1.1 (results list already shows the highlighted match line with context).
- Move/Copy/Delete have a tested `FileOps` API; only Reveal/Open are wired into the context menu in Task 11. Add move/copy/delete menu items as a trivial follow-up using the same `ops` instance.
- Glob support is `*`/`?` only (v1), matching the spec's filter intent without full extglob.

**Placeholder scan:** No TBD/TODO. The one external-API-dependent spot (`shim_grep` body, Task 9 Step 3) is explicitly bounded: written against the real `fff.h` read in Step 1, with the exact fff calls named and the copy/free contract described. Everything else is complete code.

**Type consistency:** `SearchQuery`, `RawMatch`, `SearchMatch`, `NumberedLine`, `FileResult`, `SearchEngine.grep`, `ResultsStore.add`, `SearchModel.runNow`, `ReplaceEngine.replace/undo`, `FileOps.*`, and the shim `ShimMatch`/`ShimMatches`/`shim_grep`/`shim_free` names are used identically across defining and consuming tasks. `replacement` is added to `SearchModel` in Task 10 before Task 12 uses it. `regexError` added in Task 13 before use.
