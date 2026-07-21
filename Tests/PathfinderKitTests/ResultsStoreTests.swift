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
