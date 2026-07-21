import Foundation

public struct RawMatch: Equatable, Sendable {
    public let file: URL
    public let lineNumber: Int
    public let matchLine: String
    public let matchRange: Range<Int>
    public init(file: URL, lineNumber: Int, matchLine: String, matchRange: Range<Int>) {
        self.file = file; self.lineNumber = lineNumber
        self.matchLine = matchLine; self.matchRange = matchRange
    }
}
