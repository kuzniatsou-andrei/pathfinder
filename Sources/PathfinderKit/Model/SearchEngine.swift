import Foundation

public protocol SearchEngine: Sendable {
    func grep(_ query: SearchQuery) -> AsyncThrowingStream<RawMatch, Error>
}
