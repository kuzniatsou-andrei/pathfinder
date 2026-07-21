import Foundation
import Observation

@Observable
public final class ResultsStore {
    public private(set) var files: [FileResult] = []
    public var selectedMatch: SearchMatch?
    private var indexByPath: [String: Int] = [:]

    public init() {}

    public func reset() {
        files = []; indexByPath = [:]; selectedMatch = nil
    }

    public func add(_ match: SearchMatch) {
        let key = match.file.path
        if let i = indexByPath[key] {
            files[i] = FileResult(file: files[i].file, matches: files[i].matches + [match])
        } else {
            indexByPath[key] = files.count
            files.append(FileResult(file: match.file, matches: [match]))
        }
    }

    public var totalMatches: Int { files.reduce(0) { $0 + $1.matches.count } }
    public var fileCount: Int { files.count }
}
