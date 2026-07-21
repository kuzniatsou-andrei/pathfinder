import SwiftUI

public struct PreviewPane: View {
    let store: ResultsStore
    let model: SearchModel

    public init(store: ResultsStore, model: SearchModel) {
        self.store = store; self.model = model
    }

    public var body: some View {
        Group {
            if let m = store.selectedMatch,
               let text = try? String(contentsOf: m.file, encoding: .utf8) {
                ScrollView {
                    Text(PreviewPane.highlighted(text, pattern: model.pattern, mode: model.mode))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            } else {
                Text("Выбери результат для предпросмотра").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Whole-file text with every occurrence of the query highlighted yellow.
    /// Skips highlighting on very large files (perf) and on empty patterns.
    static func highlighted(_ text: String, pattern: String, mode: SearchMode) -> AttributedString {
        var attr = AttributedString(text)
        guard !pattern.isEmpty, text.utf16.count < 300_000 else { return attr }
        for r in matchRanges(in: text, pattern: pattern, mode: mode) {
            if let lo = AttributedString.Index(r.lowerBound, within: attr),
               let hi = AttributedString.Index(r.upperBound, within: attr) {
                attr[lo..<hi].backgroundColor = .yellow
                attr[lo..<hi].foregroundColor = .black
            }
        }
        return attr
    }

    static func matchRanges(in text: String, pattern: String, mode: SearchMode) -> [Range<String.Index>] {
        switch mode {
        case .regex:
            guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
            let ns = text as NSString
            return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
                .compactMap { Range($0.range, in: text) }
        case .text, .fuzzy:
            var result: [Range<String.Index>] = []
            var start = text.startIndex
            while let r = text.range(of: pattern, options: [.caseInsensitive], range: start..<text.endIndex) {
                result.append(r)
                start = r.upperBound
                if r.isEmpty { break }
            }
            return result
        }
    }
}
