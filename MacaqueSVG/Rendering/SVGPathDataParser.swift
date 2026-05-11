import CoreGraphics
import Foundation
import SwiftUI

/// Parses an SVG `d` attribute into a SwiftUI `Path` (user space, +Y down).
enum SVGPathDataParser {
    static func path(from data: String) -> Path {
        var scanner = PathScanner(data)
        var path = Path()
        guard scanner.hasMore else { return path }

        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCubicControl: CGPoint?
        var lastQuadControl: CGPoint?

        var activeCommand: PathCommand?

        func nextCommand() -> PathCommand? {
            if let command = activeCommand {
                return command
            }
            guard let parsed = scanner.scanCommand() else { return nil }
            activeCommand = parsed
            return parsed
        }

        while scanner.hasMore {
            guard let command = nextCommand() else { break }

            switch command {
            case .moveAbsolute:
                guard let point = scanner.scanPoint() else { activeCommand = nil; continue }
                current = point
                subpathStart = current
                path.move(to: current)
                activeCommand = .lineAbsolute
                lastCubicControl = nil
                lastQuadControl = nil

            case .moveRelative:
                guard let point = scanner.scanPoint() else { activeCommand = nil; continue }
                current.x += point.x
                current.y += point.y
                subpathStart = current
                path.move(to: current)
                activeCommand = .lineRelative
                lastCubicControl = nil
                lastQuadControl = nil

            case .lineAbsolute:
                guard let point = scanner.scanPoint() else { activeCommand = nil; continue }
                current = point
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil

            case .lineRelative:
                guard let point = scanner.scanPoint() else { activeCommand = nil; continue }
                current.x += point.x
                current.y += point.y
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil

            case .horizontalAbsolute:
                guard let value = scanner.scanScalar() else { activeCommand = nil; continue }
                current.x = value
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil

            case .horizontalRelative:
                guard let delta = scanner.scanScalar() else { activeCommand = nil; continue }
                current.x += delta
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil

            case .verticalAbsolute:
                guard let value = scanner.scanScalar() else { activeCommand = nil; continue }
                current.y = value
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil

            case .verticalRelative:
                guard let delta = scanner.scanScalar() else { activeCommand = nil; continue }
                current.y += delta
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil

            case .closePath:
                path.closeSubpath()
                current = subpathStart
                activeCommand = nil
                lastCubicControl = nil
                lastQuadControl = nil

            case .cubicAbsolute:
                guard let c1 = scanner.scanPoint(), let c2 = scanner.scanPoint(), let end = scanner.scanPoint() else {
                    activeCommand = nil
                    continue
                }
                path.addCurve(to: end, control1: c1, control2: c2)
                lastCubicControl = c2
                current = end
                lastQuadControl = nil

            case .cubicRelative:
                guard let c1 = scanner.scanPoint(), let c2 = scanner.scanPoint(), let end = scanner.scanPoint() else {
                    activeCommand = nil
                    continue
                }
                let absC1 = CGPoint(x: current.x + c1.x, y: current.y + c1.y)
                let absC2 = CGPoint(x: current.x + c2.x, y: current.y + c2.y)
                let absEnd = CGPoint(x: current.x + end.x, y: current.y + end.y)
                path.addCurve(to: absEnd, control1: absC1, control2: absC2)
                lastCubicControl = absC2
                current = absEnd
                lastQuadControl = nil

            case .smoothCubicAbsolute:
                guard let c2 = scanner.scanPoint(), let end = scanner.scanPoint() else {
                    activeCommand = nil
                    continue
                }
                let c1: CGPoint
                if let previous = lastCubicControl {
                    c1 = CGPoint(x: 2 * current.x - previous.x, y: 2 * current.y - previous.y)
                } else {
                    c1 = current
                }
                path.addCurve(to: end, control1: c1, control2: c2)
                lastCubicControl = c2
                current = end
                lastQuadControl = nil

            case .smoothCubicRelative:
                guard let c2 = scanner.scanPoint(), let end = scanner.scanPoint() else {
                    activeCommand = nil
                    continue
                }
                let c1: CGPoint
                if let previous = lastCubicControl {
                    c1 = CGPoint(x: 2 * current.x - previous.x, y: 2 * current.y - previous.y)
                } else {
                    c1 = current
                }
                let absC2 = CGPoint(x: current.x + c2.x, y: current.y + c2.y)
                let absEnd = CGPoint(x: current.x + end.x, y: current.y + end.y)
                path.addCurve(to: absEnd, control1: c1, control2: absC2)
                lastCubicControl = absC2
                current = absEnd
                lastQuadControl = nil

            case .quadraticAbsolute:
                guard let c = scanner.scanPoint(), let end = scanner.scanPoint() else {
                    activeCommand = nil
                    continue
                }
                path.addQuadCurve(to: end, control: c)
                lastQuadControl = c
                lastCubicControl = nil
                current = end

            case .quadraticRelative:
                guard let c = scanner.scanPoint(), let end = scanner.scanPoint() else {
                    activeCommand = nil
                    continue
                }
                let absC = CGPoint(x: current.x + c.x, y: current.y + c.y)
                let absEnd = CGPoint(x: current.x + end.x, y: current.y + end.y)
                path.addQuadCurve(to: absEnd, control: absC)
                lastQuadControl = absC
                lastCubicControl = nil
                current = absEnd

            case .smoothQuadraticAbsolute:
                guard let end = scanner.scanPoint() else {
                    activeCommand = nil
                    continue
                }
                let c: CGPoint
                if let previous = lastQuadControl {
                    c = CGPoint(x: 2 * current.x - previous.x, y: 2 * current.y - previous.y)
                } else {
                    c = current
                }
                path.addQuadCurve(to: end, control: c)
                lastQuadControl = c
                lastCubicControl = nil
                current = end

            case .smoothQuadraticRelative:
                guard let end = scanner.scanPoint() else {
                    activeCommand = nil
                    continue
                }
                let c: CGPoint
                if let previous = lastQuadControl {
                    c = CGPoint(x: 2 * current.x - previous.x, y: 2 * current.y - previous.y)
                } else {
                    c = current
                }
                let absEnd = CGPoint(x: current.x + end.x, y: current.y + end.y)
                path.addQuadCurve(to: absEnd, control: c)
                lastQuadControl = c
                lastCubicControl = nil
                current = absEnd

            case .arcAbsolute:
                guard
                    let rx = scanner.scanScalar(),
                    let ry = scanner.scanScalar(),
                    let rotationDeg = scanner.scanScalar(),
                    let largeArc = scanner.scanFlag(),
                    let sweep = scanner.scanFlag(),
                    let end = scanner.scanPoint()
                else {
                    activeCommand = nil
                    continue
                }
                appendArc(
                    to: &path,
                    current: &current,
                    rx: rx,
                    ry: ry,
                    rotationDegrees: rotationDeg,
                    largeArc: largeArc,
                    sweep: sweep,
                    end: end
                )
                lastCubicControl = nil
                lastQuadControl = nil

            case .arcRelative:
                guard
                    let rx = scanner.scanScalar(),
                    let ry = scanner.scanScalar(),
                    let rotationDeg = scanner.scanScalar(),
                    let largeArc = scanner.scanFlag(),
                    let sweep = scanner.scanFlag(),
                    let delta = scanner.scanPoint()
                else {
                    activeCommand = nil
                    continue
                }
                let absEnd = CGPoint(x: current.x + delta.x, y: current.y + delta.y)
                appendArc(
                    to: &path,
                    current: &current,
                    rx: rx,
                    ry: ry,
                    rotationDegrees: rotationDeg,
                    largeArc: largeArc,
                    sweep: sweep,
                    end: absEnd
                )
                lastCubicControl = nil
                lastQuadControl = nil
            }

            if scanner.beginsNewCommand() {
                activeCommand = nil
            }
        }

        return path
    }

