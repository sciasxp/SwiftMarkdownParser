import SwiftUI

/// Owns rich destination resolution, one-time host adaptation, and readable native fallbacks.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
struct NativeRichContentProjection {
    enum Request {
        case image(AST.ImageNode)
        case mermaid(node: AST.MermaidDiagramNode, configuration: MermaidConfiguration)
        case mathBlock(AST.MathBlockNode)
        case inlineMath(AST.InlineMathNode)
        case htmlBlock(AST.HTMLBlockNode)
        case htmlInline(AST.HTMLInlineNode)
    }

    private let adapter: SwiftUIRichContentAdapter?
    private let baseURL: URL?
    private let style: SwiftUIStyleConfiguration
    private let adaptivePresentation: NativeAdaptivePresentation
    private let semantics: NativePresentationSemantics
    private let materializer: NativeViewMaterializer

    init(
        options: SwiftUIRenderOptions,
        adaptivePresentation: NativeAdaptivePresentation,
        semantics: NativePresentationSemantics,
        materializer: NativeViewMaterializer
    ) {
        self.adapter = options.richContentAdapter
        self.baseURL = options.baseURL
        self.style = options.styleConfiguration
        self.adaptivePresentation = adaptivePresentation
        self.semantics = semantics
        self.materializer = materializer
    }

    /// Invokes the host adapter at most once, then materializes a readable fallback if declined.
    func project(_ request: Request) -> NativeMaterializedView {
        switch request {
        case let .image(node):
            return projectImage(node)
        case let .mermaid(node, configuration):
            return adaptOrFallback(.mermaid(node: node, configuration: configuration)) {
                adaptivePresentation.present(.mermaidFallback(
                    diagramType: node.diagramType,
                    source: node.content
                ))
            }
        case let .mathBlock(node):
            return adaptOrFallback(.mathBlock(node)) {
                mathBlockFallback(node)
            }
        case let .inlineMath(node):
            return adaptOrFallback(.inlineMath(node)) {
                inlineSourceFallback(
                    source: node.content,
                    accessibilityLabel: semantics.localized(.inlineMath(content: node.content))
                )
            }
        case let .htmlBlock(node):
            return adaptOrFallback(.htmlBlock(node)) {
                blockSourceFallback(
                    source: node.content,
                    accessibilityLabel: semantics.localized(.htmlBlock)
                )
            }
        case let .htmlInline(node):
            return adaptOrFallback(.htmlInline(node)) {
                inlineSourceFallback(
                    source: node.content,
                    accessibilityLabel: semantics.localized(.htmlInline(content: node.content))
                )
            }
        }
    }

    private func projectImage(_ node: AST.ImageNode) -> NativeMaterializedView {
        guard let source = resolvedImageURL(for: node.url) else {
            return imageFallback(node: node, source: nil)
        }

        return adaptOrFallback(.image(node: node, source: source)) {
            imageFallback(node: node, source: source)
        }
    }

    private func adaptOrFallback(
        _ request: SwiftUIRichContentRequest,
        fallback: () -> NativeMaterializedView
    ) -> NativeMaterializedView {
        guard let adapted = adapter?.render(request) else {
            return fallback()
        }
        return materializer.materialize(adapted)
    }

    private func resolvedImageURL(for destination: String) -> URL? {
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

    private func imageFallback(node: AST.ImageNode, source: URL?) -> NativeMaterializedView {
        guard let source else {
            return materializer.materialize(
                Text(node.altText)
                    .accessibilityLabel(node.altText)
            )
        }

        return materializer.materialize(
            AsyncImage(url: source) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(height: style.imagePlaceholderHeight)
                        .accessibilityLabel(Text(semantics.localized(
                            .loadingImage(alternativeText: node.altText)
                        )))
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

    private func mathBlockFallback(_ node: AST.MathBlockNode) -> NativeMaterializedView {
        materializer.materialize(
            ScrollView(.horizontal, showsIndicators: true) {
                Text(node.content)
                    .font(style.codeFont)
                    .foregroundStyle(style.codeTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(style.codeBlockPadding)
            }
            .background(style.codeBackgroundColor)
            .clipShape(.rect(cornerRadius: style.codeCornerRadius))
            .accessibilityLabel(Text(semantics.localized(.mathExpression)))
            .accessibilityValue(node.content)
            .accessibilityAddTraits(.isStaticText)
        )
    }

    private func inlineSourceFallback(
        source: String,
        accessibilityLabel: LocalizedStringResource
    ) -> NativeMaterializedView {
        materializer.materialize(
            Text(source)
                .font(style.codeFont)
                .foregroundStyle(style.codeTextColor)
                .padding(.horizontal, style.codeSpanPadding)
                .background(style.codeBackgroundColor)
                .compositingGroup()
                .clipShape(.rect(cornerRadius: style.codeCornerRadius))
                .accessibilityLabel(Text(accessibilityLabel))
                .accessibilityAddTraits(.isStaticText)
        )
    }

    private func blockSourceFallback(
        source: String,
        accessibilityLabel: LocalizedStringResource
    ) -> NativeMaterializedView {
        materializer.materialize(
            Text(source)
                .font(style.codeFont)
                .foregroundStyle(style.codeTextColor)
                .padding(style.codeBlockPadding)
                .background(style.codeBackgroundColor)
                .compositingGroup()
                .clipShape(.rect(cornerRadius: style.codeCornerRadius))
                .accessibilityLabel(Text(accessibilityLabel))
                .accessibilityValue(source)
                .accessibilityAddTraits(.isStaticText)
        )
    }
}
