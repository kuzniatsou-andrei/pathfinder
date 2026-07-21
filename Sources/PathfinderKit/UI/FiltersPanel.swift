import SwiftUI

public struct FiltersPanel: View {
    @Bindable var model: SearchModel
    @State private var includeText = ""
    @State private var excludeText = ""

    public init(model: SearchModel) { self._model = Bindable(model) }

    public var body: some View {
        DisclosureGroup("Фильтры и контекст") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("include *.kt, *.json", text: $includeText)
                        .onChange(of: includeText) { _, v in model.includeGlobs = splitGlobs(v) }
                    TextField("exclude build, target, *.iml", text: $excludeText)
                        .onChange(of: excludeText) { _, v in model.excludeGlobs = splitGlobs(v) }
                }
                Toggle("Исключить бинарные", isOn: $model.excludeBinary)
                HStack {
                    Stepper("Контекст до: \(model.contextBefore)", value: $model.contextBefore, in: 0...20)
                    Stepper("после: \(model.contextAfter)", value: $model.contextAfter, in: 0...20)
                }
            }.textFieldStyle(.roundedBorder).padding(.top, 4)
        }.padding(.horizontal, 8)
    }

    private func splitGlobs(_ s: String) -> [String] {
        s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
