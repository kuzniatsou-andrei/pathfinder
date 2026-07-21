import SwiftUI

public struct FiltersPanel: View {
    @Bindable var model: SearchModel
    @State private var includeText = ""
    @State private var excludeText = ""
    @State private var expanded = false

    public init(model: SearchModel) { self._model = Bindable(model) }

    public var body: some View {
        VStack(spacing: 0) {
            // Full-width header panel; clicking anywhere on it toggles expansion.
            HStack(spacing: 6) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Фильтры и контекст").bold()
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.12))
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("include *.kt | src/**/*.java", text: $includeText)
                            .onChange(of: includeText) { _, v in model.includeGlobs = splitGlobs(v) }
                            .onChange(of: model.includeGlobs) { _, g in
                                if splitGlobs(includeText) != g { includeText = g.joined(separator: " | ") }
                            }
                        TextField("exclude build/ | **/target | feature-* | !keep/", text: $excludeText)
                            .onChange(of: excludeText) { _, v in model.excludeGlobs = splitGlobs(v) }
                            .onChange(of: model.excludeGlobs) { _, g in
                                if splitGlobs(excludeText) != g { excludeText = g.joined(separator: " | ") }
                            }
                    }
                    Toggle("Исключить бинарные", isOn: $model.excludeBinary)
                    HStack {
                        Stepper("Контекст до: \(model.contextBefore)", value: $model.contextBefore, in: 0...20)
                        Stepper("после: \(model.contextAfter)", value: $model.contextAfter, in: 0...20)
                    }
                }.textFieldStyle(.roundedBorder).padding(10)
            }
        }
        .onAppear {
            includeText = model.includeGlobs.joined(separator: " | ")
            excludeText = model.excludeGlobs.joined(separator: " | ")
        }
    }

    // Patterns are gitignore-style and separated by `|` or newlines
    // (e.g. "build/ | **/target" or one pattern per line).
    private func splitGlobs(_ s: String) -> [String] {
        s.split(whereSeparator: { $0 == "|" || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
