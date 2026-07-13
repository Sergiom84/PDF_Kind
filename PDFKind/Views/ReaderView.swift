import SwiftUI
import PDFKit

/// Lector de un libro: muestra el PDF sin alterarlo y gestiona última página,
/// marcadores, notas, subrayados y búsqueda.
struct ReaderView: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var book: Book
    @State private var document: PDFDocument?
    @StateObject private var proxy = PDFViewProxy()

    @State private var showingBookmarks = false
    @State private var showingNotes = false
    @State private var showingSearch = false
    @State private var showingAddNote = false
    @State private var sliderPage: Double = 0
    @State private var isDraggingSlider = false
    @State private var toastMessage: String?

    init(book: Book) {
        _book = State(initialValue: book)
    }

    private var currentPageIsBookmarked: Bool {
        book.hasBookmark(page: book.lastPageIndex)
    }

    var body: some View {
        Group {
            if let document {
                PDFKitView(
                    document: document,
                    proxy: proxy,
                    initialPageIndex: book.lastPageIndex
                ) { newIndex in
                    book.lastPageIndex = newIndex
                    if !isDraggingSlider { sliderPage = Double(newIndex) }
                }
                .ignoresSafeArea(edges: .bottom)
            } else {
                ContentUnavailableView(
                    "No se puede abrir el libro",
                    systemImage: "exclamationmark.triangle",
                    description: Text("El archivo PDF no está disponible o está dañado.")
                )
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { readerToolbar }
        .safeAreaInset(edge: .bottom) {
            if document != nil { bottomBar }
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showingBookmarks) {
            BookmarksSheet(book: book, document: document) { pageIndex in
                proxy.goToPage(index: pageIndex)
            } onRemove: { pageIndex in
                book.toggleBookmark(page: pageIndex)
                persist()
            }
        }
        .sheet(isPresented: $showingNotes) {
            NotesSheet(book: $book, onJump: { pageIndex in
                proxy.goToPage(index: pageIndex)
            }, onChange: persist)
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteSheet(pageIndex: book.lastPageIndex) { text in
                book.notes.append(Note(pageIndex: book.lastPageIndex, text: text))
                book.notes.sort { $0.pageIndex < $1.pageIndex }
                persist()
                showToast("Nota guardada")
            }
        }
        .sheet(isPresented: $showingSearch) {
            SearchSheet(document: document) { selection in
                showingSearch = false
                proxy.goTo(selection: selection)
            }
        }
        .onAppear {
            if document == nil {
                document = PDFDocument(url: store.pdfURL(for: book))
                sliderPage = Double(book.lastPageIndex)
            }
        }
        .onDisappear {
            book.lastReadAt = Date()
            persist()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var readerToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                book.toggleBookmark(page: book.lastPageIndex)
                persist()
                showToast(currentPageIsBookmarked ? "Marcador añadido" : "Marcador quitado")
            } label: {
                Image(systemName: currentPageIsBookmarked ? "bookmark.fill" : "bookmark")
            }

            Menu {
                Button {
                    showingAddNote = true
                } label: {
                    Label("Nueva nota en esta página", systemImage: "square.and.pencil")
                }
                Button {
                    if proxy.highlightCurrentSelection(saveTo: store.pdfURL(for: book)) {
                        showToast("Texto subrayado")
                    } else {
                        showToast("Selecciona texto primero")
                    }
                } label: {
                    Label("Subrayar selección", systemImage: "highlighter")
                }
                Divider()
                Button {
                    showingNotes = true
                } label: {
                    Label("Ver notas (\(book.notes.count))", systemImage: "note.text")
                }
                Button {
                    showingBookmarks = true
                } label: {
                    Label("Ver marcadores (\(book.bookmarks.count))", systemImage: "bookmark")
                }
                Button {
                    showingSearch = true
                } label: {
                    Label("Buscar en el libro", systemImage: "magnifyingglass")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Barra inferior

    private var bottomBar: some View {
        VStack(spacing: 4) {
            Slider(
                value: $sliderPage,
                in: 0...Double(max(book.pageCount - 1, 1)),
                step: 1
            ) { editing in
                isDraggingSlider = editing
                if !editing {
                    proxy.goToPage(index: Int(sliderPage))
                }
            }
            Text("Página \(book.lastPageIndex + 1) de \(book.pageCount) · \(book.progressText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Utilidades

    private func persist() {
        store.update(book)
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation { toastMessage = nil }
        }
    }
}
