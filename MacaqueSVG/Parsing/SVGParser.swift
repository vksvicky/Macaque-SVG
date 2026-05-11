import CoreGraphics
import Foundation

enum SVGParserError: Error, Equatable {
    case emptyData
    case noRootSVG
    case invalidStructure
    /// XML parse failed without a specific delegate error (often non‑XML / wrong file type).
    case xmlParsingFailed
}

extension SVGParserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyData:
            return "The SVG file is empty."
        case .noRootSVG:
            return "The file does not contain an <svg> root element."
        case .invalidStructure:
            return "The SVG structure is invalid (unexpected markup or parser state)."
        case .xmlParsingFailed:
            return "The file is not valid XML or is not SVG. If you opened a PNG or other image, use a .svg file instead."
        }
    }
}

struct SVGParser {
    func parse(string: String, encoding: String.Encoding = .utf8, assetBaseDirectory: URL? = nil) throws -> SVGDocument {
        guard let data = string.data(using: encoding) else {
            throw SVGParserError.emptyData
        }
        return try parse(data: data, assetBaseDirectory: assetBaseDirectory, svgSource: string)
    }

    func parse(data: Data, assetBaseDirectory: URL? = nil, svgSource: String? = nil) throws -> SVGDocument {
        guard !data.isEmpty else {
            throw SVGParserError.emptyData
        }

        let parser = XMLParser(data: data)
        let delegate = SVGXMLParserDelegate()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        guard parser.parse() else {
            if let delegateError = delegate.parsingError {
                throw delegateError
            }
            if let underlying = parser.parserError {
                throw underlying
            }
            throw SVGParserError.xmlParsingFailed
        }
        guard let root = delegate.root else {
            throw SVGParserError.noRootSVG
        }
        return SVGDocument(root: root, stylesheet: delegate.stylesheet, assetBaseDirectory: assetBaseDirectory, svgSource: svgSource)
    }
}

private final class SVGXMLParserDelegate: NSObject, XMLParserDelegate {
    var root: SVGRoot?
    var parsingError: Error?
    private(set) var stylesheet = SVGStylesheet()

