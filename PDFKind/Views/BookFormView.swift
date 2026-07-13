import SwiftUI
import PhotosUI
import PDFKit

/// Formulario compartido para importar un PDF nuevo o editar los detalles
/// (título, autor, portada) de un libro ya existente.
struct BookFormView: View {
    enum Mode {
        case importing(URL)
        case editing(Book)
    }

    let mode: Mode

    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var coverItem: PhotosPickerItem?
    @State private var coverData: Data?
    @State private var errorMessage: String?

    private var isImporting: Bool {
        if case .importing = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalles") {
                    TextField("Título", text: $title)
                    TextField("Autor", text: $author)
                }

                Section("Portada") {
                    HStack(spacing: 16) {
                        coverPreview
                            .frame(width: 80, height: 112)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $coverItem, matching: .images) {
                                Label("Elegir imagen", systemImage: "photo")
                            }
                            if coverData != nil {
                                Button("Quitar imagen elegida", role: .destructive) {
                                    coverData = nil
                                    coverItem = nil
                                }
                                .font(.footnote)
                            }
                            if isImporting {
                                Text("Si no eliges portada, se usará la primera página del PDF.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isImporting ? "Nuevo libro" : "Editar libro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { saveAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: populateInitialValues)
            .onChange(of: coverItem) {
                Task {
                    if let data = try? await coverItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        coverData = image.jpegData(compressionQuality: 0.8)
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("Aceptar") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let coverData, let image = UIImage(data: coverData) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if case .editing(let book) = mode, let cover = store.coverImage(for: book) {
            Image(uiImage: cover)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Rectangle().fill(Color.secondary.opacity(0.2))
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func populateInitialValues() {
        switch mode {
        case .editing(let book):
            title = book.title
            author = book.author
        case .importing(let url):
            // Sugerir metadatos del propio PDF si existen; si no, el nombre del archivo.
            title = url.deletingPathExtension().lastPathComponent
            if let document = PDFDocument(url: url),
               let attributes = document.documentAttributes {
                if let pdfTitle = attributes[PDFDocumentAttribute.titleAttribute] as? String,
                   !pdfTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                    title = pdfTitle
                }
                if let pdfAuthor = attributes[PDFDocumentAttribute.authorAttribute] as? String {
                    author = pdfAuthor
                }
            }
        }
    }

    private func saveAndDismiss() {
        switch mode {
        case .importing(let url):
            do {
                try store.importBook(from: url, title: title, author: author, coverData: coverData)
                try? FileManager.default.removeItem(at: url)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        case .editing(let book):
            store.updateMetadata(of: book, title: title, author: author, newCoverData: coverData)
            dismiss()
        }
    }
}
