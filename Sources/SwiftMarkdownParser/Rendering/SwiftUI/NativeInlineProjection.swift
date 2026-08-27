import Foundation
import SwiftUI

/// Owns the interpretation and native materialization of inline Markdown for SwiftUI output.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
struct NativeInlineProjection {
    private let baseURL: URL?
    private let style: SwiftUIStyleConfiguration
    private let richContentProjection: NativeRichContentProjection
    private let materializer: NativeViewMaterializer

    init(
        options: SwiftUIRenderOptions,
        richContentProjection: NativeRichContentProjection,
        materializer: NativeViewMaterializer
    ) {
        self.baseURL = options.baseURL
        self.style = options.styleConfiguration
        self.richContentProjection = richContentProjection
        self.materializer = materializer
    }

    /// Validates the complete inline tree before invoking any host adapter.
    func project(_ nodes: [any ASTNode]) throws -> NativeInlineContent {
        let plan = try NativeInlinePlan(nodes: nodes, baseURL: baseURL)
        let storage = materialize(plan.fragments)
        return NativeInlineContent(
            id: materializer.identity(),
            storage: storage,
            accessibilityText: plan.accessibilityText,
            lineSpacing: max(0, style.lineBreakSpacing)
        )
    }

    private func materialize(_ fragments: [NativeInlinePlan.Fragment]) -> NativeInlineContent.Storage {
        if fragments.allSatisfy(\.isText) {
            return .text(combinedText(from: fragments))
        }

        var materialized: [NativeInlineContent.Fragment] = []
        for fragment in fragments {
            switch fragment {
            case let .text(value, styles, link):
                materialized.append(contentsOf: mixedTextFragments(value, styles: styles, link: link))
            case .lineBreak:
                materialized.append(NativeInlineContent.Fragment(
                    content: materializer.materialize(
                        Text(verbatim: " ").hidden().frame(width: 0)
                    ),
                    startsNewLine: true
                ))
            case let .image(node, source, styles, link):
                let image = richContentProjection.project(.image(node: node, source: source))
                materialized.append(NativeInlineContent.Fragment(
                    content: styled(image, styles: styles, link: link),
                    startsNewLine: false
                ))
            case let .inlineMath(node, styles, link):
                let content = richContentProjection.project(.inlineMath(node))
                materialized.append(NativeInlineContent.Fragment(
                    content: styled(content, styles: styles, link: link),
                    startsNewLine: false
                ))
            case let .htmlInline(node, styles, link):
                let content = richContentProjection.project(.htmlInline(node))
                materialized.append(NativeInlineContent.Fragment(
                    content: styled(content, styles: styles, link: link),
                    startsNewLine: false
                ))
            }
        }
        return .mixed(materialized)
    }

    private func combinedText(from fragments: [NativeInlinePlan.Fragment]) -> Text {
        fragments.reduce(Text(verbatim: "")) { result, fragment in
            switch fragment {
            case let .text(value, styles, link):
                return result + styledText(value, styles: styles, link: link)
            case .lineBreak:
                return result + Text(verbatim: "\n")
            case .image, .inlineMath, .htmlInline:
                preconditionFailure("Rich fragments cannot be materialized as one Text")
            }
        }
    }

    private func mixedTextFragments(
        _ value: String,
        styles: NativeInlinePlan.Styles,
        link: URL?
    ) -> [NativeInlineContent.Fragment] {
        NativeInlineTextPieces(value).values.map { piece in
            NativeInlineContent.Fragment(
                content: materializer.materialize(styledText(piece, styles: styles, link: link)),
                startsNewLine: false
            )
        }
    }

    private func styledText(
        _ value: String,
        styles: NativeInlinePlan.Styles,
        link: URL?
    ) -> Text {
        var attributed = AttributedString(value)
        attributed.link = link
        var text = Text(attributed)

        if styles.contains(.emphasis) {
            text = text.italic()
        }
        if styles.contains(.strong) {
            text = text.fontWeight(.bold)
        }
        if styles.contains(.code) {
            text = text
                .font(style.codeFont)
                .foregroundStyle(style.codeTextColor)
        }
        if styles.contains(.strikethrough) {
            text = text
                .strikethrough()
                .foregroundStyle(style.strikethroughColor)
        }
        if styles.contains(.footnote) {
            text = text
                .font(.footnote)
                .baselineOffset(4)
        }
        if link != nil {
            text = text
                .foregroundStyle(style.linkColor)
                .underline()
        }
        return text
    }

