import SwiftUI

public struct PreviewPane: View {
    let store: ResultsStore
    public init(store: ResultsStore) { self.store = store }

    public var body: some View {
        Group {
            if let m = store.selectedMatch,
               let text = try? String(contentsOf: m.file, encoding: .utf8) {
                ScrollView { Text(text).font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8) }
            } else {
                Text("Выбери результат для предпросмотра").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
