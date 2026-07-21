import XCTest
@testable import PathfinderKit

final class ModelTests: XCTestCase {
    func test_searchQuery_defaults() {
        let q = SearchQuery(pattern: "x", mode: .text, basePath: URL(fileURLWithPath: "/tmp"))
        XCTAssertEqual(q.contextBefore, 1)
        XCTAssertEqual(q.contextAfter, 1)
        XCTAssertTrue(q.excludeBinary)
    }

    func test_fileResult_matchCount() {
        let m = SearchMatch(file: URL(fileURLWithPath: "/a"), lineNumber: 1,
                            matchRange: 0..<1, matchLine: "a",
                            contextBefore: [], contextAfter: [])
        XCTAssertEqual(FileResult(file: m.file, matches: [m]).matches.count, 1)
    }
}
