import Foundation

public struct FileFilter {
    private let query: SearchQuery
    public init(query: SearchQuery) { self.query = query }

    public func accepts(_ url: URL, sizeBytes: Int, isBinary: Bool) -> Bool {
        if query.excludeBinary && isBinary { return false }
        if let max = query.maxFileSizeBytes, sizeBytes > max { return false }

        let rel = relativePath(for: url)

        if isExcluded(rel) { return false }

        if !query.includeGlobs.isEmpty {
            let includePatterns = query.includeGlobs.compactMap { GitignorePattern($0) }
            let nonNegated = includePatterns.filter { !$0.negated }
            if !nonNegated.contains(where: { $0.matches(rel) }) { return false }
        }

        return true
    }

    private func relativePath(for url: URL) -> String {
        let basePrefix = query.basePath.path + "/"
        if url.path.hasPrefix(basePrefix) {
            return String(url.path.dropFirst(basePrefix.count))
        }
        return url.lastPathComponent
    }

    /// gitignore-style ordering: later patterns override earlier ones;
    /// a negated (`!`) pattern re-includes a path an earlier pattern excluded.
    private func isExcluded(_ rel: String) -> Bool {
        var excluded = false
        for raw in query.excludeGlobs {
            guard let pattern = GitignorePattern(raw) else { continue }
            if pattern.matches(rel) {
                excluded = !pattern.negated
            }
        }
        return excluded
    }
}

/// A single gitignore-style pattern compiled to a regular expression, plus the
/// metadata (negated / anchored) needed to evaluate it against a relative path.
private struct GitignorePattern {
    let negated: Bool
    let anchored: Bool
    private let regex: NSRegularExpression?

    /// Parses one pattern per gitignore semantics:
    /// - leading `!` negates (re-includes),
    /// - a trailing `/` marks a directory pattern (contents excluded too),
    /// - a leading `/` (or any internal `/`) anchors the pattern to the root;
    ///   otherwise it is a basename pattern matched at any depth.
    init?(_ raw: String) {
        var body = raw.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return nil }

        var isNegated = false
        if body.hasPrefix("!") {
            isNegated = true
            body.removeFirst()
        }

        if body.hasSuffix("/") {
            body.removeLast()
        }
        guard !body.isEmpty else { return nil }

        var isAnchored = false
        if body.hasPrefix("/") {
            isAnchored = true
            body.removeFirst()
        }
        if body.contains("/") {
            isAnchored = true
        }
        guard !body.isEmpty else { return nil }

        self.negated = isNegated
        self.anchored = isAnchored
        self.regex = GitignorePattern.buildRegex(body)
    }

    /// Basename patterns match if ANY path component full-matches.
    /// Anchored/path patterns match if the pattern full-matches the whole
    /// relative path OR any ancestor-directory prefix of it (so a directory
    /// pattern also excludes everything underneath it).
    func matches(_ rel: String) -> Bool {
        guard let regex else { return false }
        let components = rel.split(separator: "/", omittingEmptySubsequences: false).map(String.init)

        if anchored {
            var prefix = ""
            for (idx, comp) in components.enumerated() {
                prefix = idx == 0 ? comp : prefix + "/" + comp
                if fullMatch(regex, prefix) { return true }
            }
            return false
        } else {
            return components.contains { fullMatch(regex, $0) }
        }
    }

    private func fullMatch(_ regex: NSRegularExpression, _ s: String) -> Bool {
        let range = NSRange(s.startIndex..., in: s)
        guard let m = regex.firstMatch(in: s, range: range) else { return false }
        return m.range == range
    }

    private static let metacharacters: Set<Character> = [
        ".", "(", ")", "+", "|", "^", "$", "\\", "[", "]", "{", "}"
    ]

    /// Translates gitignore-style wildcards to a regex fragment, then wraps it
    /// with `^...$` for a full-string match:
    /// - `**/` crosses `/` and may match zero directories → `(?:.*/)?`
    /// - `**` (not followed by `/`) crosses `/` → `.*`
    /// - `*` does not cross `/` → `[^/]*`
    /// - `?` matches exactly one non-`/` character → `[^/]`
    /// - everything else is escaped literally.
    private static func buildRegex(_ pattern: String) -> NSRegularExpression? {
        let chars = Array(pattern)
        var re = "^"
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "*" {
                var j = i
                while j < chars.count && chars[j] == "*" { j += 1 }
                let starCount = j - i
                if starCount >= 2 {
                    if j < chars.count && chars[j] == "/" {
                        re += "(?:.*/)?"
                        i = j + 1
                    } else {
                        re += ".*"
                        i = j
                    }
                } else {
                    re += "[^/]*"
                    i = j
                }
            } else if c == "?" {
                re += "[^/]"
                i += 1
            } else if metacharacters.contains(c) {
                re += "\\" + String(c)
                i += 1
            } else {
                re += String(c)
                i += 1
            }
        }
        re += "$"
        return try? NSRegularExpression(pattern: re)
    }
}
