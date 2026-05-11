import CoreGraphics
import Foundation

struct SVGDocument {
    let root: SVGRoot
    let stylesheet: SVGStylesheet
    let idIndex: [String: SVGElement]
    /// Folder containing the saved `.svg` file; used to resolve `<image href="../…">` and exports.
    let assetBaseDirectory: URL?
    /// Original markup when parsed from text; used for WebKit preview so `textPath` matches browser layout.
    let svgSource: String?

    init(root: SVGRoot, stylesheet: SVGStylesheet = .empty, assetBaseDirectory: URL? = nil, svgSource: String? = nil) {
        self.root = root
        self.stylesheet = stylesheet
        self.assetBaseDirectory = assetBaseDirectory
        self.svgSource = svgSource
        idIndex = Self.buildIdIndex(root: root)
    }

    private static func buildIdIndex(root: SVGRoot) -> [String: SVGElement] {
        var map: [String: SVGElement] = [:]
        func walk(_ element: SVGElement) {
            if let id = element.svgId, !id.isEmpty {
                map[id] = element
            }
            if let group = element as? SVGGroup {
                for child in group.children {
                    walk(child)
                }
            }
        }
        for child in root.children {
            walk(child)
        }
        return map
    }
}

final class SVGRoot: SVGGroup {
    var viewBox: CGRect?
    var width: CGFloat?
    var height: CGFloat?
}

/// Nested `<svg>` inside the document (valid SVG). Parsed like a group with optional inner `viewBox` / size.
final class SVGNestedSVG: SVGGroup {
    var viewBox: CGRect?
    var width: CGFloat?
    var height: CGFloat?
}

class SVGGroup: SVGElement {
    private(set) var children: [SVGElement] = []
    /// Fragment id when `mask="url(#id)"` is set on this group.
    var maskHrefFragment: String?

    func addChild(_ child: SVGElement) {
        child.parent = self
        children.append(child)
    }
}

final class SVGPath: SVGElement {
    var d: String
    init(d: String = "", svgId: String? = nil, transform: CGAffineTransform = .identity, style: SVGStyle = SVGStyle()) {
        self.d = d
        super.init(svgId: svgId, transform: transform, style: style)
    }
}

final class SVGRect: SVGElement {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var rx: CGFloat?
    var ry: CGFloat?

    init(
        x: CGFloat = 0,
        y: CGFloat = 0,
        width: CGFloat = 0,
        height: CGFloat = 0,
        rx: CGFloat? = nil,
        ry: CGFloat? = nil,
        svgId: String? = nil,
        transform: CGAffineTransform = .identity,
        style: SVGStyle = SVGStyle()
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rx = rx
        self.ry = ry
        super.init(svgId: svgId, transform: transform, style: style)
    }
}

final class SVGCircle: SVGElement {
    var cx: CGFloat
    var cy: CGFloat
    var r: CGFloat

    init(
        cx: CGFloat = 0,
        cy: CGFloat = 0,
        r: CGFloat = 0,
        svgId: String? = nil,
        transform: CGAffineTransform = .identity,
        style: SVGStyle = SVGStyle()
    ) {
        self.cx = cx
        self.cy = cy
        self.r = r
        super.init(svgId: svgId, transform: transform, style: style)
    }
}

class SVGPolyline: SVGElement {
    var points: [CGPoint]

    init(
        points: [CGPoint] = [],
        svgId: String? = nil,
        transform: CGAffineTransform = .identity,
        style: SVGStyle = SVGStyle()
    ) {
        self.points = points
        super.init(svgId: svgId, transform: transform, style: style)
    }
}

/// Closed polygon (`<polygon>`); same as polyline but the renderer closes the subpath.
final class SVGPolygon: SVGPolyline {}
