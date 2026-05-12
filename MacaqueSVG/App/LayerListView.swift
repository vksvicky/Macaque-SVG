import SwiftUI

struct LayerListView: View {
    let root: SVGRoot
    @Binding var selectedElement: SVGElement?
    @Binding var revisionCounter: Int

    var body: some View {
        List {
            ForEach(root.children, id: \.nodeID) { child in
                LayerRowView(
                    element: child,
                    selectedElement: $selectedElement,
                    revisionCounter: $revisionCounter
                )
            }
        }
        .listStyle(.sidebar)
    }
}

struct LayerRowView: View {
    let element: SVGElement
    @Binding var selectedElement: SVGElement?
    @Binding var revisionCounter: Int

    @State private var isExpanded: Bool = true

    init(element: SVGElement, selectedElement: Binding<SVGElement?>, revisionCounter: Binding<Int>) {
        self.element = element
        self._selectedElement = selectedElement
        self._revisionCounter = revisionCounter
        self._isExpanded = State(initialValue: !(element is SVGDefinitionContainer))
    }

    var body: some View {
        if let group = element as? SVGGroup, !group.children.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(group.children, id: \.nodeID) { child in
                    LayerRowView(
                        element: child,
                        selectedElement: $selectedElement,
                        revisionCounter: $revisionCounter
                    )
                }
            } label: {
                rowLabel
            }
        } else {
            rowLabel
        }
    }

    private var isSelected: Bool {
        selectedElement?.nodeID == element.nodeID
    }

    private var rowLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Group {
                if let svgId = element.svgId, !svgId.isEmpty {
                    Text(svgId)
                } else {
                    Text(typeName)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)

            Spacer()

            Button {
                element.isVisible.toggle()
                revisionCounter += 1
            } label: {
                Image(systemName: element.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(element.isVisible ? .secondary : .tertiary)
            }
            .buttonStyle(.plain)
            .help(element.isVisible ? "Hide" : "Show")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedElement = element
        }
        .listRowBackground(
            isSelected
                ? RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.2))
                : nil
        )
    }

    private var iconName: String {
        if !element.isVisible { return "eye.slash" }
        switch element {
        case is SVGDefinitionContainer: return "square.dashed"
        case is SVGMask: return "theatermasks"
        case is SVGNestedSVG: return "rectangle.on.rectangle"
        case is SVGTextPath: return "textformat"
        case is SVGTextBlock: return "textformat"
        case is SVGTSpanNode: return "textformat"
        case is SVGRoot: return "folder"
        case is SVGGroup: return "folder"
        case is SVGPath: return "scribble.variable"
        case is SVGRect: return "rectangle"
        case is SVGCircle: return "circle"
        case is SVGPolygon: return "pentagon"
        case is SVGPolyline: return "line.diagonal"
        case is SVGImage: return "photo"
        case is SVGUse: return "link"
        default: return "questionmark.square"
        }
    }

    private var typeName: String {
        switch element {
        case is SVGDefinitionContainer: return "defs"
        case is SVGMask: return "mask"
        case is SVGNestedSVG: return "svg"
        case is SVGTextPath: return "textPath"
        case is SVGTextBlock: return "text"
        case is SVGTSpanNode: return "tspan"
        case is SVGRoot: return "svg"
        case is SVGGroup: return "g"
        case is SVGPath: return "path"
        case is SVGRect: return "rect"
        case is SVGCircle: return "circle"
        case is SVGPolygon: return "polygon"
        case is SVGPolyline: return "polyline"
        case is SVGImage: return "image"
        case is SVGUse: return "use"
        default: return "element"
        }
    }
}
