import CoreGraphics
import Foundation

/// `preserveAspectRatio` `… meet` fitting (default `xMidYMid meet`).
enum SVGAspectRatioMeet {
    static func destinationRect(
        container: CGRect,
        intrinsicSize: CGSize,
        preserveAspectRatio: String?
    ) -> CGRect {
        guard intrinsicSize.width > 0, intrinsicSize.height > 0, container.width > 0, container.height > 0 else {
            return container
        }
        let raw = preserveAspectRatio?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            ?? "xmidymid meet"
        let tokens = raw.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let meet = !tokens.contains(where: { $0 == "slice" })
        let sx = container.width / intrinsicSize.width
        let sy = container.height / intrinsicSize.height
        let scale = meet ? min(sx, sy) : max(sx, sy)
        let w = intrinsicSize.width * scale
        let h = intrinsicSize.height * scale

        let alignX = tokens.first(where: { $0.hasPrefix("x") }) ?? "xmid"
        let alignY = tokens.first(where: { $0.hasPrefix("y") }) ?? "ymid"

        let ox: CGFloat
        if alignX.hasPrefix("xmin") {
            ox = container.minX
        } else if alignX.hasPrefix("xmax") {
            ox = container.maxX - w
        } else {
            ox = container.midX - w / 2
        }

        let oy: CGFloat
        if alignY.hasPrefix("ymin") {
            oy = container.minY
        } else if alignY.hasPrefix("ymax") {
            oy = container.maxY - h
        } else {
            oy = container.midY - h / 2
        }

        return CGRect(x: ox, y: oy, width: w, height: h)
    }
}
