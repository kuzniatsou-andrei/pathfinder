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

    func test_excludeDirectoryByBareName() {
        let filter = FileFilter(query: q(exclude: ["build"]))
        XCTAssertFalse(filter.accepts(URL(fileURLWithPath: "/repo/build/gen/X.java"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(URL(fileURLWithPath: "/repo/src/App.kt"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(URL(fileURLWithPath: "/repo/mybuild/Y.java"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(URL(fileURLWithPath: "/repo/buildfile.txt"), sizeBytes: 10, isBinary: false))
    }

    func test_excludeByExtensionAnyDepth() {
        let filter = FileFilter(query: q(exclude: ["*.iml"]))
        XCTAssertFalse(filter.accepts(URL(fileURLWithPath: "/repo/a/b/foo.iml"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(URL(fileURLWithPath: "/repo/a/foo.txt"), sizeBytes: 10, isBinary: false))
    }

    func test_singleCharWildcardBang() {
        let filter = FileFilter(query: q(exclude: ["te!t.txt"]))
        XCTAssertFalse(filter.accepts(URL(fileURLWithPath: "/repo/x/test.txt"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(URL(fileURLWithPath: "/repo/x/teest.txt"), sizeBytes: 10, isBinary: false))
    }

    func test_questionMarkIsLiteralNow() {
        let filter = FileFilter(query: q(exclude: ["a?.txt"]))
        XCTAssertFalse(filter.accepts(URL(fileURLWithPath: "/repo/a?.txt"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(URL(fileURLWithPath: "/repo/ab.txt"), sizeBytes: 10, isBinary: false))
    }

    func test_includeByDirectory() {
        let filter = FileFilter(query: q(include: ["src"]))
        XCTAssertTrue(filter.accepts(URL(fileURLWithPath: "/repo/src/App.kt"), sizeBytes: 10, isBinary: false))
        XCTAssertFalse(filter.accepts(URL(fileURLWithPath: "/repo/test/App.kt"), sizeBytes: 10, isBinary: false))
    }
}
