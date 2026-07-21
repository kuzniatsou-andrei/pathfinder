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

    // Exercises the mode byte 1 (regex) path through the real fff library.
    func test_regexSearchFindsMatches() async throws {
        let engine = FffEngine()
        let q = SearchQuery(pattern: "he.lo", mode: .regex, basePath: dir)
        var lines: [Int] = []
        for try await m in engine.grep(q) { lines.append(m.lineNumber) }
        XCTAssertEqual(lines.sorted(), [1, 3])
    }

    // Exercises the FileFilter loop inside FffEngine against the real engine:
    // a second file with a different extension must be excluded by includeGlobs.
    func test_includeGlobsRestrictsToExtension() async throws {
        try "hello from markdown".write(
            to: dir.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        let engine = FffEngine()
        let q = SearchQuery(pattern: "hello", mode: .text, basePath: dir,
                            includeGlobs: ["*.txt"])
        var files: Set<String> = []
        for try await m in engine.grep(q) { files.insert(m.file.lastPathComponent) }
        XCTAssertEqual(files, ["a.txt"])
    }
    // Note: fuzzy mode (byte 2) is intentionally not asserted here — fff's fuzzy
    // ranking is non-deterministic across inputs, so a stable expectation isn't
    // possible; the text and regex paths cover the mode-byte plumbing.
}
