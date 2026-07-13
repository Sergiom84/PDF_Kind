import SwiftUI

/// Editor sencillo para crear o modificar una nota de una página.
struct AddNoteSheet: View {
    let pageIndex: Int
    var initialText: String = ""
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Página \(pageIndex + 1)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                TextEditor(text: $text)
                    .focused($focused)
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
            }
            .padding(.top)
            .navigationTitle("Nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { onSave(trimmed) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                text = initialText
                focused = true
            }
        }
    }
}
