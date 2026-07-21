import SwiftUI

public struct SearchBar: View {
    @Bindable var model: SearchModel
    var canUndo: Bool
    var onFolderPick: () -> Void
    var onReplace: () -> Void
    var onUndo: () -> Void

    public init(model: SearchModel, canUndo: Bool,
                onFolderPick: @escaping () -> Void, onReplace: @escaping () -> Void,
                onUndo: @escaping () -> Void) {
        self._model = Bindable(model); self.canUndo = canUndo
        self.onFolderPick = onFolderPick; self.onReplace = onReplace; self.onUndo = onUndo
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { onFolderPick() } label: {
                    Label(model.basePath?.lastPathComponent ?? "Выбрать папку", systemImage: "folder")
                }
                Spacer()
                Picker("", selection: $model.mode) {
                    Text("Text").tag(SearchMode.text)
                    Text("Regex").tag(SearchMode.regex)
                    Text("Fuzzy").tag(SearchMode.fuzzy)
                }.pickerStyle(.segmented).frame(width: 240)
            }
            HStack {
                TextField("Найти", text: $model.pattern)
                    .textFieldStyle(.roundedBorder)
                if model.isSearching { ProgressView().scaleEffect(0.5) }
            }
            if let re = model.regexError {
                HStack { Text(re).foregroundStyle(.red).font(.caption); Spacer() }
            }
            HStack {
                TextField("Заменить", text: $model.replacement)
                    .textFieldStyle(.roundedBorder)
                Button("Replace") { onReplace() }
                    .disabled(model.mode == .fuzzy)
                Button("Undo") { onUndo() }
                    .disabled(!canUndo)
            }
        }.padding(8)
    }
}
