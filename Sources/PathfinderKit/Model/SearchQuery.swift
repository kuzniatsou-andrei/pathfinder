import Foundation

public struct SearchQuery: Sendable {
    public var pattern: String
    public var mode: SearchMode
    public var basePath: URL
    public var includeGlobs: [String]
    public var excludeGlobs: [String]
    public var maxFileSizeBytes: Int?
    public var excludeBinary: Bool
    public var contextBefore: Int
    public var contextAfter: Int

    public init(pattern: String, mode: SearchMode, basePath: URL,
                includeGlobs: [String] = [], excludeGlobs: [String] = [],
                maxFileSizeBytes: Int? = nil, excludeBinary: Bool = true,
                contextBefore: Int = 1, contextAfter: Int = 1) {
        self.pattern = pattern; self.mode = mode; self.basePath = basePath
        self.includeGlobs = includeGlobs; self.excludeGlobs = excludeGlobs
        self.maxFileSizeBytes = maxFileSizeBytes; self.excludeBinary = excludeBinary
        self.contextBefore = contextBefore; self.contextAfter = contextAfter
    }
}
