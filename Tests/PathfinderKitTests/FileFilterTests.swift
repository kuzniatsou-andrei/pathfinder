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

    func url(_ relativePath: String) -> URL {
        URL(fileURLWithPath: "/repo/" + relativePath)
    }

    // MARK: - Baseline behaviors preserved

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

    // MARK: - Basename patterns (no `/`, no leading `/`) match at any depth

    func test_basenameExtensionAnyDepth() {
        let filter = FileFilter(query: q(exclude: ["*.iml"]))
        XCTAssertFalse(filter.accepts(url("a/b/foo.iml"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(url("a/foo.txt"), sizeBytes: 10, isBinary: false))
    }

    func test_basenameWildcardMatchesWholeComponentOnly() {
        // Critical regression: `src-*` must exclude `src-*` folders but must NOT
        // match a component that is only a prefix of the pattern — i.e. it must
        // not exclude `src/...` (component is "src", not matching "src-*").
        let filter = FileFilter(query: q(exclude: ["src-*"]))
        XCTAssertFalse(filter.accepts(url("src-generated/x.kt"), sizeBytes: 10, isBinary: false))
        XCTAssertFalse(filter.accepts(url("src-legacy/y.kt"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(url("src/z.java"), sizeBytes: 10, isBinary: false))
    }

    func test_basenameDirectoryExcludesContents() {
        let filter = FileFilter(query: q(exclude: ["build"]))
        XCTAssertFalse(filter.accepts(url("build/x"), sizeBytes: 10, isBinary: false))
        XCTAssertFalse(filter.accepts(url("a/build/y"), sizeBytes: 10, isBinary: false))
    }

    func test_basenameDirectoryWithTrailingSlashExcludesContents() {
        let filter = FileFilter(query: q(exclude: ["build/"]))
        XCTAssertFalse(filter.accepts(url("build/x"), sizeBytes: 10, isBinary: false))
        XCTAssertFalse(filter.accepts(url("a/build/y"), sizeBytes: 10, isBinary: false))
    }

    // MARK: - Anchored patterns (leading `/`) only match at the root

    func test_anchoredDirectoryOnlyMatchesAtRoot() {
        let filter = FileFilter(query: q(exclude: ["/build"]))
        XCTAssertFalse(filter.accepts(url("build/x"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(url("a/build/y"), sizeBytes: 10, isBinary: false))
    }

    // MARK: - `**` crosses `/`

    func test_doubleStarCrossesSlash() {
        let filter = FileFilter(query: q(exclude: ["**/target"]))
        XCTAssertFalse(filter.accepts(url("target/x"), sizeBytes: 10, isBinary: false))
        XCTAssertFalse(filter.accepts(url("a/b/target/y"), sizeBytes: 10, isBinary: false))
    }

    // MARK: - `*` does not cross `/`

    func test_singleStarDoesNotCrossSlash() {
        let filter = FileFilter(query: q(exclude: ["src/*.kt"]))
        XCTAssertFalse(filter.accepts(url("src/A.kt"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(url("src/deep/A.kt"), sizeBytes: 10, isBinary: false))
    }

    // MARK: - `?` matches exactly one non-slash character

    func test_questionMarkMatchesSingleChar() {
        let filter = FileFilter(query: q(exclude: ["a?.txt"]))
        XCTAssertFalse(filter.accepts(url("a1.txt"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(url("abc.txt"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(url("a.txt"), sizeBytes: 10, isBinary: false))
    }

    // MARK: - Negation ordering (gitignore semantics)

    func test_negationReIncludesLaterMatch() {
        let filter = FileFilter(query: q(exclude: ["build", "!build/keep.txt"]))
        XCTAssertFalse(filter.accepts(url("build/x"), sizeBytes: 10, isBinary: false))
        XCTAssertTrue(filter.accepts(url("build/keep.txt"), sizeBytes: 10, isBinary: false))
    }

    // MARK: - Include whitelist

    func test_includeWhitelistFiltersByExtension() {
        let filter = FileFilter(query: q(include: ["*.kt"]))
        XCTAssertTrue(filter.accepts(url("a/x.kt"), sizeBytes: 10, isBinary: false))
        XCTAssertFalse(filter.accepts(url("a/y.java"), sizeBytes: 10, isBinary: false))
    }
}
