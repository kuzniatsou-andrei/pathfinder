import SwiftUI
import AppKit

public struct ResultsList: View {
    let store: ResultsStore
    var relativeTo: URL?
    var onReveal: (URL) -> Void
    var onOpen: (URL) -> Void
    var onDelete: (URL) -> Void
    var onExcludeFile: (URL) -> Void
    var onExcludeFolder: (URL) -> Void

    public init(store: ResultsStore, relativeTo: URL? = nil, onReveal: @escaping (URL) -> Void,
                onOpen: @escaping (URL) -> Void, onDelete: @escaping (URL) -> Void,
                onExcludeFile: @escaping (URL) -> Void = { _ in },
                onExcludeFolder: @escaping (URL) -> Void = { _ in }) {
        self.store = store; self.relativeTo = relativeTo
        self.onReveal = onReveal; self.onOpen = onOpen; self.onDelete = onDelete
        self.onExcludeFile = onExcludeFile; self.onExcludeFolder = onExcludeFolder
    }

    private func copyToPasteboard(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    /// The match line plus its context, with line numbers, for "copy block".
    private func blockText(_ m: SearchMatch) -> String {
        var lines = m.contextBefore.map { "\($0.number)\t\($0.text)" }
        lines.append("\(m.lineNumber)\t\(m.matchLine)")
        lines += m.contextAfter.map { "\($0.number)\t\($0.text)" }
        return lines.joined(separator: "\n")
    }

    /// Path shown in a section header: relative to the searched folder so that
    /// same-named files in different directories are distinguishable.
    private func displayPath(_ file: URL) -> String {
        if let base = relativeTo, file.path.hasPrefix(base.path + "/") {
            return String(file.path.dropFirst(base.path.count + 1))
        }
        return file.lastPathComponent
    }

    public var body: some View {
        List {
            ForEach(store.files, id: \.file) { file in
                Section(header: Text("\(displayPath(file.file)) (\(file.matches.count))").bold()) {
                    ForEach(file.matches) { m in
                        MatchRow(match: m)
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(store.selectedMatch?.id == m.id
                                        ? Color.accentColor.opacity(0.20) : Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selectedMatch = m }
                            .contextMenu {
                                Button("Показать в Finder") { onReveal(file.file) }
                                Button("Открыть в редакторе") { onOpen(file.file) }
                                Divider()
                                Button("Копировать путь") { copyToPasteboard(displayPath(file.file)) }
                                Button("Копировать полный путь") { copyToPasteboard(file.file.path) }
                                Button("Копировать имя файла") { copyToPasteboard(file.file.lastPathComponent) }
                                Button("Копировать папку") { copyToPasteboard(file.file.deletingLastPathComponent().path) }
                                Button("Копировать строку") { copyToPasteboard(m.matchLine) }
                                Button("Копировать блок") { copyToPasteboard(blockText(m)) }
                                Divider()
                                Button("Исключить файл «\(file.file.lastPathComponent)»") { onExcludeFile(file.file) }
                                Button("Исключить папку «\(file.file.deletingLastPathComponent().lastPathComponent)»") { onExcludeFolder(file.file) }
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
