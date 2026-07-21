import XCTest
@testable import PathfinderKit

final class FolderMemoryTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "test." + UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)
    }
    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_saveThenLoadReturnsExistingDirectory() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let mem = FolderMemory(defaults: defaults)
        mem.save(dir)
        XCTAssertEqual(mem.loadValidDirectory()?.path, dir.path)
    }

    func test_loadNilWhenNothingSaved() {
        XCTAssertNil(FolderMemory(defaults: defaults).loadValidDirectory())
    }

    func test_loadNilWhenSavedPathMissing() {
        let mem = FolderMemory(defaults: defaults)
        mem.save(URL(fileURLWithPath: "/no/such/dir-\(UUID().uuidString)"))
        XCTAssertNil(mem.loadValidDirectory())
    }

    func test_loadNilWhenSavedPathIsAFile() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let mem = FolderMemory(defaults: defaults)
        mem.save(file)
        XCTAssertNil(mem.loadValidDirectory())  // a file is not a valid directory
    }
}
