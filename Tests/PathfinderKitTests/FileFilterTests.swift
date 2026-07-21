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
