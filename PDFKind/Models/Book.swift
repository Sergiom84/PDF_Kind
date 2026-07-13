import Foundation

/// Nota de lectura asociada a una página concreta del libro.
struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var pageIndex: Int
    var text: String
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
}

/// Un libro de la biblioteca. El PDF y la portada viven en el sandbox de la app;
/// aquí solo se guardan los nombres de fichero y los metadatos de lectura.
struct Book: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var author: String
    var fileName: String
    var coverFileName: String?
    var pageCount: Int
    var lastPageIndex: Int = 0
    var bookmarks: [Int] = []
    var notes: [Note] = []
    var addedAt: Date = Date()
    var lastReadAt: Date?

    /// Progreso de lectura entre 0 y 1.
    var progress: Double {
        guard pageCount > 0 else { return 0 }
        return Double(lastPageIndex + 1) / Double(pageCount)
    }

    var progressText: String {
        "\(Int((progress * 100).rounded())) %"
    }

    func hasBookmark(page: Int) -> Bool {
        bookmarks.contains(page)
    }

    mutating func toggleBookmark(page: Int) {
        if let index = bookmarks.firstIndex(of: page) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.append(page)
            bookmarks.sort()
        }
    }
}
