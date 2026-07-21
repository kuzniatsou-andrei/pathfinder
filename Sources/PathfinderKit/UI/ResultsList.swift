import SwiftUI
import AppKit

public struct ResultsList: View {
    let store: ResultsStore
    var onReveal: (URL) -> Void
    var onOpen: (URL) -> Void
    var onDelete: (URL) -> Void

    public init(store: ResultsStore, onReveal: @escaping (URL) -> Void,
                onOpen: @escaping (URL) -> Void, onDelete: @escaping (URL) -> Void) {
        self.store = store; self.onReveal = onReveal; self.onOpen = onOpen; self.onDelete = onDelete
    }

    public var body: some View {
        List {
            ForEach(store.files, id: \.file) { file in
                Section(header: Text("\(file.file.lastPathComponent) (\(file.matches.count))").bold()) {
                    ForEach(Array(file.matches.enumerated()), id: \.offset) { _, m in
                        MatchRow(match: m)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selectedMatch = m }
                            .contextMenu {
                                Button("Показать в Finder") { onReveal(file.file) }
                                Button("Открыть в редакторе") { onOpen(file.file) }
                                Button("Копировать путь") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(file.file.path, forType: .string)
                                }
                                Divider()
                                Button("Удалить", role: .destructive) { onDelete(file.file) }
                            }
                    }
                }
            }
        }
    }
}

private struct MatchRow: View {
    let match: SearchMatch
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(match.contextBefore, id: \.number) { contextLine(number: $0.number, text: $0.text) }
            matchLine(number: match.lineNumber, text: match.matchLine, range: match.matchRange)
            ForEach(match.contextAfter, id: \.number) { contextLine(number: $0.number, text: $0.text) }
        }.font(.system(.body, design: .monospaced))
    }

    @ViewBuilder func contextLine(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)").foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
            Text(text).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder func matchLine(number: Int, text: String, range: Range<Int>) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)").foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
            Text(MatchRow.highlighted(text, byteRange: range))
                .fontWeight(.semibold)
        }
    }

    /// The matched substring gets a yellow background. `byteRange` is a UTF-8
    /// byte range (fff reports byte offsets); it's mapped to String indices and
    /// falls back to plain text if the range is empty or lands mid-scalar.
    static func highlighted(_ text: String, byteRange: Range<Int>) -> AttributedString {
        var attr = AttributedString(text)
        let u = text.utf8
        guard byteRange.lowerBound >= 0, byteRange.upperBound <= u.count,
              byteRange.lowerBound < byteRange.upperBound,
              let loU = u.index(u.startIndex, offsetBy: byteRange.lowerBound, limitedBy: u.endIndex),
              let hiU = u.index(u.startIndex, offsetBy: byteRange.upperBound, limitedBy: u.endIndex),
              let lo = loU.samePosition(in: text), let hi = hiU.samePosition(in: text),
              let aLo = AttributedString.Index(lo, within: attr),
              let aHi = AttributedString.Index(hi, within: attr) else { return attr }
        attr[aLo..<aHi].backgroundColor = .yellow
        attr[aLo..<aHi].foregroundColor = .black
        return attr
    }
}
