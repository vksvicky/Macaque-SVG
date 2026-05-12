# Macaque SVG

A dedicated, native macOS application for parsing, rendering, and interactively editing Scalable Vector Graphics (SVG). 

Built entirely with Swift 5.9 and SwiftUI for macOS 14.0+ (Sonoma).

## Project Architecture

Macaque SVG is designed with a strict separation of concerns, heavily inspired by modern software architecture principles:

1. **Data Model Layer (`SVGNode`)**: A robust, strongly-typed Document Object Model representing SVG elements in memory (Paths, Rectangles, Groups, etc.).
2. **Rendering Layer**: A high-performance conversion engine that translates the Data Model into native Apple primitives (`SwiftUI.Path`, `CoreGraphics`).
3. **Interactive Canvas**: The workspace that handles infinite panning, zooming, and hit-testing (coordinate math mapping screen space to document space).
4. **Editor UI**: The native SwiftUI chrome surrounding the canvas, including toolbars, property inspectors, and layer hierarchies.

## Development

This project uses **XcodeGen** to generate its `.xcodeproj` file. 

To set up the project locally:
1. Ensure you have XcodeGen installed (`brew install xcodegen`)
2. Run `xcodegen` in the root directory.
3. Open the newly generated `MacaqueSVG.xcodeproj` in Xcode.

## Implementation Phases

### Phase 1: Core Data Model & Parsing (Complete)
* `SVGNode` protocol and 15+ concrete element types (rect, circle, path, group, text, image, etc.)
* XML parser with CSS stylesheet, inline styles, gradient definitions, and mask/clip-path support

### Phase 2: Native Rendering Engine (Complete)
* `SVGSceneRenderer` with fill, stroke, gradients, opacity, transforms, and embedded images
* WebKit-based preview for pixel-perfect rendering including `<textPath>` and CSS

### Phase 3: Interactive Canvas (Complete)
* Pan (drag), zoom (trackpad pinch, Cmd+/Cmd-), and hit-testing
* Selection overlay with bounding box and resize handles
* Coordinate mapping between screen space and SVG document space

### Phase 4: Editor Tools & UI (Complete)
* **Properties Inspector** with live-editing of geometry, style, and transform properties
* **Layer List** with hierarchical DOM tree, visibility toggles, and selection sync
* **Tool Architecture** with Select (V) and Move (M) tools
* Element visibility system integrated with renderer and hit-tester
