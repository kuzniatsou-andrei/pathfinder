import Foundation
@testable import PathfinderKit

/// Deterministic engine for testing everything above the real native engine.
struct FakeEngine: SearchEngine {
    var matches: [RawMatch] = []
    var error: Error? = nil
    func grep(_ query: SearchQuery) -> AsyncThrowingStream<RawMatch, Error> {
        AsyncThrowingStream { continuation in
            if let error { continuation.finish(throwing: error); return }
            for m in matches { continuation.yield(m) }
            continuation.finish()
        }
    }
}
