import AppKit
import CoreGraphics
import SwiftUI

enum SVGSceneRenderer {
    private static let maxUseDepth = 12

    static func draw(
        root: SVGRoot,
        idIndex: [String: SVGElement],
        assetBaseDirectory: URL?,
        context: inout GraphicsContext
    ) {
        let base = root.transform
        let children = root.children
        let onlyDefinitionRoots = !children.isEmpty && children.allSatisfy { $0 is SVGDefinitionContainer }
        if onlyDefinitionRoots {
            for child in children {
                draw(
                    element: child,
                    idIndex: idIndex,
                    assetBaseDirectory: assetBaseDirectory,
                    context: &context,
                    parentTransform: base,
                    useDepth: 0,
                    renderDefinitionSubtrees: true
                )
            }
            return
        }

        for child in children {
            draw(
                element: child,
                idIndex: idIndex,
                assetBaseDirectory: assetBaseDirectory,
                context: &context,
                parentTransform: base,
                useDepth: 0,
                renderDefinitionSubtrees: false
            )
        }
    }

    private static func draw(
        element: SVGElement,
        idIndex: [String: SVGElement],
        assetBaseDirectory: URL?,
        context: inout GraphicsContext,
        parentTransform: CGAffineTransform,
        useDepth: Int,
        renderDefinitionSubtrees: Bool
    ) {
        if element is SVGDefinitionContainer, !renderDefinitionSubtrees {
            return
        }
        if element is SVGMask, !renderDefinitionSubtrees {
            return
        }

        if let use = element as? SVGUse {
            guard useDepth < maxUseDepth else { return }
            guard let target = idIndex[use.hrefFragment] else { return }
            let base = parentTransform.concatenating(use.transform)
            let withOffset = base.concatenating(CGAffineTransform(translationX: use.x, y: use.y))
            let opacity = use.style.opacity ?? 1
            if opacity != 1 {
                context.opacity *= opacity
            }
            draw(
                element: target,
                idIndex: idIndex,
                assetBaseDirectory: assetBaseDirectory,
                context: &context,
                parentTransform: withOffset,
                useDepth: useDepth + 1,
                renderDefinitionSubtrees: true
            )
            if opacity != 1 {
                context.opacity /= opacity
            }
            return
        }

        if let textPath = element as? SVGTextPath {
            let world = parentTransform.concatenating(textPath.transform)
            let opacity = textPath.style.opacity ?? 1
            if opacity != 1 {
                context.opacity *= opacity
            }
            context.concatenate(world)
            if let cache = SVGTextPathRenderer.cachedRender(textPath: textPath, idIndex: idIndex) {
                context.draw(Image(nsImage: cache.image), in: cache.destination)
            }
            context.concatenate(world.inverted())
            if opacity != 1 {
                context.opacity /= opacity
            }
            return
        }

        if let textBlock = element as? SVGTextBlock {
            let textOrigin = CGAffineTransform(translationX: textBlock.x, y: textBlock.y)
            let world = parentTransform.concatenating(textOrigin).concatenating(textBlock.transform)
            let opacity = textBlock.style.opacity ?? 1
            if opacity != 1 {
                context.opacity *= opacity
            }
            if textBlock.children.isEmpty {
                context.concatenate(world)
                drawPlainTextBlock(textBlock, context: &context)
                context.concatenate(world.inverted())
            } else {
                for child in textBlock.children {
                    draw(
                        element: child,
                        idIndex: idIndex,
                        assetBaseDirectory: assetBaseDirectory,
                        context: &context,
                        parentTransform: world,
                        useDepth: useDepth,
                        renderDefinitionSubtrees: renderDefinitionSubtrees
                    )
                }
            }
            if opacity != 1 {
                context.opacity /= opacity
            }
            return
        }

        if let group = element as? SVGGroup {
            let world = parentTransform.concatenating(group.transform)
            let opacity = group.style.opacity ?? 1
            if opacity != 1 {
                context.opacity *= opacity
            }

            let maskFragment = group.maskHrefFragment
            if let fragment = maskFragment, !fragment.isEmpty,
               let mask = idIndex[fragment] as? SVGMask,
               let maskPath = SVGMaskClipPathBuilder.combinedPath(from: mask)
            {
                let clip = maskPath.applying(world)
                context.drawLayer { sub in
                    sub.clip(to: clip)
                    for child in group.children {
                        draw(
                            element: child,
                            idIndex: idIndex,
                            assetBaseDirectory: assetBaseDirectory,
                            context: &sub,
                            parentTransform: world,
                            useDepth: useDepth,
                            renderDefinitionSubtrees: renderDefinitionSubtrees
                        )
                    }
                }
            } else {
                for child in group.children {
                    draw(
                        element: child,
                        idIndex: idIndex,
                        assetBaseDirectory: assetBaseDirectory,
                        context: &context,
                        parentTransform: world,
                        useDepth: useDepth,
                        renderDefinitionSubtrees: renderDefinitionSubtrees
                    )
                }
            }

            if opacity != 1 {
                context.opacity /= opacity
            }
            return
        }

        let world = parentTransform.concatenating(element.transform)
        drawLeaf(
            element: element,
            world: world,
            assetBaseDirectory: assetBaseDirectory,
            context: &context,
            idIndex: idIndex
        )
    }

