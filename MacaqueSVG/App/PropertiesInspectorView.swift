import SwiftUI

struct PropertiesInspectorView: View {
    let element: SVGElement
    @Binding var revisionCounter: Int

    var body: some View {
        Form {
            Section {
                LabeledContent("Type", value: elementTypeName(element))
            }

            Section("Identity") {
                TextField("ID", text: Binding(
                    get: { element.svgId ?? "" },
                    set: { newValue in
                        element.svgId = newValue.isEmpty ? nil : newValue
                        revisionCounter += 1
                    }
                ))
            }

            geometrySection

            Section("Style") {
                TextField("Fill", text: styleStringBinding(\.fill))
                TextField("Stroke", text: styleStringBinding(\.stroke))
                numericField("Stroke Width", value: Binding(
                    get: { element.style.strokeWidth ?? 0 },
                    set: { newValue in
                        element.style.strokeWidth = newValue == 0 ? nil : newValue
                        revisionCounter += 1
                    }
                ))
                HStack {
                    Text("Opacity")
                    Slider(
                        value: Binding(
                            get: { element.style.opacity ?? 1.0 },
                            set: { newValue in
                                element.style.opacity = min(max(newValue, 0), 1)
                                revisionCounter += 1
                            }
                        ),
                        in: 0 ... 1
                    )
                    Text(String(format: "%.2f", element.style.opacity ?? 1.0))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Section("Transform") {
                numericField("Translate X", value: Binding(
                    get: { element.transform.tx },
                    set: { element.transform.tx = $0; revisionCounter += 1 }
                ))
                numericField("Translate Y", value: Binding(
                    get: { element.transform.ty },
                    set: { element.transform.ty = $0; revisionCounter += 1 }
                ))
                numericField("Scale X", value: Binding(
                    get: { element.transform.a },
                    set: { element.transform.a = $0; revisionCounter += 1 }
                ))
                numericField("Scale Y", value: Binding(
                    get: { element.transform.d },
                    set: { element.transform.d = $0; revisionCounter += 1 }
                ))
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var geometrySection: some View {
        Section("Geometry") {
            if let rect = element as? SVGRect {
                numericField("x", value: binding(for: rect, keyPath: \.x))
                numericField("y", value: binding(for: rect, keyPath: \.y))
                numericField("width", value: binding(for: rect, keyPath: \.width))
                numericField("height", value: binding(for: rect, keyPath: \.height))
                numericField("rx", value: optionalBinding(
                    get: { rect.rx },
                    set: { rect.rx = $0 }
                ))
                numericField("ry", value: optionalBinding(
                    get: { rect.ry },
                    set: { rect.ry = $0 }
                ))
            } else if let circle = element as? SVGCircle {
                numericField("cx", value: binding(for: circle, keyPath: \.cx))
                numericField("cy", value: binding(for: circle, keyPath: \.cy))
                numericField("r", value: binding(for: circle, keyPath: \.r))
            } else if let path = element as? SVGPath {
                LabeledContent("d") {
                    TextField("", text: .constant(path.d))
                        .disabled(true)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else if let polyline = element as? SVGPolyline {
                LabeledContent("Points", value: "\(polyline.points.count)")
            } else {
                Text("No editable geometry")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func numericField(_ label: String, value: Binding<CGFloat>) -> some View {
        LabeledContent(label) {
            TextField(
                "",
                value: value,
                formatter: cgFloatFormatter
            )
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
            .onSubmit { revisionCounter += 1 }
        }
    }

    private var cgFloatFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        return formatter
    }

    private func styleStringBinding(_ keyPath: WritableKeyPath<SVGStyle, String?>) -> Binding<String> {
        Binding(
            get: { element.style[keyPath: keyPath] ?? "" },
            set: { newValue in
                element.style[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
                revisionCounter += 1
            }
        )
    }

    private func binding<T: SVGElement>(
        for target: T,
        keyPath: ReferenceWritableKeyPath<T, CGFloat>
    ) -> Binding<CGFloat> {
        Binding(
            get: { target[keyPath: keyPath] },
            set: { newValue in
                target[keyPath: keyPath] = newValue
                revisionCounter += 1
            }
        )
    }

    /// Maps an optional CGFloat property to a non-optional binding (nil becomes 0, 0 sets nil).
    private func optionalBinding(get: @escaping () -> CGFloat?, set: @escaping (CGFloat?) -> Void) -> Binding<CGFloat> {
        Binding(
            get: { get() ?? 0 },
            set: { newValue in
                set(newValue == 0 ? nil : newValue)
                revisionCounter += 1
            }
        )
    }
}

private func elementTypeName(_ element: SVGElement) -> String {
    switch element {
    case is SVGRect: return "rect"
    case is SVGCircle: return "circle"
    case is SVGPath: return "path"
    case is SVGPolygon: return "polygon"
    case is SVGPolyline: return "polyline"
    case is SVGImage: return "image"
    case is SVGTextBlock: return "text"
    case is SVGRoot: return "svg"
    case is SVGGroup: return "g"
    default: return "element"
    }
}
