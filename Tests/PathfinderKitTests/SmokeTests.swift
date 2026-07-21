import XCTest
@testable import PathfinderKit

final class SmokeTests: XCTestCase {
    func test_searchMode_hasThreeCases() {
        XCTAssertEqual(SearchMode.allCases.count, 3)
    }
}