    private static func drawPlainTextBlock(_ block: SVGTextBlock, context: inout GraphicsContext) {
        let fill = SVGPaintResolver.fillColor(block.style.fill) ?? .primary
        let resolved = block.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolved.isEmpty else { return }
        let size = max(block.fontSize ?? 14, 1)
        let weightValue = block.fontWeightValue ?? 400
        let weight: Font.Weight
        if weightValue >= 700 {
            weight = .bold
        } else if weightValue >= 600 {
            weight = .semibold
        } else if weightValue >= 500 {
            weight = .medium
        } else {
            weight = .regular
        }
        context.draw(
            Text(resolved).font(.system(size: size, weight: weight)).foregroundStyle(fill),
            at: .zero,
            anchor: .topLeading
        )
    }

    private static func drawLeaf(
        element: SVGElement,
        world: CGAffineTransform,
        assetBaseDirectory: URL?,
        context: inout GraphicsContext,
        idIndex: [String: SVGElement]
    ) {
        let opacityScale = element.style.opacity ?? 1
        if opacityScale != 1 {
            context.opacity *= opacityScale
        }
        context.concatenate(world)

        if let rect = element as? SVGRect {
            let path = roundedRectPath(rect)
            paint(style: rect.style, path: path, context: &context, idIndex: idIndex)
        } else if let circle = element as? SVGCircle {
            let rect = CGRect(
                x: circle.cx - circle.r,
                y: circle.cy - circle.r,
                width: circle.r * 2,
                height: circle.r * 2
            )
            let path = Path(ellipseIn: rect)
            paint(style: circle.style, path: path, context: &context, idIndex: idIndex)
        } else if let svgPath = element as? SVGPath {
            let path = SVGPathDataParser.path(from: svgPath.d)
            paint(style: svgPath.style, path: path, context: &context, idIndex: idIndex)
        } else if let poly = element as? SVGPolyline {
            let path = pathFromPolyline(poly, close: poly is SVGPolygon)
            paint(style: poly.style, path: path, context: &context, idIndex: idIndex)
        } else if let svgImage = element as? SVGImage {
            drawEmbeddedImage(svgImage, assetBaseDirectory: assetBaseDirectory, context: &context)
        }

        context.concatenate(world.inverted())
        if opacityScale != 1 {
            context.opacity /= opacityScale
        }
    }

