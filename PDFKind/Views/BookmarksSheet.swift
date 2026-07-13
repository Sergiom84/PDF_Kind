import SwiftUI
import PDFKit

/// Lista de marcadores del libro. Al tocar uno se salta a esa página.
struct BookmarksSheet: View {
    let book: Book
    let document: PDFDocument?
    let onJump: (Int) -> Void
    let onRemove: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if book.bookmarks.isEmpty {
                    ContentUnavailableView(
                        "Sin marcadores",
                        systemImage: "bookmark",
                        description: Text("Añade marcadores desde el lector con el icono de marcador.")
                    )
                } else {
                    List {
                        ForEach(book.bookmarks, id: \.self) { pageIndex in
                            Button {
                                onJump(pageIndex)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Página \(pageIndex + 1)")
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        if let label = pageLabel(pageIndex) {
                                            Text(label)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                onRemove(book.bookmarks[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Marcadores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    /// Primeras palabras de la página, como referencia rápida del contenido.
    private func pageLabel(_ index: Int) -> String? {
        guard let page = document?.page(at: index),
              let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return String(text.prefix(60))
    }
}
