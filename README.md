# PDF KIND

Lector de PDF para iOS/iPadOS pensado **100 % para lectura de libros**. A diferencia de Kindle, **no re-maqueta ni cambia el aspecto del PDF**: muestra cada página exactamente como está maquetada. Ideal para libros en PDF cuya tipografía y diseño quieres conservar.

## Características

- 📚 **Biblioteca** con portadas en cuadrícula, progreso de lectura y buscador por título/autor.
- ➕ **Importar PDF** desde Archivos; el archivo se copia al almacenamiento propio de la app.
- 🖼️ **Portada y metadatos**: pon título y autor, y elige una portada de tu fototeca (o se usa la primera página del PDF).
- 📖 **Lector fiel al PDF**: paso de página horizontal, sin reformatear el contenido.
- 🔖 **Última página guardada**: cada libro reabre justo donde lo dejaste.
- 🏷️ **Marcadores** por página, con vista de lista para saltar entre ellos.
- 📝 **Anotaciones**: notas de texto ancladas a una página + subrayado de texto seleccionado (se guarda dentro del PDF).
- 🔍 **Búsqueda** de texto en todo el libro con fragmentos de contexto.

## Estructura

```
PDFKind/
├─ PDFKindApp.swift          Punto de entrada (SwiftUI App)
├─ Models/
│  └─ Book.swift             Modelo Book + Note (Codable)
├─ Store/
│  └─ LibraryStore.swift     Persistencia (JSON + ficheros PDF/portada)
└─ Views/
   ├─ LibraryView.swift      Cuadrícula de la biblioteca + importación
   ├─ BookFormView.swift     Alta/edición de metadatos y portada
   ├─ PDFKitView.swift       Envoltorio de PDFKit (UIViewRepresentable)
   ├─ ReaderView.swift       Lector: última página, marcadores, notas
   ├─ BookmarksSheet.swift   Lista de marcadores
   ├─ NotesSheet.swift       Lista/edición de notas
   ├─ AddNoteSheet.swift     Editor de nota
   └─ SearchSheet.swift      Búsqueda en el documento
```

## Cómo compilarlo (Mac + Xcode)

1. Clona el repositorio en el Mac.
2. Abre `PDFKind.xcodeproj` con Xcode 16 o superior.
3. En el target **PDFKind → Signing & Capabilities**, selecciona tu equipo de desarrollo (Apple ID). El *bundle identifier* por defecto es `com.sergio.pdfkind`; cámbialo si hace falta.
4. Elige un simulador (p. ej. iPhone 15) o tu dispositivo y pulsa **Run** (⌘R).

Requisitos: iOS 17.0+. No usa dependencias externas: todo es SwiftUI + PDFKit del sistema.

## Notas técnicas

- Los PDFs y portadas se guardan en `Documents/Books` y `Documents/Covers`; los metadatos en `Documents/library.json`.
- Los subrayados se escriben como anotaciones dentro del propio PDF, así que persisten en el archivo.
- El proyecto usa grupos sincronizados con el sistema de archivos (`PBXFileSystemSynchronizedRootGroup`), por lo que **cualquier `.swift` que añadas dentro de `PDFKind/` se incluye automáticamente** en el target al abrir en Xcode.

## Ideas para más adelante

- Temas de lectura (sepia / oscuro) y brillo por libro.
- Modo desplazamiento vertical continuo como alternativa al paso de página.
- Colecciones/estanterías y etiquetas.
- Exportar notas y subrayados a texto/Markdown.
- Sincronización con iCloud (última página y biblioteca entre dispositivos).
