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
