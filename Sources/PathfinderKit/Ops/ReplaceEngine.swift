import Foundation

public final class ReplaceEngine {
    public struct ReplaceReport {
        public let changedFiles: [URL]
        public let skipped: [(URL, String)]
    }

    private var undoStack: [[URL: String]] = []
    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }

    public func replace(in files: [URL], pattern: String, replacement: String,
                        mode: SearchMode) throws -> ReplaceReport {
        var changed: [URL] = []
        var skipped: [(URL, String)] = []
        var snapshot: [URL: String] = [:]

        // Fail-fast: compile regex once, before any file is touched, so an
        // invalid pattern throws before we've mutated anything.
        let regex: NSRegularExpression?
        switch mode {
        case .regex: regex = try NSRegularExpression(pattern: pattern)
        case .text, .fuzzy: regex = nil
        }

        do {
            for file in files {
                guard let original = try? String(contentsOf: file, encoding: .utf8) else {
                    skipped.append((file, "not a UTF-8 text file")); continue
                }
                let updated: String
                switch mode {
                case .regex:
                    updated = regex!.stringByReplacingMatches(
                        in: original, range: NSRange(original.startIndex..., in: original),
                        withTemplate: NSRegularExpression.escapedTemplate(for: replacement))
                case .text, .fuzzy:
                    updated = original.replacingOccurrences(of: pattern, with: replacement)
                }
                if updated != original {
                    snapshot[file] = original
                    try updated.write(to: file, atomically: true, encoding: .utf8)
                    changed.append(file)
                }
            }
        } catch {
            // Preserve the undo snapshot for whatever was already written
            // before the failure, so undo() can still roll those files back.
            if !snapshot.isEmpty { undoStack.append(snapshot) }
            throw error
        }
        if !snapshot.isEmpty { undoStack.append(snapshot) }
        return ReplaceReport(changedFiles: changed, skipped: skipped)
    }

    public func undo() throws {
        guard let last = undoStack.popLast() else { return }
        for (file, content) in last {
            try content.write(to: file, atomically: true, encoding: .utf8)
        }
    }
}
