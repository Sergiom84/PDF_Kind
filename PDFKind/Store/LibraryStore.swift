import Foundation
import PDFKit
import UIKit

enum ImportError: LocalizedError {
    case cannotOpen
    case encrypted
    case copyFailed

    var errorDescription: String? {
        switch self {
        case .cannotOpen: return "No se ha podido abrir el PDF. El archivo puede estar dañado."
        case .encrypted: return "Este PDF está protegido con contraseña y no se puede importar."
        case .copyFailed: return "No se ha podido copiar el PDF a la biblioteca."
        }
    }
}

/// Fuente de verdad de la biblioteca. Persiste los metadatos en un JSON dentro
/// de Documents y guarda los PDFs y portadas como ficheros en subcarpetas.
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []

    private let fileManager = FileManager.default
    private var coverCache: [String: UIImage] = [:]

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var booksDirectory: URL {
        documentsURL.appendingPathComponent("Books", isDirectory: true)
    }
    private var coversDirectory: URL {
        documentsURL.appendingPathComponent("Covers", isDirectory: true)
    }
    private var libraryFileURL: URL {
        documentsURL.appendingPathComponent("library.json")
    }

    init() {
        createDirectoriesIfNeeded()
        load()
    }

    // MARK: - Rutas

    func pdfURL(for book: Book) -> URL {
        booksDirectory.appendingPathComponent(book.fileName)
    }

    private func coverURL(for fileName: String) -> URL {
        coversDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Persistencia

    private func createDirectoriesIfNeeded() {
        for directory in [booksDirectory, coversDirectory] {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: libraryFileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([Book].self, from: data) {
            books = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(books) {
            try? data.write(to: libraryFileURL, options: .atomic)
        }
    }

    // MARK: - Operaciones de biblioteca

    /// Copia el PDF al sandbox, genera la portada y añade el libro.
    /// `sourceURL` debe ser accesible (URL temporal o con acceso de seguridad ya iniciado).
    func importBook(from sourceURL: URL, title: String, author: String, coverData: Data?) throws {
        guard let document = PDFDocument(url: sourceURL) else {
            throw ImportError.cannotOpen
        }
        if document.isEncrypted && document.isLocked {
            throw ImportError.encrypted
        }

        let bookID = UUID()
        let pdfFileName = "\(bookID.uuidString).pdf"
        let destination = booksDirectory.appendingPathComponent(pdfFileName)
        do {
            try fileManager.copyItem(at: sourceURL, to: destination)
        } catch {
            throw ImportError.copyFailed
        }

        var coverFileName: String?
        let imageData = coverData ?? Self.renderFirstPageData(of: document)
        if let imageData {
            let name = "\(bookID.uuidString).jpg"
            do {
                try imageData.write(to: coverURL(for: name), options: .atomic)
                coverFileName = name
            } catch {
                coverFileName = nil
            }
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let book = Book(
            id: bookID,
            title: cleanTitle.isEmpty ? sourceURL.deletingPathExtension().lastPathComponent : cleanTitle,
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            fileName: pdfFileName,
            coverFileName: coverFileName,
            pageCount: document.pageCount
        )
        books.insert(book, at: 0)
        save()
    }

    /// Reemplaza el libro con el mismo id y persiste el cambio.
    func update(_ book: Book) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index] = book
        save()
    }

    /// Actualiza título, autor y (opcionalmente) la portada de un libro existente.
    func updateMetadata(of book: Book, title: String, author: String, newCoverData: Data?) {
        var updated = book
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTitle.isEmpty { updated.title = cleanTitle }
        updated.author = author.trimmingCharacters(in: .whitespacesAndNewlines)

        if let newCoverData {
            let name = book.coverFileName ?? "\(book.id.uuidString).jpg"
            try? newCoverData.write(to: coverURL(for: name), options: .atomic)
            updated.coverFileName = name
            coverCache[name] = nil
        }
        update(updated)
    }

    func delete(_ book: Book) {
        try? fileManager.removeItem(at: pdfURL(for: book))
        if let coverFileName = book.coverFileName {
            try? fileManager.removeItem(at: coverURL(for: coverFileName))
            coverCache[coverFileName] = nil
        }
        books.removeAll { $0.id == book.id }
        save()
    }

    // MARK: - Portadas

    func coverImage(for book: Book) -> UIImage? {
        guard let coverFileName = book.coverFileName else { return nil }
        if let cached = coverCache[coverFileName] { return cached }
        guard let image = UIImage(contentsOfFile: coverURL(for: coverFileName).path) else {
            return nil
        }
        coverCache[coverFileName] = image
        return image
    }

    /// Renderiza la primera página del PDF como portada por defecto.
    private static func renderFirstPageData(of document: PDFDocument) -> Data? {
        guard let page = document.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let targetWidth: CGFloat = 600
        let scale = targetWidth / bounds.width
        let size = CGSize(width: targetWidth, height: bounds.height * scale)
        let image = page.thumbnail(of: size, for: .mediaBox)
        return image.jpegData(compressionQuality: 0.8)
    }
}
