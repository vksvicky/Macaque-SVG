# Dedicated macOS SwiftUI SVG App: Implementation Plan

Based on the review of the three provided repositories, we can synthesize their core philosophies into a powerful, modern native macOS application using Swift and SwiftUI.

## 1. Key Learnings from Referenced Repositories

*   **[SVG.NET](https://github.com/svg-net/SVG) (The Data Model):** This C# library demonstrates the necessity of a robust, strongly-typed, hierarchical Document Object Model (DOM) to represent SVG elements (Paths, Rects, Groups, Transforms) in memory. Handling the XML parsing and serialization cleanly is foundational.
*   **[SVGKit](https://github.com/SVGKit/SVGKit) (The Rendering Engine):** This Objective-C library proves that mapping SVG elements directly to Apple's native rendering primitives yields high performance. While SVGKit uses `CoreAnimation` (`CAShapeLayer`), in a modern Swift environment, we can leverage SwiftUI's `Path`, `Canvas`, and `CoreGraphics` for hardware-accelerated drawing and natural hit-testing.
*   **[SVG-Edit](https://github.com/SVG-Edit/svgedit) (The Interactive Editor):** This web-based JS editor highlights the importance of decoupling the visual *Canvas* (handling drawing, panning, zooming, and interactions) from the *Editor UI* (menus, toolbars, property panels). It also provides a great reference for standard vector tool behaviors (selection, pen, shapes).

---

## 2. Proposed Architecture

We will build a reactive, native macOS application leveraging modern Apple frameworks.

*   **UI Layer (SwiftUI):** Handles all application chrome—toolbars, layer lists, inspector panels, and window management. SwiftUI's state management (`@Observable` / `@State`) will keep the UI in sync with the document.
*   **Rendering Layer (SwiftUI `Canvas` / CoreGraphics):** A high-performance view that consumes the data model and issues draw commands.
*   **Data Model Layer (Swift):** A hierarchical tree structure representing the SVG DOM. Elements will conform to an `SVGNode` protocol.
*   **Parsing/Serialization Layer:** An engine using Swift's `XMLParser` (or a lightweight DOM library) to seamlessly convert between `.svg` XML strings and our Swift objects.

---

## 3. Implementation Phases

### Phase 1: Core Data Model & Parsing (The "SVG.NET" Phase)
*   Define the core `SVGNode` protocol and base properties (id, transform, styles).
*   Create concrete structs/classes for primitives: `SVGDocument`, `SVGGroup`, `SVGPath`, `SVGRect`, `SVGCircle`, `SVGText`.
*   Implement an XML parser to read standard `.svg` files and generate the Swift DOM tree.
*   Implement a serializer to write the DOM back to standard, clean XML.

### Phase 2: The Native Rendering Engine (The "SVGKit" Phase)
*   Implement a rendering engine that recursively traverses the `SVGDocument` tree.
*   Map SVG path commands (M, L, C, Z) to native SwiftUI `Path` and `CGPath`.
*   Handle SVG attributes (fill, stroke, stroke-width, opacity) and apply them to the drawing context.
*   Create a base `SVGView` (SwiftUI component) that can render an `SVGDocument` accurately at any scale.

### Phase 3: The Interactive Canvas (The "SVG-Edit Canvas" Phase)
*   Wrap the `SVGView` in an interactive workspace that supports infinite panning and zooming (via `NSScrollView` or SwiftUI gesture recognizers).
*   Implement Coordinate Math: Convert window/mouse coordinates (App space) into the SVG's internal coordinate system (Document space).
*   Implement Hit-Testing: Determine which `SVGNode` the user clicked on.
*   Add a Selection Engine: Render bounding boxes and transform handles around selected nodes.

### Phase 4: Editor Tools & UI (The "SVG-Edit UI" Phase)
*   **Main Layout:** Build the classic layout with a Toolbar (Top), Tools Palette (Left), Canvas (Center), and Inspector/Layers (Right).
*   **Tool Architecture:** Implement a state machine for different tools: Selection/Move (V), Rectangle (R), Ellipse (E), Pen (P).
*   **Properties Inspector:** Build dynamic SwiftUI forms to edit the selected node's properties (Color pickers, X/Y numeric fields, stroke width).
*   **Layer List:** Create a hierarchical `OutlineView` or SwiftUI `List` to reorder, group, hide, or lock elements.

---

## 4. Technology Stack & Requirements
*   **Language:** Swift 5.9+
*   **UI Framework:** SwiftUI (for all UI and most rendering)
*   **Target OS:** macOS 14.0+ (Sonoma)
*   **App Architecture:** Document-Based App (`ReferenceFileDocument` or `FileDocument` to handle saving/opening natively).
