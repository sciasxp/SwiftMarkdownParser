import Foundation

/// Output-specific semantic decisions shared by native SwiftUI views.
enum SwiftUIRenderSemantics {
    struct InlineStyle: OptionSet, Equatable, Sendable {
        let rawValue: UInt8

        static let emphasis = Self(rawValue: 1 << 0)
        static let strong = Self(rawValue: 1 << 1)
        static let code = Self(rawValue: 1 << 2)
        static let strikethrough = Self(rawValue: 1 << 3)
        static let footnote = Self(rawValue: 1 << 4)
    }

    struct InlineRun: Equatable, Sendable {
        let text: String
        let styles: InlineStyle
        let link: URL?
    }

    struct CodeRun: Equatable, Sendable {
        let text: String
        let tokenType: SyntaxTokenType?
    }

    static func orderedListMarker(startNumber: Int?, index: Int) -> String {
        let start = startNumber ?? 1
        return "\(start + index)."
    }

    static func resolvedURL(for destination: String, relativeTo baseURL: URL?) -> URL? {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        guard !trimmed.isEmpty,
              !lowercased.hasPrefix("javascript:"),
              !lowercased.hasPrefix("data:") else {
            return nil
        }

        if let baseURL {
            return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
        }
        return URL(string: trimmed)
    }

    /// Projects inline AST nodes into wrapping text runs while preserving semantic styling and links.
    static func inlineRuns(
        for nodes: [any ASTNode],
        relativeTo baseURL: URL?
    ) -> [InlineRun]? {
        var runs: [InlineRun] = []
        guard append(nodes, styles: [], link: nil, baseURL: baseURL, to: &runs) else {
            return nil
        }
        return coalesced(runs)
    }

    /// Fills the gaps between semantic tokens so the rendered text exactly matches the source.
    static func codeRuns(source: String, tokens: [SyntaxToken]) -> [CodeRun] {
        var result: [CodeRun] = []
        var cursor = source.startIndex

        for token in tokens {
            if cursor < token.range.lowerBound {
                result.append(CodeRun(text: String(source[cursor..<token.range.lowerBound]), tokenType: nil))
            }
            result.append(CodeRun(text: token.content, tokenType: token.tokenType))
            cursor = token.range.upperBound
        }

        if cursor < source.endIndex {
            result.append(CodeRun(text: String(source[cursor...]), tokenType: nil))
        }

        return result
    }

    static func plainText(for nodes: [any ASTNode]) -> String {
        nodes.flatMap { root in
            root.depthFirst().compactMap { visit in
                switch visit.node {
                case let text as AST.TextNode:
                    return text.content
                case let code as AST.CodeSpanNode:
                    return code.content
                case let autolink as AST.AutolinkNode:
                    return autolink.text
                case let image as AST.ImageNode:
                    return image.altText
                case let html as AST.HTMLInlineNode:
                    return html.content
                case let math as AST.InlineMathNode:
                    return math.content
                case let footnote as AST.FootnoteReferenceNode:
                    return "[\(footnote.identifier)]"
                default:
                    return nil
                }
            }
        }.joined()
    }

    private static func append(
        _ nodes: [any ASTNode],
        styles: InlineStyle,
        link: URL?,
        baseURL: URL?,
        to runs: inout [InlineRun]
    ) -> Bool {
        for node in nodes {
            switch node {
            case let text as AST.TextNode:
                runs.append(InlineRun(text: text.content, styles: styles, link: link))
            case let code as AST.CodeSpanNode:
                runs.append(InlineRun(text: code.content, styles: styles.union(.code), link: link))
            case let math as AST.InlineMathNode:
                runs.append(InlineRun(text: math.content, styles: styles.union(.code), link: link))
            case _ as AST.SoftBreakNode:
                runs.append(InlineRun(text: " ", styles: styles, link: link))
            case _ as AST.LineBreakNode:
                runs.append(InlineRun(text: "\n", styles: styles, link: link))
            case let html as AST.HTMLInlineNode:
                runs.append(InlineRun(text: html.content, styles: styles.union(.code), link: link))
            case let footnote as AST.FootnoteReferenceNode:
                runs.append(InlineRun(text: "[\(footnote.identifier)]", styles: styles.union(.footnote), link: link))
            case let emphasis as AST.EmphasisNode:
                guard append(emphasis.children, styles: styles.union(.emphasis), link: link, baseURL: baseURL, to: &runs) else { return false }
            case let strong as AST.StrongEmphasisNode:
                guard append(strong.children, styles: styles.union(.strong), link: link, baseURL: baseURL, to: &runs) else { return false }
            case let strikethrough as AST.StrikethroughNode:
                guard append(strikethrough.children, styles: styles.union(.strikethrough), link: link, baseURL: baseURL, to: &runs) else { return false }
            case let linkNode as AST.LinkNode:
                guard let destination = resolvedURL(for: linkNode.url, relativeTo: baseURL),
                      append(linkNode.children, styles: styles, link: destination, baseURL: baseURL, to: &runs) else {
                    return false
                }
            case let autolink as AST.AutolinkNode:
                guard let destination = resolvedURL(for: autolink.url, relativeTo: baseURL) else { return false }
                runs.append(InlineRun(text: autolink.text, styles: styles, link: destination))
            default:
                return false
            }
        }
        return true
    }

    private static func coalesced(_ runs: [InlineRun]) -> [InlineRun] {
        runs.reduce(into: []) { result, run in
            guard !run.text.isEmpty else { return }
            if let last = result.last, last.styles == run.styles, last.link == run.link {
                result[result.count - 1] = InlineRun(text: last.text + run.text, styles: last.styles, link: last.link)
            } else {
                result.append(run)
            }
        }
    }
}
