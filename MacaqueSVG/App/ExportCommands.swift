import SwiftUI
import UniformTypeIdentifiers

private struct ExportContextKey: FocusedValueKey {
    typealias Value = ExportContext
}

extension FocusedValues {
    var exportContext: ExportContext? {
        get { self[ExportContextKey.self] }
        set { self[ExportContextKey.self] = newValue }
    }
}

@MainActor
final class ExportContext: ObservableObject {
    let document: SVGFileDocument
    let parsedDocument: SVGDocument?
    let documentURL: URL?

    init(document: SVGFileDocument, parsedDocument: SVGDocument?, documentURL: URL?) {
        self.document = document
        self.parsedDocument = parsedDocument
        self.documentURL = documentURL
    }

    var suggestedBaseName: String {
        documentURL?.deletingPathExtension().lastPathComponent ?? "Export"
    }

    var hasParsed: Bool { parsedDocument != nil }
}

struct ExportCommands: Commands {
    @FocusedValue(\.exportContext) var exportContext

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Divider()
            Button("Export Flattened SVG…") {
                exportContext?.exportFlattenedSVG()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift, .option])
            .disabled(exportContext?.hasParsed != true)

            Button("Export Compressed SVG (.svgz)…") {
                exportContext?.exportSVGZ()
            }
            .disabled(exportContext?.hasParsed != true)

            Button("Export Flattened SVGZ…") {
                exportContext?.exportFlattenedSVGZ()
            }
            .disabled(exportContext?.hasParsed != true)

            Divider()

            Button("Export PNG 1x…") {
                exportContext?.exportPNG(scale: 1)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(exportContext?.hasParsed != true)

            Button("Export PNG 2x…") {
                exportContext?.exportPNG(scale: 2)
            }
            .disabled(exportContext?.hasParsed != true)

            Button("Export PDF 1x…") {
                exportContext?.exportPDF(scale: 1)
            }
            .disabled(exportContext?.hasParsed != true)
        }
    }
}

extension ExportContext {
    func exportPNG(scale: CGFloat) {
        guard let parsed = parsedDocument else { return }
        let box = parsed.root.userSpaceViewport()
        let pixel = CGSize(width: max(box.width, 1), height: max(box.height, 1))
        guard let data = SVGRasterPDFExporter.pngData(document: parsed, pixelSize: pixel, scale: scale) else { return }
        let suffix = scale == 1 ? "" : "@\(Int(scale))x"
        saveData(data, suggestedName: "\(suggestedBaseName)\(suffix).png", types: [.png])
    }

    func exportPDF(scale: CGFloat) {
        guard let parsed = parsedDocument else { return }
        let box = parsed.root.userSpaceViewport()
        let pixel = CGSize(width: max(box.width, 1), height: max(box.height, 1))
        guard let data = SVGRasterPDFExporter.pdfData(document: parsed, pixelSize: pixel, scale: scale) else { return }
        let suffix = scale == 1 ? "" : "@\(Int(scale))x"
        saveData(data, suggestedName: "\(suggestedBaseName)\(suffix).pdf", types: [.pdf])
    }

    func exportFlattenedSVG() {
        guard let parsed = parsedDocument else { return }
        let flattened = SVGFlattenedExporter.flattenSource(document.svgSource, parsed: parsed)
        guard let data = flattened.data(using: .utf8) else { return }
        saveData(data, suggestedName: "\(suggestedBaseName)-flat.svg", types: [.svgDocument])
    }

    func exportFlattenedSVGZ() {
        guard let parsed = parsedDocument else { return }
        let flattened = SVGFlattenedExporter.flattenSource(document.svgSource, parsed: parsed)
        guard let utf8 = flattened.data(using: .utf8),
              let gzipped = try? SVGZGzipCodec.compress(utf8) else { return }
        saveData(gzipped, suggestedName: "\(suggestedBaseName).flat.svgz", types: [.macaqueCompressedSVG])
    }

    func exportSVGZ() {
        guard let utf8 = document.svgSource.data(using: .utf8),
              let gzipped = try? SVGZGzipCodec.compress(utf8) else { return }
        saveData(gzipped, suggestedName: "\(suggestedBaseName).svgz", types: [.macaqueCompressedSVG])
    }

    private func saveData(_ data: Data, suggestedName: String, types: [UTType]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = types
        panel.nameFieldStringValue = suggestedName
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url, options: .atomic)
    }
}