    private static func appendArc(
        to path: inout Path,
        current: inout CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        rotationDegrees: CGFloat,
        largeArc: Bool,
        sweep: Bool,
        end: CGPoint
    ) {
        guard rx != 0, ry != 0 else {
            path.addLine(to: end)
            current = end
            return
        }

        let x1 = current.x
        let y1 = current.y
        let x2 = end.x
        let y2 = end.y

        let phi = rotationDegrees * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        let dx = (x1 - x2) / 2
        let dy = (y1 - y2) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        var rxEff = abs(rx)
        var ryEff = abs(ry)
        let lambda = (x1p * x1p) / (rxEff * rxEff) + (y1p * y1p) / (ryEff * ryEff)
        if lambda > 1 {
            let scale = sqrt(lambda)
            rxEff *= scale
            ryEff *= scale
        }

        let sign: CGFloat = (largeArc == sweep) ? -1 : 1
        let rxSq = rxEff * rxEff
        let rySq = ryEff * ryEff
        let x1pSq = x1p * x1p
        let y1pSq = y1p * y1p

        let radicandNumerator = rxSq * rySq - rxSq * y1pSq - rySq * x1pSq
        let radicandDenominator = rxSq * y1pSq + rySq * x1pSq
        guard radicandDenominator != 0 else {
            path.addLine(to: end)
            current = end
            return
        }

        let radicand = max(radicandNumerator / radicandDenominator, 0)
        let coeff = sign * sqrt(radicand)
        let cxp = coeff * (rxEff * y1p) / ryEff
        let cyp = coeff * (-ryEff * x1p) / rxEff

        let cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2

        func vectorAngle(ux: CGFloat, uy: CGFloat, vx: CGFloat, vy: CGFloat, sweepPositive: Bool) -> CGFloat {
            let cross = ux * vy - uy * vx
            let dot = ux * vx + uy * vy
            var angle = atan2(cross, dot)
            if !sweepPositive, angle > 0 {
                angle -= 2 * .pi
            } else if sweepPositive, angle < 0 {
                angle += 2 * .pi
            }
            return angle
        }

        let ux = (x1p - cxp) / rxEff
        let uy = (y1p - cyp) / ryEff
        let vx = (-x1p - cxp) / rxEff
        let vy = (-y1p - cyp) / ryEff

        let theta1 = atan2(uy, ux)
        let delta = vectorAngle(ux: ux, uy: uy, vx: vx, vy: vy, sweepPositive: sweep)

        let segmentLimit = 12
        let segments = min(max(Int(ceil(abs(delta) / (.pi / 2))), 1), segmentLimit)
        for segment in 0..<segments {
            let t0 = theta1 + (CGFloat(segment) * delta) / CGFloat(segments)
            let t1 = theta1 + (CGFloat(segment + 1) * delta) / CGFloat(segments)
            let deltaT = t1 - t0
            let sinDt = sin(deltaT)
            let cosDt = cos(deltaT)
            let alpha = sinDt * (sqrt(max(0, 4 + 3 * pow(tan(deltaT / 2), 2))) - 1) / 3

            let cos0 = cos(t0)
            let sin0 = sin(t0)
            let cos1 = cos(t1)
            let sin1 = sin(t1)

            let ex0 = rxEff * cos0
            let ey0 = ryEff * sin0
            let ex1 = rxEff * cos1
            let ey1 = ryEff * sin1

            let q0x = cx + cosPhi * ex0 - sinPhi * ey0
            let q0y = cy + sinPhi * ex0 + cosPhi * ey0
            let q1x = cx + cosPhi * ex1 - sinPhi * ey1
            let q1y = cy + sinPhi * ex1 + cosPhi * ey1

            let m0x = -rxEff * sin0
            let m0y = ryEff * cos0
            let m1x = -rxEff * sin1
            let m1y = ryEff * cos1
            let tan0x = cosPhi * m0x - sinPhi * m0y
            let tan0y = sinPhi * m0x + cosPhi * m0y
            let tan1x = cosPhi * m1x - sinPhi * m1y
            let tan1y = sinPhi * m1x + cosPhi * m1y

            if !atan2(sinDt, cosDt).isFinite {
                continue
            }

            let c1 = CGPoint(x: q0x + alpha * tan0x, y: q0y + alpha * tan0y)
            let c2 = CGPoint(x: q1x - alpha * tan1x, y: q1y - alpha * tan1y)
            path.addCurve(to: CGPoint(x: q1x, y: q1y), control1: c1, control2: c2)
        }

        current = end
    }
}

