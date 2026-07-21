import XCTest
@testable import PathfinderKit

@MainActor
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

    func test_displayCapSkipsAssemblyBeyondLimit() async {
        let raws = (0..<5).map { i in
            RawMatch(file: URL(fileURLWithPath: "/f\(i)"), lineNumber: 1,
                     matchLine: "x", matchRange: 0..<1)
        }
        let engine = FakeEngine(matches: raws)
        let store = ResultsStore(displayLimit: 2)
        let counter = CallCounter()
        let model = SearchModel(engine: engine, store: store, fileLinesProvider: { _ in
            counter.increment()
            return ["x"]
        })
        model.pattern = "x"
        model.basePath = URL(fileURLWithPath: "/")

        await model.runNow()

        XCTAssertLessThanOrEqual(counter.count, 2)
        XCTAssertEqual(store.displayedCount, 2)
        XCTAssertEqual(store.totalMatches, 5)
    }

    func test_invalidRegexSetsRegexError() {
        let model = SearchModel(engine: FakeEngine(), store: ResultsStore(),
                                fileLinesProvider: { _ in [] })
        model.mode = .regex; model.pattern = "([unclosed"
        XCTAssertNotNil(model.regexError)
        model.pattern = "\\d+"
        XCTAssertNil(model.regexError)
    }
}

/// Thread-safe invocation counter for use inside @Sendable closures under test.
final class CallCounter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()
    func increment() { lock.lock(); value += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}
