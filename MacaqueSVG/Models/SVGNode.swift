import CoreGraphics
import Foundation

protocol SVGNode: AnyObject, Identifiable {
    var nodeID: UUID { get }
    var svgId: String? { get set }
    /// Space-separated class tokens from the `class` attribute (for `<style>` rules).
    var svgClass: String? { get set }
    var transform: CGAffineTransform { get set }
    var style: SVGStyle { get set }
    var parent: SVGGroup? { get }
}

class SVGElement: SVGNode {
    let nodeID: UUID
    var svgId: String?
    var svgClass: String?
    var transform: CGAffineTransform
    var style: SVGStyle
    weak var parent: SVGGroup?

    init(
        svgId: String? = nil,
        svgClass: String? = nil,
        transform: CGAffineTransform = .identity,
        style: SVGStyle = SVGStyle()
    ) {
        nodeID = UUID()
        self.svgId = svgId
        self.svgClass = svgClass
        self.transform = transform
        self.style = style
    }
}

extension SVGNode {
    var id: UUID { nodeID }
}
