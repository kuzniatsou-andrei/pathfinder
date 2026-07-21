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
        XCTAssertEqual(s.displayedCount, 0)
        XCTAssertEqual(s.overflowCount, 0)
    }

    func test_displayCapStoresLimitAndCountsOverflow() {
        let s = ResultsStore(displayLimit: 3)
        s.add(match("/a", 1)); s.add(match("/a", 2)); s.add(match("/b", 1))
        s.add(match("/b", 2)); s.add(match("/c", 1))

        XCTAssertEqual(s.displayedCount, 3)
        XCTAssertEqual(s.overflowCount, 2)
        XCTAssertEqual(s.totalMatches, 5)
        XCTAssertEqual(s.files.reduce(0) { $0 + $1.matches.count }, 3)
        XCTAssertFalse(s.canDisplayMore)
    }

    func test_countOverflowIncrementsWithoutStoring() {
        let s = ResultsStore(displayLimit: 1)
        s.add(match("/a", 1))
        XCTAssertTrue(s.canDisplayMore == false)
        s.countOverflow()
        XCTAssertEqual(s.displayedCount, 1)
        XCTAssertEqual(s.overflowCount, 1)
        XCTAssertEqual(s.totalMatches, 2)
        XCTAssertEqual(s.files.reduce(0) { $0 + $1.matches.count }, 1)
    }
}
