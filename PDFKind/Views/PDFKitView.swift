import SwiftUI
import PDFKit

/// Referencia al PDFView subyacente para que la vista SwiftUI pueda
/// pedirle acciones (ir a página, subrayar la selección actual...).
final class PDFViewProxy: ObservableObject {
    weak var pdfView: PDFView?

    /// Nivel de zoom de lectura como multiplicador del ajuste a pantalla.
    /// 1.0 = "Ajustar" (autoScales). >1 mantiene ese aumento al pasar de página.
    @Published var zoomMultiplier: CGFloat = 1.0

    func setZoom(_ multiplier: CGFloat) {
        zoomMultiplier = multiplier
        applyZoom()
    }

    /// Aplica el zoom actual al PDFView. Se vuelve a llamar en cada cambio de
    /// página para que el aumento se conserve sin tener que rehacerlo a mano.
    func applyZoom() {
        guard let pdfView else { return }
        if zoomMultiplier <= 1.001 {
            pdfView.autoScales = true
        } else {
            pdfView.autoScales = false
            let fit = pdfView.scaleFactorForSizeToFit
            guard fit > 0 else { return }
            pdfView.minScaleFactor = fit * 0.5
            pdfView.maxScaleFactor = fit * 8
            pdfView.scaleFactor = fit * zoomMultiplier
        }
    }

    func goToPage(index: Int) {
        guard let pdfView, let document = pdfView.document,
              index >= 0, index < document.pageCount,
              let page = document.page(at: index) else { return }
        pdfView.go(to: page)
    }

    /// Avanza de página sin depender del gesto de swipe: funciona con
    /// cualquier zoom activo (el swipe manual sí queda bloqueado al hacer zoom).
    var canGoToNextPage: Bool { pdfView?.canGoToNextPage ?? false }
    var canGoToPreviousPage: Bool { pdfView?.canGoToPreviousPage ?? false }

    func goToNextPage() {
        pdfView?.goToNextPage(nil)
    }

    func goToPreviousPage() {
        pdfView?.goToPreviousPage(nil)
    }

    func goTo(selection: PDFSelection) {
        guard let pdfView else { return }
        if let page = selection.pages.first {
            pdfView.go(to: page)
        }
        pdfView.setCurrentSelection(selection, animate: true)
    }

    /// Subraya la selección actual del usuario y la guarda dentro del PDF.
    /// Devuelve false si no había texto seleccionado.
    func highlightCurrentSelection(saveTo url: URL) -> Bool {
        guard let pdfView, let document = pdfView.document,
              let selection = pdfView.currentSelection,
              !(selection.string ?? "").isEmpty else { return false }

        for lineSelection in selection.selectionsByLine() {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard !bounds.isEmpty else { continue }
                let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                highlight.color = UIColor.systemYellow.withAlphaComponent(0.5)
                page.addAnnotation(highlight)
            }
        }
        pdfView.clearSelection()
        document.write(to: url)
        return true
    }
}

/// Envoltorio de PDFKit. Muestra el PDF tal cual es, sin reformatear nada,
/// con paso de página horizontal estilo libro.
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let proxy: PDFViewProxy
    let initialPageIndex: Int
    let onPageChange: (Int) -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true, withViewOptions: nil)
        pdfView.autoScales = true
        pdfView.backgroundColor = .systemBackground

        proxy.pdfView = pdfView

        if initialPageIndex > 0, initialPageIndex < document.pageCount,
           let page = document.page(at: initialPageIndex) {
            // Diferido para que el layout inicial no lo pise.
            DispatchQueue.main.async {
                pdfView.go(to: page)
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // El documento no cambia durante la vida de la vista.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPageChange: onPageChange, proxy: proxy)
    }

    final class Coordinator: NSObject {
        let onPageChange: (Int) -> Void
        weak var proxy: PDFViewProxy?

        init(onPageChange: @escaping (Int) -> Void, proxy: PDFViewProxy) {
            self.onPageChange = onPageChange
            self.proxy = proxy
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let document = pdfView.document,
                  let currentPage = pdfView.currentPage else { return }
            onPageChange(document.index(for: currentPage))
            // Conserva el zoom de lectura en la nueva página.
            DispatchQueue.main.async { [weak proxy] in
                proxy?.applyZoom()
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
