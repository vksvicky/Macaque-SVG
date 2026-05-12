import AppKit
import SwiftUI

struct SVGPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    let document: SVGDocument
    var showsTransparencyGrid: Bool = true
    var useBrowserSVGRendering: Bool = true
    @Binding var selectedElement: SVGElement?

    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @GestureState private var liveDrag: CGSize = .zero
    @State private var baseZoomScale: CGFloat = 1.0

    private enum FocusField: Hashable { case canvas }
    @FocusState private var focusedField: FocusField?

    private var isEditMode: Bool { !useBrowserSVGRendering }

    private static let minZoom: CGFloat = 0.1
    private static let maxZoom: CGFloat = 20

    init(
        document: SVGDocument,
        showsTransparencyGrid: Bool = true,
        useBrowserSVGRendering: Bool = true,
        selectedElement: Binding<SVGElement?> = .constant(nil)
    ) {
        self.document = document
        self.showsTransparencyGrid = showsTransparencyGrid
        self.useBrowserSVGRendering = useBrowserSVGRendering
        _selectedElement = selectedElement
    }

    var body: some View {
        let viewBox = document.root.userSpaceViewport()
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                if showsTransparencyGrid {
                    transparencyGridBackground
                }

                if isEditMode {
                    svgContentView
                        .scaleEffect(zoomScale)
                        .offset(currentOffset)
                    selectionOverlayView(viewSize: size, viewBox: viewBox)
                } else {
                    svgContentView
                }
            }
            .contentShape(Rectangle())
            .ifEditMode(isEditMode) { view in
                view
                    .focusable()
                    .focused($focusedField, equals: .canvas)
                    .focusEffectDisabled()
                    .onKeyPress(.escape) {
                        selectedElement = nil
                        return .handled
                    }
                    .gesture(tapGesture(viewSize: size, viewBox: viewBox))
                    .gesture(panGesture)
                    .gesture(zoomGesture)
                    .onAppear { focusedField = .canvas }
                    .onChange(of: selectedElement != nil) { _, hasSelection in
                        if hasSelection { focusedField = .canvas }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .resetCanvasViewport)) { _ in
                        zoomScale = 1.0
                        baseZoomScale = 1.0
                        panOffset = .zero
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .canvasZoomIn)) { _ in
                        applyZoomStep(factor: 1.25)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .canvasZoomOut)) { _ in
                        applyZoomStep(factor: 0.8)
                    }
            }
        }
        .clipShape(Rectangle())
        .onChange(of: useBrowserSVGRendering) { _, isPreview in
            if isPreview {
                zoomScale = 1.0
                baseZoomScale = 1.0
                panOffset = .zero
                selectedElement = nil
            }
        }
        .overlay {
            Rectangle()
                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
        }
        .accessibilityLabel("SVG preview")
    }

    // MARK: - SVG Content

    @ViewBuilder
    private var svgContentView: some View {
        if let source = document.svgSource {
            SVGWebKitPreviewRepresentable(svgSource: source, assetBaseURL: document.assetBaseDirectory)
        } else {
            canvasFallbackView
        }
    }

    private var canvasFallbackView: some View {
        let viewBox = document.root.userSpaceViewport()
        return Canvas { context, canvasSize in
            let mapper = SVGViewBoxMapping.userSpaceToView(viewSize: canvasSize, viewBox: viewBox)
            var context = context
            context.concatenate(mapper)
            SVGSceneRenderer.draw(
                root: document.root,
                idIndex: document.idIndex,
                assetBaseDirectory: document.assetBaseDirectory,
                context: &context
            )
        }
    }

    // MARK: - Selection Overlay

    private func selectionOverlayView(viewSize: CGSize, viewBox: CGRect) -> some View {
        Canvas { context, canvasSize in
            guard let element = selectedElement else { return }
            var context = context
            context.translateBy(x: currentOffset.width, y: currentOffset.height)
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2
            context.translateBy(x: cx, y: cy)
            context.scaleBy(x: zoomScale, y: zoomScale)
            context.translateBy(x: -cx, y: -cy)
            let mapper = SVGViewBoxMapping.userSpaceToView(viewSize: canvasSize, viewBox: viewBox)
            context.concatenate(mapper)
            SVGSelectionOverlay.drawSelection(element: element, context: &context)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Gestures

    private var currentOffset: CGSize {
        CGSize(
            width: panOffset.width + liveDrag.width,
            height: panOffset.height + liveDrag.height
        )
    }

    private func tapGesture(viewSize: CGSize, viewBox: CGRect) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                handleTap(at: value.location, viewSize: viewSize, viewBox: viewBox)
                focusedField = .canvas
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .updating($liveDrag) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                panOffset.width += value.translation.width
                panOffset.height += value.translation.height
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoomScale = clampZoom(baseZoomScale * value.magnification)
            }
            .onEnded { value in
                baseZoomScale = clampZoom(baseZoomScale * value.magnification)
                zoomScale = baseZoomScale
                // Nudge offset to keep the gesture recognizer responsive (macOS SwiftUI workaround)
                panOffset.width += 0.01
                panOffset.width -= 0.01
            }
    }

    private func clampZoom(_ value: CGFloat) -> CGFloat {
        max(Self.minZoom, min(value, Self.maxZoom))
    }

    private func applyZoomStep(factor: CGFloat) {
        let newScale = clampZoom(zoomScale * factor)
        zoomScale = newScale
        baseZoomScale = newScale
    }

    private func handleTap(at location: CGPoint, viewSize: CGSize, viewBox: CGRect) {
        guard !useBrowserSVGRendering else { return }
        let cx = viewSize.width / 2
        let cy = viewSize.height / 2
        let adjustedPoint = CGPoint(
            x: (location.x - currentOffset.width - cx) / zoomScale + cx,
            y: (location.y - currentOffset.height - cy) / zoomScale + cy
        )
        let docPoint = SVGCoordinateMapper.viewToDocument(
            point: adjustedPoint, viewSize: viewSize, viewBox: viewBox
        )
        let hit = SVGHitTester.hitTest(
            point: docPoint, root: document.root, idIndex: document.idIndex
        )
        selectedElement = hit
    }

    // MARK: - Background

    private var transparencyGridBackground: some View {
        Canvas { context, size in
            let light = gridColor(light: true)
            let dark = gridColor(light: false)
            let cell: CGFloat = 8
            var row = 0
            var posY: CGFloat = 0
            while posY < size.height + cell {
                var posX: CGFloat = 0
                var column = 0
                while posX < size.width + cell {
                    let useLight = (row + column) % 2 == 0
                    let rect = CGRect(x: posX, y: posY, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(useLight ? light : dark))
                    posX += cell
                    column += 1
                }
                posY += cell
                row += 1
            }
        }
    }

    private func gridColor(light isLight: Bool) -> Color {
        switch colorScheme {
        case .dark:
            return Color(white: isLight ? 0.22 : 0.14)
        default:
            return Color(white: isLight ? 0.96 : 0.86)
        }
    }
}

private extension View {
    @ViewBuilder
    func ifEditMode<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview("SVGPreviewView") {
    let source = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <rect x="10" y="10" width="80" height="80" fill="#888" stroke="black" stroke-width="2" />
    </svg>
    """
    let parsed = try? SVGParser().parse(string: source)
    Group {
        if let parsed {
            SVGPreviewView(document: parsed)
                .frame(width: 240, height: 240)
                .padding()
        }
    }
}
