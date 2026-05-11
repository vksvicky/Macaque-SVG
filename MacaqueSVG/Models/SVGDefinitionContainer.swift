import Foundation

/// `<defs>` / `<symbol>` subtree: keeps children in the DOM for `id` lookup and `<use>`, but is not painted in the main scene.
final class SVGDefinitionContainer: SVGGroup {}
