import Foundation
import AppKit

public struct FileOps {
    public init() {}

    public func move(_ src: URL, to dst: URL) throws {
        try FileManager.default.moveItem(at: src, to: dst)
    }
    public func copy(_ src: URL, to dst: URL) throws {
        try FileManager.default.copyItem(at: src, to: dst)
    }
    public func delete(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
    public func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    public func open(_ url: URL, withEditor bundleId: String?) {
        if let bundleId,
           let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let cfg = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: app, configuration: cfg)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
