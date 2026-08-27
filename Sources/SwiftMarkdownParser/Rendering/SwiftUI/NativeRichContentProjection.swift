import SwiftUI

/// Owns one-time host adaptation and readable native fallbacks for rich SwiftUI output.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
struct NativeRichContentProjection {
    enum Request {
        case image(node: AST.ImageNode, source: URL?)
        case mermaid(node: AST.MermaidDiagramNode, configuration: MermaidConfiguration)
        case mathBlock(AST.MathBlockNode)
        case inlineMath(AST.InlineMathNode)
        case htmlBlock(AST.HTMLBlockNode)
        case htmlInline(AST.HTMLInlineNode)
    }

    private let adapter: SwiftUIRichContentAdapter?
    private let style: SwiftUIStyleConfiguration
    private let adaptivePresentation: NativeAdaptivePresentation

    init(options: SwiftUIRenderOptions, adaptivePresentation: NativeAdaptivePresentation) {
        self.adapter = options.richContentAdapter
        self.style = options.styleConfiguration
        self.adaptivePresentation = adaptivePresentation
    }

    /// Invokes the host adapter at most once, then materializes a readable fallback if declined.
    func project(_ request: Request) -> AnyView {
        if let adapterRequest = adapterRequest(for: request),
           let adapted = adapter?.render(adapterRequest) {
            return adapted
        }
        return fallback(for: request)
    }

    private func adapterRequest(for request: Request) -> SwiftUIRichContentRequest? {
        switch request {
        case let .image(node, source):
            guard let source else { return nil }
            return .image(node: node, source: source)
        case let .mermaid(node, configuration):
            return .mermaid(node: node, configuration: configuration)
        case let .mathBlock(node):
            return .mathBlock(node)
        case let .inlineMath(node):
            return .inlineMath(node)
        case let .htmlBlock(node):
            return .htmlBlock(node)
        case let .htmlInline(node):
            return .htmlInline(node)
        }
    }

    private func fallback(for request: Request) -> AnyView {
        switch request {
        case let .image(node, source):
            return imageFallback(node: node, source: source)
        case let .mermaid(node, _):
            return adaptivePresentation.present(.mermaidFallback(
                diagramType: node.diagramType,
                source: node.content
            ))
        case let .mathBlock(node):
            return mathBlockFallback(node)
        case let .inlineMath(node):
            return inlineSourceFallback(
                source: node.content,
                accessibilityLabel: "Math: \(node.content)"
            )
        case let .htmlBlock(node):
            return blockSourceFallback(
                source: node.content,
                accessibilityLabel: "HTML content"
            )
        case let .htmlInline(node):
            return inlineSourceFallback(
                source: node.content,
                accessibilityLabel: "HTML: \(node.content)"
            )
        }
    }

    private func imageFallback(node: AST.ImageNode, source: URL?) -> AnyView {
        guard let source else {
            return AnyView(
                Text(node.altText)
                    .accessibilityLabel(node.altText)
            )
        }

        return AnyView(
            AsyncImage(url: source) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(height: style.imagePlaceholderHeight)
                        .accessibilityLabel("Loading image: \(node.altText)")
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: style.imageMaxWidth)
                        .clipShape(.rect(cornerRadius: style.imageCornerRadius))
                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(node.altText)
                    }
                    .frame(maxWidth: style.imageMaxWidth)
                    .frame(minHeight: style.imagePlaceholderHeight)
                @unknown default:
                    Text(node.altText)
                }
            }
            .accessibilityLabel(node.altText)
            .accessibilityAddTraits(.isImage)
        )
    }

    private func mathBlockFallback(_ node: AST.MathBlockNode) -> AnyView {
        AnyView(
            ScrollView(.horizontal, showsIndicators: true) {
                Text(node.content)
                    .font(style.codeFont)
                    .foregroundStyle(style.codeTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(style.codeBlockPadding)
            }
            .background(style.codeBackgroundColor)
            .clipShape(.rect(cornerRadius: style.codeCornerRadius))
            .accessibilityLabel("Math expression")
            .accessibilityValue(node.content)
            .accessibilityAddTraits(.isStaticText)
        )
    }

    private func inlineSourceFallback(source: String, accessibilityLabel: String) -> AnyView {
        AnyView(
            Text(source)
                .font(style.codeFont)
                .foregroundStyle(style.codeTextColor)
                .padding(.horizontal, style.codeSpanPadding)
                .background(style.codeBackgroundColor)
                .compositingGroup()
                .clipShape(.rect(cornerRadius: style.codeCornerRadius))
                .accessibilityLabel(accessibilityLabel)
                .accessibilityAddTraits(.isStaticText)
        )
    }

    private func blockSourceFallback(source: String, accessibilityLabel: String) -> AnyView {
        AnyView(
            Text(source)
                .font(style.codeFont)
                .foregroundStyle(style.codeTextColor)
                .padding(style.codeBlockPadding)
                .background(style.codeBackgroundColor)
                .compositingGroup()
                .clipShape(.rect(cornerRadius: style.codeCornerRadius))
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(source)
                .accessibilityAddTraits(.isStaticText)
        )
    }
}
