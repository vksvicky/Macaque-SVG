import AppKit
import CoreGraphics
import CoreText
import Foundation
import SwiftUI

enum SVGTextPathRenderer {
    static func cachedRender(textPath: SVGTextPath, idIndex: [String: SVGElement]) -> (image: NSImage, destination: CGRect)? {
        if let cached = textPath.cachedRender {
            return cached
        }
        guard let built = buildCache(textPath: textPath, idIndex: idIndex) else { return nil }
        textPath.cachedRender = built
        return built
    }

    private static func buildCache(textPath: SVGTextPath, idIndex: [String: SVGElement]) -> (image: NSImage, destination: CGRect)? {
        guard let pathEl = idIndex[textPath.pathHrefFragment] as? SVGPath else { return nil }
        // Match painted `<path>` geometry: `d` is local; `transform` is applied when the path is drawn elsewhere.
        let swiftPath = SVGPathDataParser.path(from: pathEl.d).applying(pathEl.transform)
        let samples = SVGPathLengthSampler.samples(from: swiftPath)
        guard let pathLen = samples.last?.distance, pathLen > 2 else { return nil }

        let block = textPath.hostTextBlock
        let fontSize = max(block?.fontSize ?? 16, 1)
        let weight = block?.fontWeightValue ?? 400
        let nsFont = resolvedFont(family: block?.fontFamily, size: fontSize, weight: weight)

        var segments: [(String, NSColor)] = []
        for child in textPath.children.compactMap({ $0 as? SVGTSpanNode }) {
            let color = SVGPaintResolver.nsColor(forFill: child.style.fill) ?? NSColor.labelColor
            let fragment = child.text.replacingOccurrences(of: "\n", with: " ")
            guard !fragment.isEmpty else { continue }
            segments.append((fragment, color))
        }
        if segments.isEmpty {
            let fragment = textPath.inlineText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !fragment.isEmpty {
                // Inherit `<text fill="…">` when `<textPath>` has no usable fill (SVG inheritance; stylesheet may set a dark default on textPath).
                let fill = SVGPaintResolver.nsColor(forFill: block?.style.fill)
                    ?? SVGPaintResolver.nsColor(forFill: textPath.style.fill)
                    ?? NSColor.labelColor
                segments.append((fragment, fill))
            }
        }
        guard !segments.isEmpty else { return nil }

        let letterExtra = letterSpacingPoints(block?.letterSpacing, fontSize: fontSize)
        var totalNaturalWidth: CGFloat = 0
        var totalGlyphCount = 0
        var segmentCaches: [(line: CTLine, placements: [(midX: CGFloat, advance: CGFloat)], naturalWidth: CGFloat)] = []
        for (str, color) in segments {
            let attr = attributedSegment(string: str, font: nsFont, color: color)
            let line = CTLineCreateWithAttributedString(attr)
            // Do not use CTRun positions/advances here: on some contexts they collapse to 0 or run-local
            // values, which stacks every glyph at one path distance. String-index offsets match the line width.
            let placements = composedClusterPlacements(line: line, attributed: attr)
            guard !placements.isEmpty else { continue }
            let naturalWidth = ctLineWidth(attr)
            totalNaturalWidth += naturalWidth
            totalGlyphCount += placements.count
            segmentCaches.append((line, placements, naturalWidth))
        }
        guard !segmentCaches.isEmpty else { return nil }
        let gapCount = max(0, totalGlyphCount - 1)
        let totalWidth = totalNaturalWidth + CGFloat(gapCount) * letterExtra
        guard totalWidth > 0 else { return nil }

        let startDist = textStartDistance(
            pathLen: pathLen,
            totalWidth: totalWidth,
            textAnchor: textPath.textAnchor,
            startOffset: textPath.startOffset
        )

        let pad = max(fontSize * 2.5, 48)
        let bbox = pixelSnappedBounds(path: swiftPath, pad: pad)
        guard bbox.width > 0, bbox.height > 0 else { return nil }

        let img = NSImage(size: NSSize(width: bbox.width, height: bbox.height))
        img.lockFocus()
        defer { img.unlockFocus() }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }

        // Path and sampler use SVG user space (+Y down). Use a flipped graphics state so drawing matches that space
        // (NSImage lockFocus defaults to +Y up, which would mirror geometry and break tangent angles).
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(bbox.height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: -bbox.minX, y: -bbox.minY)

        // Letter-spacing: extra gap only *between* glyphs (see `letterSpacingPoints`).
        // Each glyph is drawn with a clipped `CTLineDraw` of the full segment so pair kerning / ligatures match
        // the Core Text metrics used for `mid` (isolated `NSString.draw` does not).
        var segmentNaturalBase: CGFloat = 0
        var globalGlyphIndex = 0
        for cache in segmentCaches {
            for placement in cache.placements {
                let mid = startDist + segmentNaturalBase + placement.midX + CGFloat(globalGlyphIndex) * letterExtra
                globalGlyphIndex += 1
                if let (point, ang) = SVGPathLengthSampler.pointAndAngle(samples: samples, atDistance: mid) {
                    drawClippedSegmentGlyph(
                        ctx: ctx,
                        line: cache.line,
                        midX: placement.midX,
                        advance: placement.advance,
                        point: point,
                        angle: ang,
                        font: nsFont
                    )
                }
            }
            segmentNaturalBase += cache.naturalWidth
        }
        ctx.restoreGState()

