import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DocumentEditorView: View {
    @Binding var document: SVGFileDocument
    /// `nil` for unsaved documents; used for relative `<image href>` and exports.
    var documentURL: URL?

    @State private var parsedDocument: SVGDocument?
    @State private var parseErrorMessage: String?
    @State private var exportErrorMessage: String?

    private var assetDirectory: URL? {
        documentURL?.deletingLastPathComponent()
    }

    private var suggestedExportBaseName: String {
        documentURL?.deletingPathExtension().lastPathComponent ?? "Export"
    }

    var body: some View {
        Group {
            if let message = parseErrorMessage {
                VStack(alignment: .leading, spacing: 12) {
                    Text(message)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if let parsed = parsedDocument {
                HSplitView {
                    SVGPreviewView(document: parsed)
                        .frame(minWidth: 360, minHeight: 400)

                    ScrollView {
                        parsedSummary(parsed)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            } else {
                Text("No SVG loaded.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu("Export", systemImage: "square.and.arrow.up") {
                    Button("Flattened SVG…") { exportFlattenedSVG() }
                    Button("Compressed SVG (.svgz)…") { exportSVGZ(source: document.svgSource, suggestedSuffix: "svgz") }
                    Button("Flattened SVGZ (.svgz)…") { exportFlattenedSVGZ() }
                    Divider()
                    Menu("PDF (raster)") {
                        Button("1× …") { exportPDF(scale: 1) }
                        Button("2× …") { exportPDF(scale: 2) }
                        Button("4× …") { exportPDF(scale: 4) }
                    }
                    Menu("PNG") {
                        Button("1× …") { exportPNG(scale: 1) }
                        Button("2× …") { exportPNG(scale: 2) }
                        Button("4× …") { exportPNG(scale: 4) }
                    }
                }
                .disabled(parsedDocument == nil)
            }
        }
        .onAppear(perform: reparse)
        .onChange(of: document.svgSource) { _, _ in
            reparse()
        }
        .onChange(of: documentURL?.path ?? "") { _, _ in
            reparse()
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    @MainActor
    private func exportPNG(scale: CGFloat) {
        guard let parsed = parsedDocument else { return }
        let box = parsed.root.userSpaceViewport()
        let pixel = CGSize(width: max(box.width, 1), height: max(box.height, 1))
        guard let data = SVGRasterPDFExporter.pngData(document: parsed, pixelSize: pixel, scale: scale) else {
            exportErrorMessage = "Could not render PNG."
            return
        }
        let suffix = scale == 1 ? "" : "@\(Int(scale))x"
        saveData(data, suggestedName: "\(suggestedExportBaseName)\(suffix).png", types: [.png])
    }

    @MainActor
    private func exportPDF(scale: CGFloat) {
        guard let parsed = parsedDocument else { return }
        let box = parsed.root.userSpaceViewport()
        let pixel = CGSize(width: max(box.width, 1), height: max(box.height, 1))
        guard let data = SVGRasterPDFExporter.pdfData(document: parsed, pixelSize: pixel, scale: scale) else {
            exportErrorMessage = "Could not render PDF."
            return
        }
        let suffix = scale == 1 ? "" : "@\(Int(scale))x"
        saveData(data, suggestedName: "\(suggestedExportBaseName)\(suffix).pdf", types: [.pdf])
    }

    @MainActor
    private func exportFlattenedSVG() {
        guard let parsed = parsedDocument else { return }
        let flattened = SVGFlattenedExporter.flattenSource(document.svgSource, parsed: parsed)
        guard let data = flattened.data(using: .utf8) else {
            exportErrorMessage = "Could not encode UTF-8."
            return
        }
        saveData(data, suggestedName: "\(suggestedExportBaseName)-flat.svg", types: [.svgDocument])
    }

    @MainActor
    private func exportFlattenedSVGZ() {
        guard let parsed = parsedDocument else { return }
        let flattened = SVGFlattenedExporter.flattenSource(document.svgSource, parsed: parsed)
        exportSVGZ(source: flattened, suggestedSuffix: "flat.svgz")
    }

    @MainActor
    private func exportSVGZ(source: String, suggestedSuffix: String) {
        guard let utf8 = source.data(using: .utf8) else {
            exportErrorMessage = "Could not encode UTF-8."
            return
        }
        do {
            let gzipped = try SVGZGzipCodec.compress(utf8)
            saveData(gzipped, suggestedName: "\(suggestedExportBaseName).\(suggestedSuffix)", types: [.macaqueCompressedSVG])
        } catch let err as SVGZGzipCodec.CodecError {
            exportErrorMessage = err.presentation
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveData(_ data: Data, suggestedName: String, types: [UTType]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = types
        panel.nameFieldStringValue = suggestedName
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func parsedSummary(_ parsed: SVGDocument) -> some View {
        let root = parsed.root
        VStack(alignment: .leading, spacing: 8) {
            Label("SVG parsed successfully", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Group {
                summaryRow("Direct children", value: "\(root.children.count)")
                if let viewBox = root.viewBox {
                    summaryRow("viewBox", value: formatViewBox(viewBox))
                } else {
                    summaryRow("viewBox", value: "—")
                }
                summaryRow("Root width / height", value: formatOptionalSize(width: root.width, height: root.height))
                if assetDirectory != nil {
                    summaryRow("Asset folder", value: assetDirectory!.path)
                }
            }
            .font(.body)
        }
    }

    private func formatViewBox(_ rect: CGRect) -> String {
        "\(formatNumber(rect.minX)), \(formatNumber(rect.minY)), \(formatNumber(rect.width)), \(formatNumber(rect.height))"
    }

    private func summaryRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
    }

    private func formatOptionalSize(width: CGFloat?, height: CGFloat?) -> String {
        switch (width, height) {
        case let (width?, height?):
            return "\(formatNumber(width)) × \(formatNumber(height))"
        case let (width?, nil):
            return "\(formatNumber(width)) × —"
        case let (nil, height?):
            return "— × \(formatNumber(height))"
        default:
            return "—"
        }
    }

    private func formatNumber(_ value: CGFloat) -> String {
        String(format: "%g", Double(value))
    }

    @MainActor
    private func reparse() {
        do {
            let parsed = try SVGParser().parse(string: document.svgSource, assetBaseDirectory: assetDirectory)
            SVGImageAssetResolver.warmRasterCaches(in: parsed)
            parsedDocument = parsed
            parseErrorMessage = nil
        } catch {
            parsedDocument = nil
            parseErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    DocumentEditorView(document: .constant(SVGFileDocument()), documentURL: nil)
}