    private func styled(
        _ view: NativeMaterializedView,
        styles: NativeInlinePlan.Styles,
        link: URL?
    ) -> NativeMaterializedView {
        var result = view
        if styles.contains(.emphasis) {
            result = materializer.transform(result) { $0.italic() }
        }
        if styles.contains(.strong) {
            result = materializer.transform(result) { $0.fontWeight(.bold) }
        }
        if styles.contains(.code) {
            result = materializer.transform(result) {
                $0.font(style.codeFont).foregroundStyle(style.codeTextColor)
            }
        }
        if styles.contains(.strikethrough) {
            result = materializer.transform(result) {
                $0.strikethrough().foregroundStyle(style.strikethroughColor)
            }
        }
        if styles.contains(.footnote) {
            result = materializer.transform(result) { $0.font(.footnote).baselineOffset(4) }
        }

        guard let link else { return result }
        return materializer.transform(result) { content in
            Link(destination: link) { content }
                .buttonStyle(.plain)
                .foregroundStyle(style.linkColor)
                .underline()
                .accessibilityAddTraits(.isLink)
        }
    }

}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
struct NativeInlineContent: Identifiable, View {
    fileprivate enum Storage {
        case text(Text)
        case mixed([Fragment])
    }

    fileprivate struct Fragment: Identifiable {
        let content: NativeMaterializedView
        let startsNewLine: Bool

        var id: NativeViewIdentity { content.id }
    }

    let id: NativeViewIdentity
    fileprivate let storage: Storage
    let accessibilityText: String
    fileprivate let lineSpacing: CGFloat

    var body: some View {
        switch storage {
        case let .text(text):
            text.lineSpacing(lineSpacing)
        case let .mixed(fragments):
            NativeInlineFlowLayout(spacing: lineSpacing) {
                ForEach(fragments) { fragment in
                    fragment.content
                        .layoutValue(key: NativeInlineLineBreakKey.self, value: fragment.startsNewLine)
                }
            }
        }
    }
}

private struct NativeInlinePlan {
    struct Styles: OptionSet, Equatable, Sendable {
        let rawValue: UInt8

        static let emphasis = Self(rawValue: 1 << 0)
        static let strong = Self(rawValue: 1 << 1)
        static let code = Self(rawValue: 1 << 2)
        static let strikethrough = Self(rawValue: 1 << 3)
        static let footnote = Self(rawValue: 1 << 4)
    }

    enum Fragment {
        case text(String, styles: Styles, link: URL?)
        case lineBreak
        case image(AST.ImageNode, source: URL?, styles: Styles, link: URL?)
        case inlineMath(AST.InlineMathNode, styles: Styles, link: URL?)
        case htmlInline(AST.HTMLInlineNode, styles: Styles, link: URL?)

        var isText: Bool {
            switch self {
            case .text, .lineBreak:
                true
            case .image, .inlineMath, .htmlInline:
                false
            }
        }
    }

    private(set) var fragments: [Fragment] = []
    private(set) var accessibilityText = ""
    private let baseURL: URL?

    init(nodes: [any ASTNode], baseURL: URL?) throws {
        self.baseURL = baseURL
        try append(nodes, styles: [], link: nil)
    }

    private mutating func append(
        _ nodes: [any ASTNode],
        styles: Styles,
        link: URL?
    ) throws {
        for node in nodes {
            switch node {
            case let text as AST.TextNode:
                appendText(text.content, styles: styles, link: link)
            case let emphasis as AST.EmphasisNode:
                try append(emphasis.children, styles: styles.union(.emphasis), link: link)
            case let strong as AST.StrongEmphasisNode:
                try append(strong.children, styles: styles.union(.strong), link: link)
            case let code as AST.CodeSpanNode:
                appendText(code.content, styles: styles.union(.code), link: link)
            case let strikethrough as AST.StrikethroughNode:
                try append(strikethrough.children, styles: styles.union(.strikethrough), link: link)
            case let linkNode as AST.LinkNode:
                try append(
                    linkNode.children,
                    styles: styles,
                    link: Self.resolvedURL(for: linkNode.url, relativeTo: baseURL)
                )
            case let autolink as AST.AutolinkNode:
                appendText(
                    autolink.text,
                    styles: styles,
                    link: Self.resolvedURL(for: autolink.url, relativeTo: baseURL)
                )
            case let image as AST.ImageNode:
                fragments.append(.image(
                    image,
                    source: Self.resolvedURL(for: image.url, relativeTo: baseURL),
                    styles: styles,
                    link: link
                ))
                accessibilityText += image.altText
            case let math as AST.InlineMathNode:
                fragments.append(.inlineMath(math, styles: styles, link: link))
                accessibilityText += math.content
            case let html as AST.HTMLInlineNode:
                fragments.append(.htmlInline(html, styles: styles, link: link))
                accessibilityText += html.content
            case let footnote as AST.FootnoteReferenceNode:
                appendText("[\(footnote.identifier)]", styles: styles.union(.footnote), link: link)
            case _ as AST.SoftBreakNode:
                appendText(" ", styles: styles, link: link)
            case _ as AST.LineBreakNode:
                fragments.append(.lineBreak)
                accessibilityText += "\n"
            default:
                throw SwiftUIRenderingError.unsupportedNodeType(node.nodeType)
            }
        }
    }

