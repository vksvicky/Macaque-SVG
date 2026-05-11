import Foundation

/// Minimal CSS from `<style>` blocks: `.class { fill: ... }` and `#id { ... }`.
struct SVGStylesheet: Equatable {
    static let empty = SVGStylesheet()

    private struct Rule: Equatable {
        let selector: String
        let declarations: String
    }

    private var rules: [Rule] = []

    mutating func append(css text: String) {
        let stripped = Self.stripComments(text)
        let pattern = #"([.#][\w-]+)\s*\{([^}]*)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
        let range = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
        regex.enumerateMatches(in: stripped, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 3,
                  let selRange = Range(match.range(at: 1), in: stripped),
                  let bodyRange = Range(match.range(at: 2), in: stripped)
            else { return }
            let selector = String(stripped[selRange]).lowercased()
            let body = String(stripped[bodyRange])
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
            rules.append(Rule(selector: selector, declarations: body))
        }
    }

    func apply(to style: inout SVGStyle, classList: String?, elementId: String?) {
        let classes = classList?
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0).lowercased() }
            .filter { !$0.isEmpty } ?? []

        for rule in rules {
            if rule.selector.hasPrefix(".") {
                let name = String(rule.selector.dropFirst())
                guard classes.contains(name) else { continue }
                SVGInlineStyle.apply(rule.declarations, to: &style)
            } else if rule.selector.hasPrefix("#"), let elementId {
                let name = String(rule.selector.dropFirst())
                guard name == elementId.lowercased() else { continue }
                SVGInlineStyle.apply(rule.declarations, to: &style)
            }
        }
    }

    private static func stripComments(_ text: String) -> String {
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "/" && text.index(after: index) < text.endIndex, text[text.index(after: index)] == "*" {
                var cursor = text.index(index, offsetBy: 2)
                while cursor < text.endIndex {
                    if text[cursor] == "*", text.index(after: cursor) < text.endIndex, text[text.index(after: cursor)] == "/" {
                        cursor = text.index(after: text.index(after: cursor))
                        break
                    }
                    cursor = text.index(after: cursor)
                }
                index = cursor
                continue
            }
            result.append(text[index])
            index = text.index(after: index)
        }
        return result
    }
}
