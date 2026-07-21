import Foundation
import Observation

@Observable
public final class ResultsStore {
    public private(set) var files: [FileResult] = []
    public var selectedMatch: SearchMatch?
    public let displayLimit: Int
    public private(set) var displayedCount: Int = 0
    public private(set) var overflowCount: Int = 0
    private var indexByPath: [String: Int] = [:]

    public init(displayLimit: Int = 100) {
        self.displayLimit = displayLimit
    }

    public func reset() {
        files = []; indexByPath = [:]; selectedMatch = nil
        displayedCount = 0; overflowCount = 0
    }

    public var canDisplayMore: Bool { displayedCount < displayLimit }

    public func add(_ match: SearchMatch) {
        guard canDisplayMore else { overflowCount += 1; return }
        let key = match.file.path
        if let i = indexByPath[key] {
            files[i] = FileResult(file: files[i].file, matches: files[i].matches + [match])
        } else {
            indexByPath[key] = files.count
            files.append(FileResult(file: match.file, matches: [match]))
        }
        displayedCount += 1
    }

    public func countOverflow() {
        overflowCount += 1
    }

    public var totalMatches: Int { displayedCount + overflowCount }
    public var fileCount: Int { files.count }
}
