import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var store: LibraryStore

    @State private var showingFileImporter = false
    @State private var pendingImportURL: URL?
    @State private var bookToEdit: Book?
    @State private var bookToDelete: Book?
    @State private var errorMessage: String?
    @State private var searchText = ""

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 16)]

    private var filteredBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.books }
        return store.books.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.author.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.books.isEmpty {
                    emptyState
                } else {
                    bookGrid
                }
            }
            .navigationTitle("Biblioteca")
            .searchable(text: $searchText, prompt: "Buscar por título o autor")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Añadir libro", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.pdf]
            ) { result in
                handlePickedFile(result)
            }
            .sheet(item: $pendingImportURL) { url in
                BookFormView(mode: .importing(url))
            }
            .sheet(item: $bookToEdit) { book in
                BookFormView(mode: .editing(book))
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("Aceptar") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog(
                "¿Eliminar \"\(bookToDelete?.title ?? "")\"?",
                isPresented: .constant(bookToDelete != nil),
                titleVisibility: .visible
            ) {
                Button("Eliminar libro", role: .destructive) {
                    if let book = bookToDelete { store.delete(book) }
                    bookToDelete = nil
                }
                Button("Cancelar", role: .cancel) { bookToDelete = nil }
            } message: {
                Text("Se borrarán el PDF, los marcadores y las notas. Esta acción no se puede deshacer.")
            }
        }
    }

    // MARK: - Subvistas

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Tu biblioteca está vacía", systemImage: "books.vertical")
        } description: {
            Text("Añade tu primer libro en PDF con el botón +.")
        } actions: {
            Button("Añadir libro") { showingFileImporter = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var bookGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(filteredBooks) { book in
                    NavigationLink(value: book) {
                        BookCell(book: book)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            bookToEdit = book
                        } label: {
                            Label("Editar detalles", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            bookToDelete = book
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
        .navigationDestination(for: Book.self) { book in
            ReaderView(book: book)
        }
    }

    // MARK: - Importación

    /// Copia el PDF elegido a una URL temporal propia para no depender del
    /// alcance de seguridad mientras el usuario rellena el formulario.
    private func handlePickedFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure:
            errorMessage = "No se ha podido acceder al archivo seleccionado."
        case .success(let url):
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                pendingImportURL = tempURL
            } catch {
                errorMessage = "No se ha podido copiar el PDF seleccionado."
            }
        }
    }
}

// Permite usar URL directamente en .sheet(item:).
extension URL: Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Celda de libro

struct BookCell: View {
    @EnvironmentObject private var store: LibraryStore
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverView(book: book)
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

            Text(book.title)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            if !book.author.isEmpty {
                Text(book.author)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: book.progress)
                .tint(.accentColor)
            Text(book.progressText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct CoverView: View {
    @EnvironmentObject private var store: LibraryStore
    let book: Book

    var body: some View {
        if let cover = store.coverImage(for: book) {
            Image(uiImage: cover)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(
                    colors: [.accentColor.opacity(0.7), .accentColor.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                    Text(book.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                }
            }
        }
    }
}
