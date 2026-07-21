import Foundation

/// Persists a de-duplicated, most-recent-first list of search patterns
/// (last 50) in UserDefaults, so the search bar can offer a history popover.
public struct SearchHistory {
    private let defaults: UserDefaults
    private let key = "pathfinder.searchHistory"
    private let maxItems = 50

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// Most-recent first.
    public func items() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    public func add(_ pattern: String) {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var current = items()
        current.removeAll { $0 == trimmed }
        current.insert(trimmed, at: 0)
        if current.count > maxItems {
            current = Array(current.prefix(maxItems))
        }
        defaults.set(current, forKey: key)
    }

    public func remove(_ pattern: String) {
        var current = items()
        current.removeAll { $0 == pattern }
        defaults.set(current, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
