import SwiftUI

public struct PreviewPane: View {
    let store: ResultsStore
    let model: SearchModel
    @State private var content: AttributedString?
    @State private var loadedFor: String?

    public init(store: ResultsStore, model: SearchModel) {
        self.store = store; self.model = model
    }

    public var body: some View {
        Group {
            if let m = store.selectedMatch {
                VStack(alignment: .leading, spacing: 0) {
                    // File path header — updates instantly on selection; selectable.
                    Text(m.file.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                    Divider()
                    // Content area: cleared immediately on selection change, then
                    // filled once the async load finishes.
                    if let content, loadedFor == m.id {
                        ScrollView {
                            Text(content)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                // .task(id:) re-runs (and cancels the prior run) whenever the
                // selected match changes — reading the file and computing the
                // highlight OFF the main thread so the UI never blocks.
                .task(id: m.id) {
                    content = nil
                    loadedFor = nil
                    let url = m.file
                    let pattern = model.pattern
                    let mode = model.mode
                    let loaded = await Task.detached(priority: .userInitiated) { () -> AttributedString in
                        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                            return AttributedString("(не удалось прочитать файл)")
                        }
                        return PreviewPane.highlighted(text, pattern: pattern, mode: mode)
                    }.value
                    if !Task.isCancelled {
                        content = loaded
                        loadedFor = m.id
                    }
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
