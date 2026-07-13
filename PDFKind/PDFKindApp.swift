import SwiftUI

@main
struct PDFKindApp: App {
    @StateObject private var store = LibraryStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(store)
        }
    }
}
