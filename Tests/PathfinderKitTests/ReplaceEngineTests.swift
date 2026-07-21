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

    func test_partialBatchFailureStillAllowsUndo() throws {
        let a = try write("a.txt", "foo")
        // b.txt lives in a subdirectory that we lock down *after* creating the
        // file, so its atomic write (which needs to create a temp file and
        // rename it in that directory) fails partway through the batch, while
        // a.txt -- in the still-writable parent dir -- succeeds first.
        let subdir = dir.appendingPathComponent("locked")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        let b = subdir.appendingPathComponent("b.txt")
        try "foo".write(to: b, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: subdir.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: subdir.path)
        }

        let engine = ReplaceEngine()
        XCTAssertThrowsError(
            try engine.replace(in: [a, b], pattern: "foo", replacement: "baz", mode: .text))

        XCTAssertTrue(engine.canUndo)

        // Fix the transient failure condition (as an operator would before
        // retrying/undoing), then undo should restore everything cleanly.
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: subdir.path)
        try engine.undo()
        XCTAssertEqual(try read(a), "foo")
    }

    func test_invalidRegexThrowsBeforeWriting() throws {
        let f = try write("d.txt", "x")
        let engine = ReplaceEngine()
        XCTAssertThrowsError(
            try engine.replace(in: [f], pattern: "([", replacement: "y", mode: .regex))
        XCTAssertEqual(try read(f), "x")
        XCTAssertFalse(engine.canUndo)
    }
}
