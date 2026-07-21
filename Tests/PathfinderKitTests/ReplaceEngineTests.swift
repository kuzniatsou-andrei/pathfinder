import XCTest
@testable import PathfinderKit

final class ReplaceEngineTests: XCTestCase {
    var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func write(_ name: String, _ content: String) throws -> URL {
        let u = dir.appendingPathComponent(name)
        try content.write(to: u, atomically: true, encoding: .utf8)
        return u
    }
    func read(_ u: URL) throws -> String { try String(contentsOf: u, encoding: .utf8) }

    func test_literalReplaceAndUndo() throws {
        let f = try write("a.txt", "foo bar foo")
        let engine = ReplaceEngine()
        let report = try engine.replace(in: [f], pattern: "foo", replacement: "baz", mode: .text)
        XCTAssertEqual(report.changedFiles, [f])
        XCTAssertEqual(try read(f), "baz bar baz")
        XCTAssertTrue(engine.canUndo)
        try engine.undo()
        XCTAssertEqual(try read(f), "foo bar foo")
    }

    func test_regexReplace() throws {
        let f = try write("b.txt", "id=42 id=7")
        let engine = ReplaceEngine()
        _ = try engine.replace(in: [f], pattern: #"id=\d+"#, replacement: "id=X", mode: .regex)
        XCTAssertEqual(try read(f), "id=X id=X")
    }

    func test_skipsBinary() throws {
        let u = dir.appendingPathComponent("c.bin")
        try Data([0xFF, 0x00, 0xFE]).write(to: u)
        let engine = ReplaceEngine()
        let report = try engine.replace(in: [u], pattern: "x", replacement: "y", mode: .text)
        XCTAssertTrue(report.changedFiles.isEmpty)
        XCTAssertEqual(report.skipped.count, 1)
    }
}
