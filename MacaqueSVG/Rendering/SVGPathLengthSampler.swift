import CoreGraphics
import Foundation
import SwiftUI

/// Flattens a SwiftUI `Path` into a polyline with cumulative arc length for text-on-path placement.
enum SVGPathLengthSampler {
    struct Sample {
        var point: CGPoint
        var distance: CGFloat
        var angle: CGFloat
    }

    static func samples(from path: Path, curveSteps: Int = 12) -> [Sample] {
        var samples: [Sample] = []
        var lastPoint = CGPoint.zero
        var cumulative: CGFloat = 0

        func appendPoint(_ p: CGPoint) {
            let angle: CGFloat
            if let prev = samples.last {
                let dx = p.x - prev.point.x
                let dy = p.y - prev.point.y
                let seg = hypot(dx, dy)
                if seg > 0.0001 {
                    cumulative += seg
                    angle = atan2(dy, dx)
                } else {
                    angle = prev.angle
                }
            } else {
                angle = 0
            }
            samples.append(Sample(point: p, distance: cumulative, angle: angle))
        }

        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }

        func subdivideQuad(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint) {
            let steps = max(2, curveSteps)
            for step in 1 ... steps {
                let t = CGFloat(step) / CGFloat(steps)
                let q = lerp(lerp(p0, c, t), lerp(c, p1, t), t)
                appendPoint(q)
            }
        }

        func subdivideCubic(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint) {
            let steps = max(2, curveSteps)
            for step in 1 ... steps {
                let t = CGFloat(step) / CGFloat(steps)
                let u = 1 - t
                let x = u * u * u * p0.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p1.x
                let y = u * u * u * p0.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p1.y
                appendPoint(CGPoint(x: x, y: y))
            }
        }

        path.forEach { element in
            switch element {
            case .move(to: let p):
                lastPoint = p
                if samples.isEmpty {
                    appendPoint(p)
                } else {
                    samples.append(Sample(point: p, distance: cumulative, angle: samples.last!.angle))
                }

            case .line(to: let p):
                appendPoint(p)
                lastPoint = p

            case .quadCurve(to: let p1, control: let c):
                subdivideQuad(lastPoint, c, p1)
                lastPoint = p1

            case .curve(to: let p1, control1: let c1, control2: let c2):
                subdivideCubic(lastPoint, c1, c2, p1)
                lastPoint = p1

            case .closeSubpath:
                if let first = samples.first?.point, hypot(first.x - lastPoint.x, first.y - lastPoint.y) > 0.0001 {
                    appendPoint(first)
                    lastPoint = first
                }
            }
        }

        return samples
    }

    static func pointAndAngle(samples: [Sample], atDistance target: CGFloat) -> (CGPoint, CGFloat)? {
        guard let last = samples.last else { return nil }
        let clamped = min(max(target, 0), last.distance)
        guard let idx = samples.firstIndex(where: { $0.distance >= clamped }) else {
            return (last.point, last.angle)
        }
        if idx == 0 {
            return (samples[0].point, samples[0].angle)
        }
        let prev = samples[idx - 1]
        let cur = samples[idx]
        let span = cur.distance - prev.distance
        if span < 0.0001 {
            return (cur.point, cur.angle)
        }
        let t = (clamped - prev.distance) / span
        let x = prev.point.x + (cur.point.x - prev.point.x) * t
        let y = prev.point.y + (cur.point.y - prev.point.y) * t
        let ang = atan2(cur.point.y - prev.point.y, cur.point.x - prev.point.x)
        return (CGPoint(x: x, y: y), ang)
    }
}
