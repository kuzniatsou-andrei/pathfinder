import SwiftUI

public struct StatusBar: View {
    let store: ResultsStore
    let model: SearchModel
    public init(store: ResultsStore, model: SearchModel) { self.store = store; self.model = model }

    public var body: some View {
        HStack {
            if let err = model.lastError {
                Text(err).foregroundStyle(.red)
            } else {
                Text("\(store.fileCount) файлов · \(store.totalMatches) совпадений")
            }
            Spacer()
        }.font(.callout).padding(.horizontal, 8).padding(.vertical, 4)
    }
}
