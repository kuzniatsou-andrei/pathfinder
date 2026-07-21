import Foundation

/// Persists the last searched folder so it can be restored on the next launch.
/// Stores a plain path string in UserDefaults (the app runs unsandboxed, so no
/// security-scoped bookmark is required).
public struct FolderMemory {
    private let defaults: UserDefaults
    private let key = "pathfinder.lastFolder"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func save(_ url: URL) {
        defaults.set(url.path, forKey: key)
    }

    /// The saved folder, but only if it still exists and is a directory.
    public func loadValidDirectory() -> URL? {
        guard let path = defaults.string(forKey: key), !path.isEmpty else { return nil }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
}
