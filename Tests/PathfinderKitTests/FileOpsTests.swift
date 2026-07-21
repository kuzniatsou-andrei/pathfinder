import XCTest
@testable import PathfinderKit

final class FileOpsTests: XCTestCase {
    var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func write(_ name: String) throws -> URL {
        let u = dir.appendingPathComponent(name)
        try "data".write(to: u, atomically: true, encoding: .utf8)
        return u
    }

    func test_copyThenDelete() throws {
        let src = try write("a.txt")
        let dst = dir.appendingPathComponent("b.txt")
        let ops = FileOps()
        try ops.copy(src, to: dst)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.path))
        try ops.delete(src)
        XCTAssertFalse(FileManager.default.fileExists(atPath: src.path))
    }

    func test_move() throws {
        let src = try write("a.txt")
        let dst = dir.appendingPathComponent("moved.txt")
        try FileOps().move(src, to: dst)
        XCTAssertFalse(FileManager.default.fileExists(atPath: src.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.path))
    }
}
