import XCTest
@testable import PathfinderKit

final class SearchHistoryTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "test." + UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)
    }
    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_addThenItemsReturnsPattern() {
        let history = SearchHistory(defaults: defaults)
        history.add("hello")
        XCTAssertEqual(history.items(), ["hello"])
    }

    func test_addEmptyOrWhitespaceIsIgnored() {
        let history = SearchHistory(defaults: defaults)
        history.add("")
        history.add("   ")
        XCTAssertEqual(history.items(), [])
    }

    func test_addTrimsWhitespace() {
        let history = SearchHistory(defaults: defaults)
        history.add("  hello  ")
        XCTAssertEqual(history.items(), ["hello"])
    }

    func test_addingExistingPatternMovesItToFrontNoDuplicate() {
        let history = SearchHistory(defaults: defaults)
        history.add("A")
        history.add("B")
        history.add("A")
        XCTAssertEqual(history.items(), ["A", "B"])
    }

    func test_capAt50DropsOldest() {
        let history = SearchHistory(defaults: defaults)
        for i in 1...55 {
            history.add("pattern-\(i)")
        }
        let items = history.items()
        XCTAssertEqual(items.count, 50)
        XCTAssertEqual(items.first, "pattern-55")
        XCTAssertFalse(items.contains("pattern-1"))
        XCTAssertFalse(items.contains("pattern-5"))
        XCTAssertTrue(items.contains("pattern-6"))
    }

    func test_removeDropsOnlyThatEntry() {
        let history = SearchHistory(defaults: defaults)
        history.add("A")
        history.add("B")
        history.add("C")
        history.remove("B")
        XCTAssertEqual(history.items(), ["C", "A"])
    }

    func test_clearEmptiesHistory() {
        let history = SearchHistory(defaults: defaults)
        history.add("A")
        history.add("B")
        history.clear()
        XCTAssertEqual(history.items(), [])
    }
}