    private static func drawEmbeddedImage(
        _ svgImage: SVGImage,
        assetBaseDirectory: URL?,
        context: inout GraphicsContext
    ) {
        guard svgImage.width > 0, svgImage.height > 0 else { return }
        guard let nsImage = svgImage.displayBitmap(assetBaseDirectory: assetBaseDirectory) else { return }
        let outer = CGRect(x: svgImage.x, y: svgImage.y, width: svgImage.width, height: svgImage.height)
        let inner = SVGAspectRatioMeet.destinationRect(
            container: outer,
            intrinsicSize: nsImage.size,
            preserveAspectRatio: svgImage.preserveAspectRatio
        )
        context.draw(Image(nsImage: nsImage), in: inner)
    }

    private static func paint(style: SVGStyle, path: Path, context: inout GraphicsContext, idIndex: [String: SVGElement]) {
        applyFill(style: style, path: path, context: &context, idIndex: idIndex)
        applyStroke(style: style, path: path, context: &context, idIndex: idIndex)
    }

    private static func applyFill(style: SVGStyle, path: Path, context: inout GraphicsContext, idIndex: [String: SVGElement]) {
        if let fill = style.fill, let fragment = SVGURLPaintParser.paintServerFragment(from: fill) {
            if let linear = idIndex[fragment] as? SVGLinearGradientDef {
                fillLinearGradient(linear, path: path, context: &context)
            } else if let radial = idIndex[fragment] as? SVGRadialGradientDef {
                fillRadialGradient(radial, path: path, context: &context)
            }
            return
        }
        if let fillColor = SVGPaintResolver.fillColor(style.fill) {
            context.fill(path, with: .color(fillColor))
        }
    }

    private static func applyStroke(style: SVGStyle, path: Path, context: inout GraphicsContext, idIndex: [String: SVGElement]) {
        let width = style.strokeWidth ?? 1
        guard width > 0 else { return }

        if let stroke = style.stroke, let fragment = SVGURLPaintParser.paintServerFragment(from: stroke) {
            if let linear = idIndex[fragment] as? SVGLinearGradientDef {
                strokeLinearGradient(linear, path: path, context: &context, lineWidth: width)
            } else if let radial = idIndex[fragment] as? SVGRadialGradientDef {
                strokeRadialGradient(radial, path: path, context: &context, lineWidth: width)
            }
            return
        }
        if let strokeColor = SVGPaintResolver.strokeColor(style.stroke) {
            context.stroke(path, with: .color(strokeColor), lineWidth: width)
        }
    }

    private static func fillLinearGradient(
        _ definition: SVGLinearGradientDef,
        path: Path,
        context: inout GraphicsContext
    ) {
        guard !definition.stops.isEmpty else { return }
        let bounds = path.boundingRect
        let sorted = definition.stops.sorted { $0.offset < $1.offset }
        let swiftStops = sorted.map { Gradient.Stop(color: $0.color, location: min(max($0.offset, 0), 1)) }
        let gradient = Gradient(stops: swiftStops)

        let startPoint: CGPoint
        let endPoint: CGPoint
        if definition.gradientUnits.lowercased() == "userspaceonuse" {
            startPoint = CGPoint(x: definition.x1, y: definition.y1)
            endPoint = CGPoint(x: definition.x2, y: definition.y2)
        } else {
            startPoint = CGPoint(x: bounds.minX + definition.x1 * bounds.width, y: bounds.minY + definition.y1 * bounds.height)
            endPoint = CGPoint(x: bounds.minX + definition.x2 * bounds.width, y: bounds.minY + definition.y2 * bounds.height)
        }
        context.fill(path, with: .linearGradient(gradient, startPoint: startPoint, endPoint: endPoint))
    }

