import Foundation

public struct NumberedLine: Equatable, Sendable {
    public let number: Int
    public let text: String
    public init(number: Int, text: String) { self.number = number; self.text = text }
}

public struct SearchMatch: Equatable, Sendable {
    public let file: URL
    public let lineNumber: Int
    public let matchRange: Range<Int>
    public let matchLine: String
    public let contextBefore: [NumberedLine]
    public let contextAfter: [NumberedLine]
    public init(file: URL, lineNumber: Int, matchRange: Range<Int>, matchLine: String,
                contextBefore: [NumberedLine], contextAfter: [NumberedLine]) {
        self.file = file; self.lineNumber = lineNumber; self.matchRange = matchRange
        self.matchLine = matchLine; self.contextBefore = contextBefore; self.contextAfter = contextAfter
    }
}

extension SearchMatch: Identifiable {
    /// Globally-unique, stable row identity (file + line + match range) so
    /// SwiftUI never reuses one match's row view for another's content.
    public var id: String { "\(file.path):\(lineNumber):\(matchRange.lowerBound)-\(matchRange.upperBound)" }
}

public struct FileResult: Equatable, Sendable {
    public let file: URL
    public let matches: [SearchMatch]
    public init(file: URL, matches: [SearchMatch]) { self.file = file; self.matches = matches }
}