    private mutating func appendText(_ value: String, styles: Styles, link: URL?) {
        guard !value.isEmpty else { return }
        accessibilityText += value

        if case let .text(previous, previousStyles, previousLink) = fragments.last,
           previousStyles == styles,
           previousLink == link {
            fragments[fragments.count - 1] = .text(previous + value, styles: styles, link: link)
        } else {
            fragments.append(.text(value, styles: styles, link: link))
        }
    }

    private static func resolvedURL(for destination: String, relativeTo baseURL: URL?) -> URL? {
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
}

private struct NativeInlineTextPieces {
    let values: [String]

    init(_ text: String) {
        var values: [String] = []
        var current = ""
        var currentIsWhitespace: Bool?

        for character in text {
            let isWhitespace = character.isWhitespace
            if let currentIsWhitespace, currentIsWhitespace != isWhitespace {
                values.append(current)
                current = ""
            }
            current.append(character)
            currentIsWhitespace = isWhitespace
        }
        if !current.isEmpty {
            values.append(current)
        }
        self.values = values
    }
}

private struct NativeInlineLineBreakKey: LayoutValueKey {
    static let defaultValue = false
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeInlineFlowLayout: Layout {
    let spacing: CGFloat

    struct PlacedSubview {
        let index: Int
        let size: CGSize
        let x: CGFloat
        let baseline: CGFloat
    }

    struct Line {
        var items: [PlacedSubview] = []
        var width: CGFloat = 0
        var ascent: CGFloat = 0
        var descent: CGFloat = 0

        var height: CGFloat { ascent + descent }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let constrainedWidth = proposal.width.flatMap { width in
            width.isFinite ? max(0, width) : nil
        }
        let lines = lines(for: subviews, width: constrainedWidth)
        let contentWidth = lines.map(\.width).max() ?? 0
        let lineGaps = CGFloat(max(0, lines.count - 1))
        let contentHeight = lines.map(\.height).reduce(0, +) + spacing * lineGaps
        return CGSize(width: constrainedWidth ?? contentWidth, height: contentHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let lines = lines(for: subviews, width: bounds.width)
        var y = bounds.minY

        for line in lines {
            for item in line.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: y + line.ascent - item.baseline),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
            }
            y += line.height + spacing
        }
    }

    private func lines(for subviews: Subviews, width proposedWidth: CGFloat?) -> [Line] {
        let maximumWidth = proposedWidth.map { max(0, $0) } ?? .infinity
        var result: [Line] = []
        var line = Line()

        func finishLine() {
            if !line.items.isEmpty {
                result.append(line)
                line = Line()
            }
        }

        for index in subviews.indices {
            let subview = subviews[index]
            if subview[NativeInlineLineBreakKey.self] {
                let hadContent = !line.items.isEmpty
                finishLine()
                if !hadContent {
                    let size = subview.sizeThatFits(.unspecified)
                    let dimensions = subview.dimensions(in: ProposedViewSize(size))
                    let rawBaseline = dimensions[VerticalAlignment.firstTextBaseline]
                    let baseline = rawBaseline.isFinite ? min(max(0, rawBaseline), size.height) : size.height
                    line.items.append(PlacedSubview(index: index, size: size, x: 0, baseline: baseline))
                    line.ascent = baseline
                    line.descent = size.height - baseline
                    finishLine()
                }
                continue
            }

            var size = subview.sizeThatFits(.unspecified)
            if size.width > maximumWidth, maximumWidth.isFinite {
                size = subview.sizeThatFits(ProposedViewSize(width: maximumWidth, height: nil))
            }
            if !line.items.isEmpty, line.width + size.width > maximumWidth {
                finishLine()
            }

            let dimensions = subview.dimensions(in: ProposedViewSize(size))
            let rawBaseline = dimensions[VerticalAlignment.firstTextBaseline]
            let baseline = rawBaseline.isFinite ? min(max(0, rawBaseline), size.height) : size.height
            line.items.append(PlacedSubview(index: index, size: size, x: line.width, baseline: baseline))
            line.width += size.width
            line.ascent = max(line.ascent, baseline)
            line.descent = max(line.descent, size.height - baseline)
        }
        finishLine()
        return result
    }
}