    private static func fillRadialGradient(
        _ definition: SVGRadialGradientDef,
        path: Path,
        context: inout GraphicsContext
    ) {
        guard !definition.stops.isEmpty else { return }
        let bounds = path.boundingRect
        let sorted = definition.stops.sorted { $0.offset < $1.offset }
        let swiftStops = sorted.map { Gradient.Stop(color: $0.color, location: min(max($0.offset, 0), 1)) }
        let gradient = Gradient(stops: swiftStops)

        let center: CGPoint
        let endRadius: CGFloat
        if definition.gradientUnits.lowercased() == "userspaceonuse" {
            center = CGPoint(x: definition.cx, y: definition.cy)
            endRadius = max(definition.r, 0)
        } else {
            center = CGPoint(x: bounds.minX + definition.cx * bounds.width, y: bounds.minY + definition.cy * bounds.height)
            endRadius = max(definition.r, 0) * max(bounds.width, bounds.height)
        }
        context.fill(path, with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: max(endRadius, 0.0001)))
    }

    private static func strokeLinearGradient(
        _ definition: SVGLinearGradientDef,
        path: Path,
        context: inout GraphicsContext,
        lineWidth: CGFloat
    ) {
        guard !definition.stops.isEmpty else { return }
        let bounds = path.boundingRect
        let sorted = definition.stops.sorted { $0.offset < $1.offset }
        let swiftStops = sorted.map { Gradient.Stop(color: $0.color, location: min(max($0.offset, 0), 1)) }
        let gradient = Gradient(stops: swiftStops)

        let startPoint: CGPoint
        let endPoint: CGPoint
        if definition.gradientUnits.lowercased() == "userspaceonuse" {
            startPoint = CGPoint(x: definition.x1, y: definition.y1)
            endPoint = CGPoint(x: definition.x2, y: definition.y2)
        } else {
            startPoint = CGPoint(x: bounds.minX + definition.x1 * bounds.width, y: bounds.minY + definition.y1 * bounds.height)
            endPoint = CGPoint(x: bounds.minX + definition.x2 * bounds.width, y: bounds.minY + definition.y2 * bounds.height)
        }
        context.stroke(path, with: .linearGradient(gradient, startPoint: startPoint, endPoint: endPoint), lineWidth: lineWidth)
    }

    private static func strokeRadialGradient(
        _ definition: SVGRadialGradientDef,
        path: Path,
        context: inout GraphicsContext,
        lineWidth: CGFloat
    ) {
        guard !definition.stops.isEmpty else { return }
        let bounds = path.boundingRect
        let sorted = definition.stops.sorted { $0.offset < $1.offset }
        let swiftStops = sorted.map { Gradient.Stop(color: $0.color, location: min(max($0.offset, 0), 1)) }
        let gradient = Gradient(stops: swiftStops)

        let center: CGPoint
        let endRadius: CGFloat
        if definition.gradientUnits.lowercased() == "userspaceonuse" {
            center = CGPoint(x: definition.cx, y: definition.cy)
            endRadius = max(definition.r, 0)
        } else {
            center = CGPoint(x: bounds.minX + definition.cx * bounds.width, y: bounds.minY + definition.cy * bounds.height)
            endRadius = max(definition.r, 0) * max(bounds.width, bounds.height)
        }
        context.stroke(
            path,
            with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: max(endRadius, 0.0001)),
            lineWidth: lineWidth
        )
    }

    private static func pathFromPolyline(_ poly: SVGPolyline, close: Bool) -> Path {
        var path = Path()
        guard let first = poly.points.first else { return path }
        path.move(to: first)
        for point in poly.points.dropFirst() {
            path.addLine(to: point)
        }
        if close {
            path.closeSubpath()
        }
        return path
    }

    private static func roundedRectPath(_ rect: SVGRect) -> Path {
        let frame = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        let radiusX = rect.rx ?? 0
        let radiusY = rect.ry ?? rect.rx ?? 0
        guard radiusX > 0, radiusY > 0 else {
            return Path(frame)
        }
        var path = Path()
        path.addRoundedRect(in: frame, cornerSize: CGSize(width: radiusX, height: radiusY))
        return path
    }
}