        return (img, bbox)
    }

    /// SVG / CSS `letter-spacing` as extra points between adjacent typographic units (approximate for `%` / unitless).
    private static func letterSpacingPoints(_ raw: String?, fontSize: CGFloat) -> CGFloat {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return 0 }
        let lower = raw.lowercased()
        if lower == "normal" { return 0 }
        if lower.hasSuffix("em") {
            let n = String(lower.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            return CGFloat(Double(n) ?? 0) * fontSize
        }
        if lower.hasSuffix("ex") {
            let n = String(lower.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            return CGFloat(Double(n) ?? 0) * fontSize * 0.5
        }
        if lower.hasSuffix("%") {
            let n = String(lower.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            return CGFloat(Double(n) ?? 0) / 100 * fontSize
        }
        let stripped = raw.replacingOccurrences(of: "px", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return CGFloat(Double(stripped) ?? 0)
    }

    private static func attributedSegment(string: String, font: NSFont, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    }

    private static func ctLineWidth(_ attributed: NSAttributedString) -> CGFloat {
        guard attributed.length > 0 else { return 0 }
        let line = CTLineCreateWithAttributedString(attributed)
        var secondary: CGFloat = 0
        // Trailing offset matches the sum of per-cluster advances from `CTLineGetOffsetForStringIndex`.
        return CGFloat(CTLineGetOffsetForStringIndex(line, attributed.length, &secondary))
    }

    /// Horizontal center and advance per composed cluster, from the same `CTLine` used for `CTLineDraw` (includes kerning).
    private static func composedClusterPlacements(line: CTLine, attributed: NSAttributedString) -> [(midX: CGFloat, advance: CGFloat)] {
        let ns = attributed.string as NSString
        guard ns.length > 0 else { return [] }
        var items: [(CGFloat, CGFloat)] = []
        var i = 0
        while i < ns.length {
            let composed = ns.rangeOfComposedCharacterSequence(at: i)
            let startIdx = composed.location
            let endIdx = composed.location + composed.length
            var secondary: CGFloat = 0
            let startX = CGFloat(CTLineGetOffsetForStringIndex(line, startIdx, &secondary))
            let endX = CGFloat(CTLineGetOffsetForStringIndex(line, endIdx, &secondary))
            let advance = max(0, endX - startX)
            let midX = (startX + endX) / 2
            items.append((midX, advance))
            i = endIdx
        }
        return items
    }

    private static func drawClippedSegmentGlyph(
        ctx: CGContext,
        line: CTLine,
        midX: CGFloat,
        advance: CGFloat,
        point: CGPoint,
        angle: CGFloat,
        font: NSFont
    ) {
        let nudgeY = CGFloat(font.ascender * 0.35)
        let band = max(abs(font.ascender) + abs(font.descender) + font.leading, font.capHeight) + 8
        let safeAdvance = max(advance, 0.5)
        let slop = max(2, safeAdvance * 0.2)
        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y)
        ctx.rotate(by: angle)
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: 0, y: nudgeY)
        ctx.translateBy(x: -midX, y: 0)
        ctx.clip(to: CGRect(x: -safeAdvance / 2 - slop, y: -band, width: safeAdvance + 2 * slop, height: 2 * band))
        ctx.textMatrix = .identity
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    /// Whole-pixel bounds so `NSImage.size` matches `destination.size` exactly (avoids sub-pixel stretch vs vector art).
    private static func pixelSnappedBounds(path: Path, pad: CGFloat) -> CGRect {
        let loose = path.boundingRect.insetBy(dx: -pad, dy: -pad)
        let minX = floor(loose.minX)
        let minY = floor(loose.minY)
        let maxX = ceil(loose.maxX)
        let maxY = ceil(loose.maxY)
        let w = max(1, maxX - minX)
        let h = max(1, maxY - minY)
        return CGRect(x: minX, y: minY, width: w, height: h)
    }

    private static func resolvedFont(family: String?, size: CGFloat, weight: CGFloat) -> NSFont {
        if let family, !family.isEmpty {
            let candidates = family.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
            for name in candidates where !name.isEmpty {
                if let font = NSFont(name: name, size: size) {
                    return font
                }
            }
        }
        let fontWeight: NSFont.Weight
        if weight >= 700 {
            fontWeight = .bold
        } else if weight >= 600 {
            fontWeight = .semibold
        } else if weight >= 500 {
            fontWeight = .medium
        } else {
            fontWeight = .regular
        }
        return NSFont.systemFont(ofSize: size, weight: fontWeight)
    }

    /// Distance along the path where the left edge of the laid-out string should begin.
    private static func textStartDistance(pathLen: CGFloat, totalWidth: CGFloat, textAnchor: String?, startOffset: String?) -> CGFloat {
        let anchor = (textAnchor ?? "start").lowercased()
        let alongPath = offsetAlongPath(pathLen: pathLen, textAnchor: anchor, startOffset: startOffset)
        let raw: CGFloat
        switch anchor {
        case "middle", "center":
            raw = alongPath - totalWidth / 2
        case "end":
            raw = alongPath - totalWidth
        default:
            raw = alongPath
        }
        return max(0, min(raw, max(0, pathLen - totalWidth)))
    }

    /// Point on the path that `text-anchor` / `startOffset` refer to (SVG `textPath` semantics).
    private static func offsetAlongPath(pathLen: CGFloat, textAnchor: String, startOffset: String?) -> CGFloat {
        let trimmed = startOffset?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            if trimmed.hasSuffix("%"), let p = Double(trimmed.dropLast()) {
                return CGFloat(p / 100) * pathLen
            }
            let numeric = trimmed
                .replacingOccurrences(of: "px", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let v = Double(numeric) {
                return CGFloat(v)
            }
        }
        // No usable startOffset: match common viewer behavior for anchor-only cases.
        if textAnchor == "middle" || textAnchor == "center" {
            return pathLen / 2
        }
        if textAnchor == "end" {
            return pathLen
        }
        return 0
    }
}
