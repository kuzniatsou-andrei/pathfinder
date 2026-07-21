import Foundation

public struct ContextAssembler {
    public init() {}

    /// `raw.lineNumber` is 1-based; `fileLines` is the file split on "\n".
    public func assemble(_ raw: RawMatch, fileLines: [String], before: Int, after: Int) -> SearchMatch {
        let idx = raw.lineNumber - 1
        let beforeStart = max(0, idx - before)
        let afterEnd = min(fileLines.count - 1, idx + after)

        let ctxBefore: [NumberedLine] = (beforeStart..<idx).map {
            NumberedLine(number: $0 + 1, text: fileLines[$0])
        }
        let ctxAfter: [NumberedLine] = idx < afterEnd
            ? ((idx + 1)...afterEnd).map { NumberedLine(number: $0 + 1, text: fileLines[$0]) }
            : []

        return SearchMatch(file: raw.file, lineNumber: raw.lineNumber,
                           matchRange: raw.matchRange, matchLine: raw.matchLine,
                           contextBefore: ctxBefore, contextAfter: ctxAfter)
    }
}
