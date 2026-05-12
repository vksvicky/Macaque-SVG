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
    @State private var selectedElement: SVGElement?
    @State private var useCanvasMode: Bool = false

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
                    SVGPreviewView(
                        document: parsed,
                        useBrowserSVGRendering: !useCanvasMode,
                        selectedElement: $selectedElement
                    )
                    .frame(minWidth: 360, minHeight: 400)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            parsedSummary(parsed)
                            if useCanvasMode {
                                Divider()
                                Label("Edit Mode", systemImage: "pencil.and.outline")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                                Text("Click elements to select. Drag to pan. Pinch to zoom.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let element = selectedElement {
                                Divider()
                                selectedElementInspector(element)
                            }
                        }
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
                Button {
                    useCanvasMode.toggle()
                } label: {
                    Label(
                        useCanvasMode ? "Edit Mode" : "Preview Mode",
                        systemImage: useCanvasMode ? "pencil.and.outline" : "eye"
                    )
                }
                .help(useCanvasMode ? "Switch to Preview (Cmd+E)" : "Switch to Edit (Cmd+E)")

                Menu("Export", systemImage: "square.and.arrow.up") {
                    Button("Flattened SVG…") { exportFlattenedSVG() }
                    Button("Compressed SVG (.svgz)…") {
                        exportSVGZ(source: document.svgSource, suggestedSuffix: "svgz")
                    }
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
        .focusedValue(\.exportContext, ExportContext(
            document: document,
            parsedDocument: parsedDocument,
            documentURL: documentURL
        ))
        .focusedValue(\.canvasActions, CanvasActions(
            useCanvasMode: $useCanvasMode,
            selectedElement: $selectedElement
        ))
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

    @ViewBuilder
    private func selectedElementInspector(_ element: SVGElement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Selected Element", systemImage: "cursorarrow.click.2")
                .font(.headline)

            summaryRow("Type", value: elementTypeName(element))
            if let svgId = element.svgId {
                summaryRow("ID", value: svgId)
            }
            if let svgClass = element.svgClass {
                summaryRow("Class", value: svgClass)
            }

            if let rect = element as? SVGRect {
                Group {
                    summaryRow("x", value: formatNumber(rect.x))
                    summaryRow("y", value: formatNumber(rect.y))
                    summaryRow("width", value: formatNumber(rect.width))
                    summaryRow("height", value: formatNumber(rect.height))
                    if let rx = rect.rx { summaryRow("rx", value: formatNumber(rx)) }
                    if let ry = rect.ry { summaryRow("ry", value: formatNumber(ry)) }
                }
            } else if let circle = element as? SVGCircle {
                summaryRow("cx", value: formatNumber(circle.cx))
                summaryRow("cy", value: formatNumber(circle.cy))
                summaryRow("r", value: formatNumber(circle.r))
            } else if let path = element as? SVGPath {
                let truncated = path.d.count > 60 ? String(path.d.prefix(60)) + "…" : path.d
                summaryRow("d", value: truncated)
            } else if let poly = element as? SVGPolyline {
                summaryRow("points", value: "\(poly.points.count)")
            }

            Divider()
            Text("Style").font(.subheadline).foregroundStyle(.secondary)
            if let fill = element.style.fill {
                summaryRow("fill", value: fill)
            }
            if let stroke = element.style.stroke {
                summaryRow("stroke", value: stroke)
            }
            if let strokeWidth = element.style.strokeWidth {
                summaryRow("stroke-width", value: formatNumber(strokeWidth))
            }
            if let opacity = element.style.opacity {
                summaryRow("opacity", value: formatNumber(opacity))
            }

            if element.transform != .identity {
                Divider()
                Text("Transform").font(.subheadline).foregroundStyle(.secondary)
                let transform = element.transform
                summaryRow("translate", value: "\(formatNumber(transform.tx)), \(formatNumber(transform.ty))")
                summaryRow("scale", value: "\(formatNumber(transform.a)), \(formatNumber(transform.d))")
            }
        }
    }

    private func elementTypeName(_ element: SVGElement) -> String {
        switch element {
        case is SVGRect: return "rect"
        case is SVGCircle: return "circle"
        case is SVGPath: return "path"
        case is SVGPolygon: return "polygon"
        case is SVGPolyline: return "polyline"
        case is SVGImage: return "image"
        case is SVGTextBlock: return "text"
        case is SVGTextPath: return "textPath"
        case is SVGUse: return "use"
        case is SVGGroup: return "g"
        default: return "element"
        }
    }

    @MainActor
    private func reparse() {
        selectedElement = nil
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
