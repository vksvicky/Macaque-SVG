import UniformTypeIdentifiers

extension UTType {
    /// Standard SVG content type for open/save and Finder integration.
    static var svgDocument: UTType {
        UTType(importedAs: "public.svg-image") ?? UTType(filenameExtension: "svg")!
    }

    /// Gzip-compressed SVG (`.svgz`); declared in `Info.plist` as `club.cycleruncode.macaque.svgz-image`.
    static var macaqueCompressedSVG: UTType {
        UTType(importedAs: "club.cycleruncode.macaque.svgz-image") ?? UTType(filenameExtension: "svgz")!
    }
}
