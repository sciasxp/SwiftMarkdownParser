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
    private let codeStyle: NativePresentationStyle.CodeBlock
    private let imageStyle: NativePresentationStyle.Image
    private let adaptivePresentation: NativeAdaptivePresentation
    private let semantics: NativePresentationSemantics
    private let materializer: NativeViewMaterializer

    init(
        options: SwiftUIRenderOptions,
        style: NativePresentationStyle,
        adaptivePresentation: NativeAdaptivePresentation,
        semantics: NativePresentationSemantics,
        materializer: NativeViewMaterializer
    ) {
        self.adapter = options.richContentAdapter
        self.baseURL = options.baseURL
        self.codeStyle = style.codeBlock
        self.imageStyle = style.image
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
        guard let source = MarkdownDestination.resolve(node.url, relativeTo: baseURL) else {
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
                        .frame(height: imageStyle.placeholderHeight)
                        .accessibilityLabel(Text(semantics.localized(
                            .loadingImage(alternativeText: node.altText)
                        )))
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: imageStyle.maximumWidth)
                        .clipShape(.rect(cornerRadius: imageStyle.cornerRadius))
                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(node.altText)
                    }
                    .frame(maxWidth: imageStyle.maximumWidth)
                    .frame(minHeight: imageStyle.placeholderHeight)
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
                    .font(codeStyle.font)
                    .foregroundStyle(codeStyle.textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(codeStyle.blockPadding)
            }
            .background(codeStyle.backgroundColor)
            .clipShape(.rect(cornerRadius: codeStyle.cornerRadius))
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
                .font(codeStyle.font)
                .foregroundStyle(codeStyle.textColor)
                .padding(.horizontal, codeStyle.spanPadding)
                .background(codeStyle.backgroundColor)
                .compositingGroup()
                .clipShape(.rect(cornerRadius: codeStyle.cornerRadius))
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
                .font(codeStyle.font)
                .foregroundStyle(codeStyle.textColor)
                .padding(codeStyle.blockPadding)
                .background(codeStyle.backgroundColor)
                .compositingGroup()
                .clipShape(.rect(cornerRadius: codeStyle.cornerRadius))
                .accessibilityLabel(Text(accessibilityLabel))
                .accessibilityValue(source)
                .accessibilityAddTraits(.isStaticText)
        )
    }
}