// MARK: - Scanner

private enum PathCommand: Equatable {
    case moveAbsolute, moveRelative
    case lineAbsolute, lineRelative
    case horizontalAbsolute, horizontalRelative
    case verticalAbsolute, verticalRelative
    case closePath
    case cubicAbsolute, cubicRelative
    case smoothCubicAbsolute, smoothCubicRelative
    case quadraticAbsolute, quadraticRelative
    case smoothQuadraticAbsolute, smoothQuadraticRelative
    case arcAbsolute, arcRelative
}

private struct PathScanner {
    private let characters: [Character]
    private var position = 0

    init(_ string: String) {
        characters = Array(string)
    }

    var hasMore: Bool {
        var scanner = self
        scanner.skipSeparators()
        return scanner.position < scanner.characters.count
    }

    mutating func scanCommand() -> PathCommand? {
        skipSeparators()
        guard position < characters.count else { return nil }
        let character = characters[position]
        position += 1
        switch character {
        case "M": return .moveAbsolute
        case "m": return .moveRelative
        case "L": return .lineAbsolute
        case "l": return .lineRelative
        case "H": return .horizontalAbsolute
        case "h": return .horizontalRelative
        case "V": return .verticalAbsolute
        case "v": return .verticalRelative
        case "Z", "z": return .closePath
        case "C": return .cubicAbsolute
        case "c": return .cubicRelative
        case "S": return .smoothCubicAbsolute
        case "s": return .smoothCubicRelative
        case "Q": return .quadraticAbsolute
        case "q": return .quadraticRelative
        case "T": return .smoothQuadraticAbsolute
        case "t": return .smoothQuadraticRelative
        case "A": return .arcAbsolute
        case "a": return .arcRelative
        default:
            return nil
        }
    }

