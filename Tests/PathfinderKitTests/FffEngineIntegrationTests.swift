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
