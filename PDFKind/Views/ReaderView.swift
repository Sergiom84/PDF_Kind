import SwiftUI
import PDFKit

/// Lector de un libro: muestra el PDF sin alterarlo y gestiona última página,
/// marcadores, notas, subrayados y búsqueda.
struct ReaderView: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var showControls = true

    /// Preferencias de lectura (persisten entre libros y sesiones).
    @AppStorage("showReaderProgress") private var showProgressBar = true
    @AppStorage("readingZoom") private var readingZoom: Double = 1.0

    /// Niveles de zoom disponibles desde la lupa. 1.0 = Ajustar a pantalla.
    private let zoomLevels: [Double] = [1.0, 1.25, 1.5, 2.0, 2.5, 3.0]

    private func zoomLabel(_ z: Double) -> String {
        z <= 1.001 ? "Ajustar" : "\(Int(z * 100))%"
    }

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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            if document != nil { backButton }
        }
        .overlay(alignment: .topTrailing) {
            if document != nil { floatingControls }
        }
        .safeAreaInset(edge: .bottom) {
            if document != nil && showProgressBar { bottomBar }
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
                // Restaura el zoom de lectura tras montar la vista.
                DispatchQueue.main.async { proxy.setZoom(readingZoom) }
            }
        }
        .onDisappear {
            book.lastReadAt = Date()
            persist()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Guarda la última página también al segundo plano/cierre: onDisappear
            // no salta si el usuario mata la app en vez de volver atrás.
            if newPhase != .active, document != nil {
                book.lastReadAt = Date()
                persist()
            }
        }
    }

    // MARK: - Controles flotantes

    /// Flecha de volver, flotante en el margen izquierdo.
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .floatingControlStyle()
        }
        .padding(.leading, 8)
        .padding(.top, 4)
    }

    /// Columna vertical de controles pegada al borde derecho. El botón superior
    /// pliega/despliega el resto para leer a pantalla casi completa.
    private var floatingControls: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
            } label: {
                Image(systemName: showControls ? "chevron.up" : "slider.horizontal.3")
                    .floatingControlStyle()
            }

            if showControls {
                zoomMenu
                pageTurnButtons
                bookmarkButton
                optionsMenu
            }
        }
        .padding(.trailing, 8)
        .padding(.top, 4)
    }

    private var zoomMenu: some View {
        Menu {
            Picker("Zoom", selection: Binding(
                get: { readingZoom },
                set: { newValue in
                    readingZoom = newValue
                    proxy.setZoom(newValue)
                    showToast("Zoom \(zoomLabel(newValue))")
                }
            )) {
                ForEach(zoomLevels, id: \.self) { level in
                    Text(zoomLabel(level)).tag(level)
                }
            }
        } label: {
            Image(systemName: "plus.magnifyingglass")
                .floatingControlStyle()
        }
    }

    /// Avanza/retrocede página conservando el zoom actual, sin necesidad de
    /// reducir manualmente para poder deslizar.
    private var pageTurnButtons: some View {
        VStack(spacing: 12) {
            Button {
                proxy.goToPreviousPage()
            } label: {
                Image(systemName: "chevron.left")
                    .floatingControlStyle()
            }

            Button {
                proxy.goToNextPage()
            } label: {
                Image(systemName: "chevron.right")
                    .floatingControlStyle()
            }
        }
    }

    private var bookmarkButton: some View {
        Button {
            book.toggleBookmark(page: book.lastPageIndex)
            persist()
            showToast(currentPageIsBookmarked ? "Marcador añadido" : "Marcador quitado")
        } label: {
            Image(systemName: currentPageIsBookmarked ? "bookmark.fill" : "bookmark")
                .floatingControlStyle()
        }
    }

    private var optionsMenu: some View {
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
            Divider()
            Toggle(isOn: $showProgressBar) {
                Label("Barra de progreso", systemImage: "chart.bar")
            }
        } label: {
            Image(systemName: "ellipsis")
                .floatingControlStyle()
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

// MARK: - Estilo de botón flotante

private extension View {
    /// Icono compacto sobre fondo circular translúcido, legible encima del PDF.
    func floatingControlStyle() -> some View {
        self
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 40, height: 40)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.quaternary, lineWidth: 0.5))
            .contentShape(Circle())
    }
}