    mutating func scanPoint() -> CGPoint? {
        guard let x = scanScalar(), let y = scanScalar() else { return nil }
        return CGPoint(x: x, y: y)
    }

    mutating func scanFlag() -> Bool? {
        skipSeparators()
        guard position < characters.count else { return nil }
        let character = characters[position]
        switch character {
        case "0":
            position += 1
            return false
        case "1":
            position += 1
            return true
        default:
            guard let value = scanScalar() else { return nil }
            return value != 0
        }
    }

    mutating func scanScalar() -> CGFloat? {
        skipSeparators()
        guard position < characters.count else { return nil }

        let start = position
        if characters[position] == "-" || characters[position] == "+" {
            position += 1
        }

        var sawDigitOrDot = false
        while position < characters.count {
            let character = characters[position]
            if character.isNumber {
                sawDigitOrDot = true
                position += 1
            } else if character == "." {
                sawDigitOrDot = true
                position += 1
            } else if character == "e" || character == "E" {
                position += 1
                if position < characters.count, characters[position] == "+" || characters[position] == "-" {
                    position += 1
                }
                while position < characters.count, characters[position].isNumber {
                    position += 1
                }
                break
            } else {
                break
            }
        }

        guard sawDigitOrDot, start < position else {
            position = start
            return nil
        }

        let substring = String(characters[start..<position])
        guard let value = Double(substring) else {
            position = start
            return nil
        }
        return CGFloat(value)
    }

    mutating func skipSeparators() {
        while position < characters.count {
            let character = characters[position]
            if character.isWhitespace || character == "," {
                position += 1
            } else {
                break
            }
        }
    }

    func beginsNewCommand() -> Bool {
        var copy = self
        copy.skipSeparators()
        guard copy.position < characters.count else { return true }
        let character = characters[copy.position]
        return "MmZzLlHhVvCcSsQqTtAa".contains(character)
    }
}
