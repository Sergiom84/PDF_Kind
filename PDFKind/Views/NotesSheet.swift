import SwiftUI

/// Lista y edición de las notas del libro. Al tocar una nota se salta a su página.
struct NotesSheet: View {
    @Binding var book: Book
    let onJump: (Int) -> Void
    let onChange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var noteToEdit: Note?

    var body: some View {
        NavigationStack {
            Group {
                if book.notes.isEmpty {
                    ContentUnavailableView(
                        "Sin notas",
                        systemImage: "note.text",
                        description: Text("Crea notas desde el lector con la opción \"Nueva nota\".")
                    )
                } else {
                    List {
                        ForEach(book.notes) { note in
                            Button {
                                onJump(note.pageIndex)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Página \(note.pageIndex + 1)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.accent)
                                    Text(note.text)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(4)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(note)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                Button {
                                    noteToEdit = note
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .sheet(item: $noteToEdit) { note in
                AddNoteSheet(pageIndex: note.pageIndex, initialText: note.text) { text in
                    if let index = book.notes.firstIndex(where: { $0.id == note.id }) {
                        book.notes[index].text = text
                        book.notes[index].modifiedAt = Date()
                        onChange()
                    }
                }
            }
        }
    }

    private func delete(_ note: Note) {
        book.notes.removeAll { $0.id == note.id }
        onChange()
    }
}
