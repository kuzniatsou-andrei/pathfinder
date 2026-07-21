import XCTest
@testable import PathfinderKit

final class ContextAssemblerTests: XCTestCase {
    let lines = ["l1","l2","l3","l4","l5"]
    let raw = RawMatch(file: URL(fileURLWithPath: "/f"), lineNumber: 3,
                       matchLine: "l3", matchRange: 0..<2)

    func test_assemblesSymmetricContext() {
        let m = ContextAssembler().assemble(raw, fileLines: lines, before: 1, after: 1)
        XCTAssertEqual(m.contextBefore, [NumberedLine(number: 2, text: "l2")])
        XCTAssertEqual(m.contextAfter, [NumberedLine(number: 4, text: "l4")])
        XCTAssertEqual(m.matchLine, "l3")
        XCTAssertEqual(m.lineNumber, 3)
    }

    func test_clampsAtFileStart() {
        let first = RawMatch(file: URL(fileURLWithPath: "/f"), lineNumber: 1,
                             matchLine: "l1", matchRange: 0..<2)
        let m = ContextAssembler().assemble(first, fileLines: lines, before: 2, after: 0)
        XCTAssertEqual(m.contextBefore, [])
    }

    func test_clampsAtFileEnd() {
        let last = RawMatch(file: URL(fileURLWithPath: "/f"), lineNumber: 5,
                            matchLine: "l5", matchRange: 0..<2)
        let m = ContextAssembler().assemble(last, fileLines: lines, before: 0, after: 3)
        XCTAssertEqual(m.contextAfter, [])
    }

    func test_zeroContext() {
        let m = ContextAssembler().assemble(raw, fileLines: lines, before: 0, after: 0)
        XCTAssertTrue(m.contextBefore.isEmpty && m.contextAfter.isEmpty)
    }
}