    private var stack: [SVGElement] = []
    private var styleElementDepth = 0
    private var styleTextBuffer = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = elementName.localElementName
        if name == "svg" {
            if root == nil {
                startRootSVG(attributes: attributeDict)
                return
            }
            guard let container = stack.last as? SVGGroup else {
                parsingError = SVGParserError.invalidStructure
                parser.abortParsing()
                return
            }
            startNestedSVG(container: container, attributes: attributeDict)
            return
        }
        /// `<stop>` is a child of `<linearGradient>` / `<radialGradient>`, which are not `SVGGroup` subclasses.
        if name == "stop" {
            handleStop(attributes: attributeDict)
            return
        }
        guard let container = stack.last as? SVGGroup else {
            parsingError = SVGParserError.invalidStructure
            parser.abortParsing()
            return
        }
        handleChildElementStart(name: name, container: container, attributes: attributeDict)
    }

    private func startRootSVG(attributes: [String: String]) {
        let svgRoot = SVGRoot()
        SVGAttributeApplier.applyCommonAttributes(svgRoot, attributes, stylesheet: stylesheet)
        SVGAttributeApplier.applyRootAttributes(svgRoot, attributes)
        root = svgRoot
        stack = [svgRoot]
    }

    private func startNestedSVG(container: SVGGroup, attributes: [String: String]) {
        let nested = SVGNestedSVG()
        SVGAttributeApplier.applyCommonAttributes(nested, attributes, stylesheet: stylesheet)
        SVGAttributeApplier.applyNestedSVGViewport(nested, attributes)
        container.addChild(nested)
        stack.append(nested)
    }

    private func handleStop(attributes: [String: String]) {
        var stopColor = attributes["stop-color"]
        var stopOpacity = SVGScalarParsing.parseCGFloat(attributes["stop-opacity"])
        var inline = SVGStyle()
        SVGInlineStyle.apply(attributes["style"], to: &inline)
        if let fill = inline.fill {
            stopColor = fill
        }
        if let opacity = inline.opacity {
            stopOpacity = opacity
        }
        let color = SVGPaintResolver.colorForGradientStop(stopColor)
        let opacity = stopOpacity ?? 1
        let stop = SVGGradientStop(offset: SVGScalarParsing.parseStopOffset(attributes["offset"]), color: color.opacity(opacity))
        if let linear = stack.last as? SVGLinearGradientDef {
            linear.appendStop(stop)
        } else if let radial = stack.last as? SVGRadialGradientDef {
            radial.appendStop(stop)
        }
    }

    private func handleChildElementStart(
        name: String,
        container: SVGGroup,
        attributes: [String: String]
    ) {
        switch name {
        case "style":
            styleElementDepth += 1
            styleTextBuffer = ""

        case "defs", "symbol":
            let definitions = SVGDefinitionContainer()
            SVGAttributeApplier.applyCommonAttributes(definitions, attributes, stylesheet: stylesheet)
            container.addChild(definitions)
            stack.append(definitions)

        case "mask":
            let mask = SVGMask()
            SVGAttributeApplier.applyCommonAttributes(mask, attributes, stylesheet: stylesheet)
            container.addChild(mask)
            stack.append(mask)

        case "use":
            guard let fragment = SVGUseAttributeParsing.hrefFragment(from: attributes) else { break }
            let use = SVGUse(
                hrefFragment: fragment,
                x: SVGScalarParsing.parseCGFloat(attributes["x"]) ?? 0,
                y: SVGScalarParsing.parseCGFloat(attributes["y"]) ?? 0,
                useWidth: SVGScalarParsing.parseCGFloat(attributes["width"]),
                useHeight: SVGScalarParsing.parseCGFloat(attributes["height"])
            )
            SVGAttributeApplier.applyCommonAttributes(use, attributes, stylesheet: stylesheet)
            container.addChild(use)

        case "g":
            let group = SVGGroup()
            SVGAttributeApplier.applyCommonAttributes(group, attributes, stylesheet: stylesheet)
            if let rawMask = attributes["mask"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               let fragment = SVGURLPaintParser.paintServerFragment(from: rawMask) {
                group.maskHrefFragment = fragment
            }
            container.addChild(group)
            stack.append(group)

        case "path":
            let path = SVGPath(d: attributes["d"] ?? "")
            SVGAttributeApplier.applyCommonAttributes(path, attributes, stylesheet: stylesheet)
            container.addChild(path)

        case "rect":
            let rect = SVGRect(
                x: SVGScalarParsing.parseCGFloat(attributes["x"]) ?? 0,
                y: SVGScalarParsing.parseCGFloat(attributes["y"]) ?? 0,
                width: SVGScalarParsing.parseCGFloat(attributes["width"]) ?? 0,
                height: SVGScalarParsing.parseCGFloat(attributes["height"]) ?? 0,
                rx: SVGScalarParsing.parseCGFloat(attributes["rx"]),
                ry: SVGScalarParsing.parseCGFloat(attributes["ry"])
            )
            SVGAttributeApplier.applyCommonAttributes(rect, attributes, stylesheet: stylesheet)
            container.addChild(rect)

        case "circle":
            let circle = SVGCircle(
                cx: SVGScalarParsing.parseCGFloat(attributes["cx"]) ?? 0,
                cy: SVGScalarParsing.parseCGFloat(attributes["cy"]) ?? 0,
                r: SVGScalarParsing.parseCGFloat(attributes["r"]) ?? 0
            )
            SVGAttributeApplier.applyCommonAttributes(circle, attributes, stylesheet: stylesheet)
            container.addChild(circle)

        case "polyline":
            let polyline = SVGPolyline(points: SVGScalarParsing.parsePointsList(attributes["points"]))
            SVGAttributeApplier.applyCommonAttributes(polyline, attributes, stylesheet: stylesheet)
            container.addChild(polyline)

        case "polygon":
            let polygon = SVGPolygon(points: SVGScalarParsing.parsePointsList(attributes["points"]))
            SVGAttributeApplier.applyCommonAttributes(polygon, attributes, stylesheet: stylesheet)
            container.addChild(polygon)

        case "image":
            let rawHref =
                attributes["href"]
                ?? attributes["xlink:href"]
                ?? attributes["{http://www.w3.org/1999/xlink}href"]
                ?? ""
            let image = SVGImage(
                x: SVGScalarParsing.parseCGFloat(attributes["x"]) ?? 0,
                y: SVGScalarParsing.parseCGFloat(attributes["y"]) ?? 0,
                width: SVGScalarParsing.parseCGFloat(attributes["width"]) ?? 0,
                height: SVGScalarParsing.parseCGFloat(attributes["height"]) ?? 0,
                href: rawHref
            )
            image.preserveAspectRatio = attributes["preserveAspectRatio"] ?? attributes["preserveaspectratio"]
            SVGAttributeApplier.applyCommonAttributes(image, attributes, stylesheet: stylesheet)
            container.addChild(image)

        case "linearGradient":
            let units = (attributes["gradientUnits"] ?? "objectBoundingBox").lowercased()
            let isObjectBox = units != "userspaceonuse"
            let linear: SVGLinearGradientDef
            if isObjectBox {
                linear = SVGLinearGradientDef(
                    x1: SVGScalarParsing.parseGradientAxis(attributes["x1"], default: 0),
                    y1: SVGScalarParsing.parseGradientAxis(attributes["y1"], default: 0),
                    x2: SVGScalarParsing.parseGradientAxis(attributes["x2"], default: 1),
                    y2: SVGScalarParsing.parseGradientAxis(attributes["y2"], default: 0),
                    gradientUnits: attributes["gradientUnits"] ?? "objectBoundingBox",
                    svgId: nil,
                    transform: .identity,
                    style: SVGStyle()
                )
            } else {
                linear = SVGLinearGradientDef(
                    x1: SVGScalarParsing.parseCGFloat(attributes["x1"]) ?? 0,
                    y1: SVGScalarParsing.parseCGFloat(attributes["y1"]) ?? 0,
                    x2: SVGScalarParsing.parseCGFloat(attributes["x2"]) ?? 1,
                    y2: SVGScalarParsing.parseCGFloat(attributes["y2"]) ?? 0,
                    gradientUnits: "userSpaceOnUse",
                    svgId: nil,
                    transform: .identity,
                    style: SVGStyle()
                )
            }
            SVGAttributeApplier.applyCommonAttributes(linear, attributes, stylesheet: stylesheet)
            container.addChild(linear)
            stack.append(linear)

        case "radialGradient":
            let units = (attributes["gradientUnits"] ?? "objectBoundingBox").lowercased()
            let isObjectBox = units != "userspaceonuse"
            let radial: SVGRadialGradientDef
            if isObjectBox {
                radial = SVGRadialGradientDef(
                    cx: SVGScalarParsing.parseGradientAxis(attributes["cx"], default: 0.5),
                    cy: SVGScalarParsing.parseGradientAxis(attributes["cy"], default: 0.5),
                    r: SVGScalarParsing.parseGradientAxis(attributes["r"], default: 0.5),
                    gradientUnits: attributes["gradientUnits"] ?? "objectBoundingBox",
                    svgId: nil,
                    transform: .identity,
                    style: SVGStyle()
                )
            } else {
                radial = SVGRadialGradientDef(
                    cx: SVGScalarParsing.parseCGFloat(attributes["cx"]) ?? 0.5,
                    cy: SVGScalarParsing.parseCGFloat(attributes["cy"]) ?? 0.5,
                    r: SVGScalarParsing.parseCGFloat(attributes["r"]) ?? 0.5,
                    gradientUnits: "userSpaceOnUse",
                    svgId: nil,
                    transform: .identity,
                    style: SVGStyle()
                )
            }
            SVGAttributeApplier.applyCommonAttributes(radial, attributes, stylesheet: stylesheet)
            container.addChild(radial)
            stack.append(radial)

        case "text":
            let block = SVGTextBlock()
            block.x = SVGScalarParsing.parseCGFloat(attributes["x"]) ?? 0
            block.y = SVGScalarParsing.parseCGFloat(attributes["y"]) ?? 0
            block.fontFamily = attributes["font-family"] ?? attributes["fontFamily"]
            block.fontSize = SVGScalarParsing.parseCGFloat(attributes["font-size"] ?? attributes["fontSize"])
            block.fontWeightValue = SVGScalarParsing.parseFontWeight(attributes["font-weight"] ?? attributes["fontWeight"])
            block.letterSpacing = attributes["letter-spacing"] ?? attributes["letterSpacing"]
            SVGAttributeApplier.applyCommonAttributes(block, attributes, stylesheet: stylesheet)
            container.addChild(block)
            stack.append(block)

        case "textPath":
            let textPath = SVGTextPath()
            let rawHref =
                attributes["href"]
                ?? attributes["xlink:href"]
                ?? attributes["{http://www.w3.org/1999/xlink}href"]
                ?? ""
            textPath.pathHrefFragment = SVGHrefParsing.fragmentId(from: rawHref) ?? ""
            textPath.startOffset = attributes["startOffset"] ?? attributes["start-offset"]
            textPath.textAnchor = attributes["text-anchor"] ?? attributes["textAnchor"]
            SVGAttributeApplier.applyCommonAttributes(textPath, attributes, stylesheet: stylesheet)
            if let block = container as? SVGTextBlock {
                textPath.hostTextBlock = block
            }
            container.addChild(textPath)
            stack.append(textPath)

        case "tspan":
            let span = SVGTSpanNode()
            SVGAttributeApplier.applyCommonAttributes(span, attributes, stylesheet: stylesheet)
            container.addChild(span)
            stack.append(span)

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.localElementName
        switch name {
        case "style":
            if styleElementDepth > 0 {
                styleElementDepth -= 1
                stylesheet.append(css: styleTextBuffer)
                styleTextBuffer = ""
            }

        case "textPath":
            if let textPath = stack.last as? SVGTextPath {
                textPath.inlineText = textPath.inlineText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if stack.count > 1 {
                stack.removeLast()
            }

        case "tspan":
            if stack.count > 1 {
                stack.removeLast()
            }

        case "text":
            if let block = stack.last as? SVGTextBlock {
                if !block.children.isEmpty {
                    block.plainText = ""
                } else {
                    block.plainText = block.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            if stack.count > 1 {
                stack.removeLast()
            }

        case "g", "defs", "symbol", "mask", "linearGradient", "radialGradient":
            if stack.count > 1 {
                stack.removeLast()
            }
        case "svg":
            if !stack.isEmpty {
                stack.removeLast()
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if styleElementDepth > 0 {
            styleTextBuffer.append(string)
            return
        }

        if let span = stack.last as? SVGTSpanNode {
            span.text.append(string)
            return
        }
        if let textPath = stack.last as? SVGTextPath {
            textPath.inlineText.append(string)
            return
        }
        if let block = stack.last as? SVGTextBlock {
            block.plainText.append(string)
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATA: Data) {
        guard styleElementDepth > 0 else { return }
        if let chunk = String(data: CDATA, encoding: .utf8) {
            styleTextBuffer.append(chunk)
        }
    }
}

private extension String {
    var localElementName: String {
        if let colon = lastIndex(of: ":") {
            return String(self[index(after: colon)...])
        }
        return self
    }
}

enum SVGScalarParsing {
    static func parseCGFloat(_ raw: String?) -> CGFloat? {
        guard var token = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return nil
        }

        if token.hasSuffix("%") {
            return nil
        }

        let unitSuffixes = ["px", "pt", "pc", "mm", "cm", "in", "em", "ex"]
        for suffix in unitSuffixes where token.lowercased().hasSuffix(suffix) {
            token = String(token.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        guard let value = Double(token) else { return nil }
        return CGFloat(value)
    }

    static func parseViewBox(_ raw: String?) -> CGRect? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let parts = raw.split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map(String.init)
            .compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        return CGRect(
            x: CGFloat(parts[0]),
            y: CGFloat(parts[1]),
            width: CGFloat(parts[2]),
            height: CGFloat(parts[3])
        )
    }

    /// Parses SVG `points="x y x y …"` (commas and/or whitespace separated).
    static func parsePointsList(_ raw: String?) -> [CGPoint] {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return []
        }
        let normalized = raw.replacingOccurrences(of: ",", with: " ")
        let tokens = normalized.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var values: [CGFloat] = []
        for token in tokens {
            if let value = parseCGFloat(token) {
                values.append(value)
            }
        }
        var points: [CGPoint] = []
        var index = 0
        while index + 1 < values.count {
            points.append(CGPoint(x: values[index], y: values[index + 1]))
            index += 2
        }
        return points
    }

    /// Gradient axis or stop offset: number, or percentage of 0–1 range.
    static func parseGradientAxis(_ raw: String?, default defaultValue: CGFloat) -> CGFloat {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return defaultValue
        }
        if raw.hasSuffix("%") {
            guard let value = Double(raw.dropLast()) else { return defaultValue }
            return CGFloat(value / 100)
        }
        return parseCGFloat(raw) ?? defaultValue
    }

    static func parseStopOffset(_ raw: String?) -> CGFloat {
        parseGradientAxis(raw, default: 0)
    }

    /// Parses `font-weight` presentation values (`400`, `bold`, …).
    static func parseFontWeight(_ raw: String?) -> CGFloat? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let lower = raw.lowercased()
        switch lower {
        case "normal": return 400
        case "bold": return 700
        default: return parseCGFloat(raw)
        }
    }
}

enum SVGAttributeApplier {
    static func applyCommonAttributes(
        _ element: SVGElement,
        _ attributes: [String: String],
        stylesheet: SVGStylesheet
    ) {
        if let id = attributes["id"] {
            element.svgId = id
        }

        if let className = attributes["class"] {
            element.svgClass = className.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let transformString = attributes["transform"] {
            element.transform = SVGTransformParsing.parse(transformString)
        }

        if let fill = attributes["fill"] {
            element.style.fill = fill
        }
        if let stroke = attributes["stroke"] {
            element.style.stroke = stroke
        }
        if let width = SVGScalarParsing.parseCGFloat(attributes["stroke-width"] ?? attributes["strokeWidth"]) {
            element.style.strokeWidth = width
        }
        if let opacity = SVGScalarParsing.parseCGFloat(attributes["opacity"]) {
            element.style.opacity = opacity
        }

        stylesheet.apply(to: &element.style, classList: element.svgClass, elementId: element.svgId)
        SVGInlineStyle.apply(attributes["style"], to: &element.style)
    }

    static func applyRootAttributes(_ root: SVGRoot, _ attributes: [String: String]) {
        root.viewBox = SVGScalarParsing.parseViewBox(attributes["viewBox"])
        root.width = SVGScalarParsing.parseCGFloat(attributes["width"])
        root.height = SVGScalarParsing.parseCGFloat(attributes["height"])
    }

    static func applyNestedSVGViewport(_ nested: SVGNestedSVG, _ attributes: [String: String]) {
        nested.viewBox = SVGScalarParsing.parseViewBox(attributes["viewBox"])
        nested.width = SVGScalarParsing.parseCGFloat(attributes["width"])
        nested.height = SVGScalarParsing.parseCGFloat(attributes["height"])
    }
}

enum SVGTransformParsing {
    static func parse(_ raw: String) -> CGAffineTransform {
        let normalized = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        var result = CGAffineTransform.identity

        let pattern = #"(\w+)\(([^)]*)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return .identity
        }

        let fullRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        regex.enumerateMatches(in: normalized, options: [], range: fullRange) { match, _, _ in
            guard let match, match.numberOfRanges >= 3,
                  let nameRange = Range(match.range(at: 1), in: normalized),
                  let argsRange = Range(match.range(at: 2), in: normalized)
            else { return }

            let name = String(normalized[nameRange]).lowercased()
            let argsString = String(normalized[argsRange])

            switch name {
            case "translate":
                let nums = parseNumbers(argsString)
                if let offsetX = nums.first {
                    let offsetY = nums.count > 1 ? nums[1] : 0
                    result = CGAffineTransform(translationX: offsetX, y: offsetY).concatenating(result)
                }
            case "scale":
                let nums = parseNumbers(argsString)
                if let scaleX = nums.first {
                    let scaleY = nums.count > 1 ? nums[1] : scaleX
                    result = CGAffineTransform(scaleX: scaleX, y: scaleY).concatenating(result)
                }
            case "matrix":
                let nums = parseNumbers(argsString)
                if nums.count >= 6 {
                    let matrix = CGAffineTransform(
                        a: nums[0], b: nums[1],
                        c: nums[2], d: nums[3],
                        tx: nums[4], ty: nums[5]
                    )
                    result = matrix.concatenating(result)
                }
            default:
                break
            }
        }

        return result
    }

    private static func parseNumbers(_ raw: String) -> [CGFloat] {
        let separators = CharacterSet(charactersIn: ", \t")
        return raw
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { Double($0) }
            .map { CGFloat($0) }
    }
}
