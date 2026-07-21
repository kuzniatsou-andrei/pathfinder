import SwiftUI

public struct SearchBar: View {
    @Bindable var model: SearchModel
    var onFolderPick: () -> Void
    var onReplace: () -> Void

    public init(model: SearchModel, onFolderPick: @escaping () -> Void, onReplace: @escaping () -> Void) {
        self._model = Bindable(model); self.onFolderPick = onFolderPick; self.onReplace = onReplace
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
            }
        }.padding(8)
    }
}
