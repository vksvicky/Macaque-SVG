import AppKit
import SwiftUI

struct SVGPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme

    let document: SVGDocument
    /// When false (e.g. nested SVG rasterization), the preview is drawn on a clear background so transparency is preserved.
    var showsTransparencyGrid: Bool = true
    /// When true and `document.svgSource` is set, WebKit draws the file so `<textPath>` matches browser output.
    var useBrowserSVGRendering: Bool = true

    var body: some View {
        let viewBox = document.root.userSpaceViewport()
        ZStack {
            if showsTransparencyGrid {
                transparencyGridBackground
            }
            if useBrowserSVGRendering, let source = document.svgSource {
                SVGWebKitPreviewRepresentable(svgSource: source, assetBaseURL: document.assetBaseDirectory)
            } else {
                Canvas { context, size in
                    var context = context
                    let mapper = SVGViewBoxMapping.userSpaceToView(viewSize: size, viewBox: viewBox)
                    context.concatenate(mapper)
                    SVGSceneRenderer.draw(
                        root: document.root,
                        idIndex: document.idIndex,
                        assetBaseDirectory: document.assetBaseDirectory,
                        context: &context
                    )
                }
            }
        }
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
        }
        .accessibilityLabel("SVG preview")
    }

    private var transparencyGridBackground: some View {
        Canvas { context, size in
            let light = gridColor(light: true)
            let dark = gridColor(light: false)
            let cell: CGFloat = 8
            var row = 0
            var y: CGFloat = 0
            while y < size.height + cell {
                var x: CGFloat = 0
                var column = 0
                while x < size.width + cell {
                    let useLight = (row + column) % 2 == 0
                    let rect = CGRect(x: x, y: y, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(useLight ? light : dark))
                    x += cell
                    column += 1
                }
                y += cell
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
