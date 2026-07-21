import SwiftUI

public struct ResultsList: View {
    let store: ResultsStore
    var onReveal: (URL) -> Void
    var onOpen: (URL) -> Void

    public init(store: ResultsStore, onReveal: @escaping (URL) -> Void, onOpen: @escaping (URL) -> Void) {
        self.store = store; self.onReveal = onReveal; self.onOpen = onOpen
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
            ForEach(match.contextBefore, id: \.number) { line(number: $0.number, text: $0.text, isMatch: false) }
            line(number: match.lineNumber, text: match.matchLine, isMatch: true)
            ForEach(match.contextAfter, id: \.number) { line(number: $0.number, text: $0.text, isMatch: false) }
        }.font(.system(.body, design: .monospaced))
    }
    @ViewBuilder func line(number: Int, text: String, isMatch: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)").foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
            Text(text).foregroundStyle(isMatch ? .primary : .secondary)
                .fontWeight(isMatch ? .semibold : .regular)
        }
    }
}
