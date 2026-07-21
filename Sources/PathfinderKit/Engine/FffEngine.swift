import Foundation
import CFffShim

/// The real `SearchEngine`, backed by the vendored `fff` library through the
/// project-authored `CFffShim`. This is the only Swift file that imports the shim.
public struct FffEngine: SearchEngine {
    public init() {}

    public func grep(_ query: SearchQuery) -> AsyncThrowingStream<RawMatch, Error> {
        AsyncThrowingStream { continuation in
            let modeCode: Int32 = switch query.mode {
                case .text: 0
                case .regex: 1
                case .fuzzy: 2
            }
            var out = ShimMatches()
            let rc = query.basePath.path.withCString { base in
                query.pattern.withCString { pat in
                    shim_grep(base, pat, modeCode, &out)
                }
            }
            guard rc == 0 else {
                continuation.finish(throwing: EngineError.searchFailed(code: Int(rc)))
                return
            }
            defer { shim_free(&out) }

            let filter = FileFilter(query: query)
            for i in 0..<out.count {
                let m = out.items[i]
                let url = URL(fileURLWithPath: String(cString: m.file))
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil ?? 0
                let isBinary = FffEngine.looksBinary(url)
                guard filter.accepts(url, sizeBytes: size, isBinary: isBinary) else { continue }
                continuation.yield(RawMatch(
                    file: url,
                    lineNumber: Int(m.line),
                    matchLine: String(cString: m.text),
                    matchRange: Int(m.col_start)..<Int(m.col_end)))
            }
            continuation.finish()
        }
    }

    public enum EngineError: Error { case searchFailed(code: Int) }

    static func looksBinary(_ url: URL) -> Bool {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? fh.close() }
        let chunk = fh.readData(ofLength: 8000)
        return chunk.contains(0)
    }
}
