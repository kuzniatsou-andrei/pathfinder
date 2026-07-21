import SwiftUI

public struct SearchBar: View {
    @Bindable var model: SearchModel
    var canUndo: Bool
    var onFolderPick: () -> Void
    var onReplace: () -> Void
    var onUndo: () -> Void
    var onSearchToggle: () -> Void
    var onClear: () -> Void

    public init(model: SearchModel, canUndo: Bool,
                onFolderPick: @escaping () -> Void, onReplace: @escaping () -> Void,
                onUndo: @escaping () -> Void, onSearchToggle: @escaping () -> Void,
                onClear: @escaping () -> Void) {
        self._model = Bindable(model); self.canUndo = canUndo
        self.onFolderPick = onFolderPick; self.onReplace = onReplace; self.onUndo = onUndo
        self.onSearchToggle = onSearchToggle; self.onClear = onClear
    }

    // Enabled when there is a query to run; a missing folder is handled by
    // toggleSearch (it opens the folder picker first), so it must not gate the
    // button — otherwise the button looks dead with no explanation.
    private var runnable: Bool {
        !model.pattern.isEmpty && !(model.mode == .regex && model.regexError != nil)
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
                    .onSubmit {
                        if !model.isSearching && runnable { onSearchToggle() }
                    }
                if model.isSearching { ProgressView().scaleEffect(0.5) }
                Button { onSearchToggle() } label: {
                    if model.isSearching {
                        Label("Остановить", systemImage: "stop.fill")
                    } else {
                        Label("Начать поиск", systemImage: "magnifyingglass")
                    }
                }
                .disabled(!model.isSearching && !runnable)
                Button { onClear() } label: {
                    Label("Очистить", systemImage: "xmark.circle")
                }
                .disabled(model.pattern.isEmpty)
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
