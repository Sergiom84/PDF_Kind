import SwiftUI
import PDFKit

/// Búsqueda de texto en todo el documento. Muestra los resultados con un
/// fragmento de contexto y salta a la coincidencia elegida.
struct SearchSheet: View {
    let document: PDFDocument?
    let onSelect: (PDFSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PDFSelection] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView(
                        "Buscar en el libro",
                        systemImage: "magnifyingglass",
                        description: Text("Escribe una palabra o frase para encontrarla en el texto.")
                    )
                } else if isSearching {
                    ProgressView("Buscando…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results.indices, id: \.self) { index in
                        let selection = results[index]
                        Button {
                            onSelect(selection)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                if let page = selection.pages.first,
                                   let label = page.label {
                                    Text("Página \(label)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.accent)
                                }
                                Text(context(for: selection))
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Buscar")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .onSubmit(of: .search, runSearch)
            .onChange(of: query) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    results = []
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private func runSearch() {
        guard let document else { return }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        results = []
        // findString es síncrono pero rápido; lo lanzamos tras un ciclo para
        // que la UI muestre el indicador.
        DispatchQueue.main.async {
            let found = document.findString(trimmed, withOptions: [.caseInsensitive])
            results = Array(found.prefix(200))
            isSearching = false
        }
    }

    /// Extrae un fragmento con la coincidencia rodeada de contexto.
    private func context(for selection: PDFSelection) -> String {
        guard let page = selection.pages.first,
              let pageText = page.string,
              let match = selection.string, !match.isEmpty else {
            return selection.string ?? ""
        }
        if let range = pageText.range(of: match, options: .caseInsensitive) {
            let lower = pageText.index(range.lowerBound, offsetBy: -40, limitedBy: pageText.startIndex) ?? pageText.startIndex
            let upper = pageText.index(range.upperBound, offsetBy: 40, limitedBy: pageText.endIndex) ?? pageText.endIndex
            var snippet = String(pageText[lower..<upper]).replacingOccurrences(of: "\n", with: " ")
            snippet = snippet.trimmingCharacters(in: .whitespaces)
            return "…\(snippet)…"
        }
        return match
    }
}
