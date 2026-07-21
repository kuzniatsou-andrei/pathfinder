import Foundation

public struct FileFilter {
    private let query: SearchQuery
    public init(query: SearchQuery) { self.query = query }

    public func accepts(_ url: URL, sizeBytes: Int, isBinary: Bool) -> Bool {
        if query.excludeBinary && isBinary { return false }
        if let max = query.maxFileSizeBytes, sizeBytes > max { return false }
        if query.excludeGlobs.contains(where: { matches(url, glob: $0) }) { return false }
        if !query.includeGlobs.isEmpty &&
            !query.includeGlobs.contains(where: { matches(url, glob: $0) }) { return false }
        return true
    }

    private func matches(_ url: URL, glob: String) -> Bool {
        let target = glob.contains("/")
            ? url.path.replacingOccurrences(of: query.basePath.path + "/", with: "")
            : url.lastPathComponent
        return globToRegex(glob).firstMatch(
            in: target, range: NSRange(target.startIndex..., in: target)) != nil
    }

    private func globToRegex(_ glob: String) -> NSRegularExpression {
        var re = "^"
        for ch in glob {
            switch ch {
            case "*": re += "[^/]*"
            case "?": re += "[^/]"
            case ".", "(", ")", "+", "|", "^", "$", "\\", "[", "]", "{", "}":
                re += "\\" + String(ch)
            default: re += String(ch)
            }
        }
        re += "$"
        return try! NSRegularExpression(pattern: re)
    }
}
