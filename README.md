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

## Phase 1 Objectives
* Define the `SVGNode` protocol and base shape primitives.
* Implement a basic XML Parser to convert `.svg` strings into our Swift DOM.
