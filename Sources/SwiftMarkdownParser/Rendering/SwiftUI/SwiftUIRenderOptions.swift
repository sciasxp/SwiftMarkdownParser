/// Options and styling for native SwiftUI output rendering.
///
/// This file provides the configuration and styling system for the SwiftUI renderer,
/// including fonts, colors, spacing, and behavior customization.

public import SwiftUI
public import Foundation

// MARK: - SwiftUIRenderOptions

/// One semantic request at the native rich-content seam.
@available(iOS 17.0, macOS 14.0, *)
public enum SwiftUIRichContentRequest: Sendable {
    /// A validated image destination. Unsafe or unresolved destinations never reach the adapter.
    case image(node: AST.ImageNode, source: URL)
    case mermaid(node: AST.MermaidDiagramNode, configuration: MermaidConfiguration)
    case mathBlock(AST.MathBlockNode)
    case inlineMath(AST.InlineMathNode)
    case htmlBlock(AST.HTMLBlockNode)
    case htmlInline(AST.HTMLInlineNode)
}

/// Host adapter for rich content that has no single faithful system SwiftUI primitive.
/// Returning `nil` declines a request and selects the renderer's readable native fallback.
@available(iOS 17.0, macOS 14.0, *)
public struct SwiftUIRichContentAdapter: Sendable {
    public typealias Renderer = @MainActor @Sendable (SwiftUIRichContentRequest) -> AnyView?

    private let renderer: Renderer

    public init(render: @escaping Renderer) {
        self.renderer = render
    }

    /// Materialize a request or return `nil` to use the native fallback.
    @MainActor
    public func render(_ request: SwiftUIRichContentRequest) -> AnyView? {
        renderer(request)
    }
}

/// Immutable options consumed by `SwiftUIRenderer`.
@available(iOS 17.0, macOS 14.0, *)
public struct SwiftUIRenderOptions: Sendable {
    /// Base URL for resolving relative links and images
    public let baseURL: URL?

    /// Style configuration for visual appearance
    public let styleConfiguration: SwiftUIStyleConfiguration

    /// Configuration for Mermaid diagram rendering
    public let mermaidConfiguration: MermaidConfiguration

    /// Optional semantic highlighting theme for supported fenced code languages.
    /// Unsupported or unlabelled blocks retain the configured plain-code appearance.
    public let syntaxHighlightingTheme: SyntaxHighlightingTheme?

    /// Optional host adapter for images, Mermaid, math, and raw HTML.
    public let richContentAdapter: SwiftUIRichContentAdapter?

    /// Link handler for tap actions
    public let linkHandler: (@Sendable (URL) -> Void)?

    public init(
        baseURL: URL? = nil,
        styleConfiguration: SwiftUIStyleConfiguration = SwiftUIStyleConfiguration(),
        mermaidConfiguration: MermaidConfiguration = .default,
        syntaxHighlightingTheme: SyntaxHighlightingTheme? = nil,
        richContentAdapter: SwiftUIRichContentAdapter? = nil,
        linkHandler: (@Sendable (URL) -> Void)? = nil
    ) {
        self.baseURL = baseURL
        self.styleConfiguration = styleConfiguration
        self.mermaidConfiguration = mermaidConfiguration
        self.syntaxHighlightingTheme = syntaxHighlightingTheme
        self.richContentAdapter = richContentAdapter
        self.linkHandler = linkHandler
    }
}

/// Errors raised at the native SwiftUI output seam.
public enum SwiftUIRenderingError: Error, LocalizedError, Sendable {
    case unsupportedNodeType(ASTNodeType)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedNodeType(type):
            return String(localized: NativePresentationSemantics().localized(
                .unsupportedNodeType(type.rawValue)
            ))
        }
    }
}

// MARK: - SwiftUIStyleConfiguration

/// Comprehensive style configuration for SwiftUI markdown rendering
@available(iOS 17.0, macOS 14.0, *)
public struct SwiftUIStyleConfiguration: Sendable {

    // MARK: - Typography

    /// Base body font
    public let bodyFont: Font

    /// Code font (monospace)
    public let codeFont: Font

    /// Heading fonts by level
    public let headingFonts: [Int: Font]

    /// Table header font
    public let tableHeaderFont: Font

    /// Table body font
    public let tableBodyFont: Font

    /// Task list checkbox font
    public let taskListCheckboxFont: Font

    // MARK: - Colors

    /// Primary text color
    public let textColor: Color

    /// Heading text color
    public let headingColor: Color

    /// Link color
    public let linkColor: Color

    /// Code text color
    public let codeTextColor: Color

    /// Code background color
    public let codeBackgroundColor: Color

    /// Block quote border color
    public let blockQuoteBorderColor: Color

    /// Block quote background color
    public let blockQuoteBackgroundColor: Color

    /// Thematic break color
    public let thematicBreakColor: Color

    /// List marker color
    public let listMarkerColor: Color

    /// Strikethrough text color
    public let strikethroughColor: Color

    /// Task list checked color
    public let taskListCheckedColor: Color

    /// Task list unchecked color
    public let taskListUncheckedColor: Color

    /// Table border color
    public let tableBorderColor: Color

    /// Table background color
    public let tableBackgroundColor: Color

    /// Table header background color
    public let tableHeaderBackgroundColor: Color

    /// Table cell background color
    public let tableCellBackgroundColor: Color

    /// Table header text color
    public let tableHeaderTextColor: Color

    /// Table body text color
    public let tableBodyTextColor: Color

    // MARK: - Spacing

    /// Document-level spacing between elements
    public let documentSpacing: CGFloat

    /// Paragraph bottom spacing
    public let paragraphSpacing: CGFloat

    /// Line break spacing
    public let lineBreakSpacing: CGFloat

    /// Block quote spacing
    public let blockQuoteSpacing: CGFloat

    /// Block quote content spacing
    public let blockQuoteContentSpacing: CGFloat

    /// Block quote padding
    public let blockQuotePadding: CGFloat

    /// Block quote vertical padding
    public let blockQuoteVerticalPadding: CGFloat

    /// Thematic break spacing
    public let thematicBreakSpacing: CGFloat

    /// List item spacing
    public let listItemSpacing: CGFloat

    /// List item content spacing
    public let listItemContentSpacing: CGFloat

    /// List marker spacing
    public let listMarkerSpacing: CGFloat

    /// List indentation
    public let listIndentation: CGFloat

    /// List marker width
    public let listMarkerWidth: CGFloat

    /// Code span padding
    public let codeSpanPadding: CGFloat

    /// Code block padding
    public let codeBlockPadding: CGFloat

    /// Task list spacing
    public let taskListSpacing: CGFloat

    /// Task list content spacing
    public let taskListContentSpacing: CGFloat

    /// Table cell padding
    public let tableCellPadding: CGFloat

    // MARK: - Dimensions

    /// Block quote border width
    public let blockQuoteBorderWidth: CGFloat

    /// Block quote corner radius
    public let blockQuoteCornerRadius: CGFloat

    /// Code corner radius
    public let codeCornerRadius: CGFloat

    /// Image maximum width
    public let imageMaxWidth: CGFloat

    /// Image corner radius
    public let imageCornerRadius: CGFloat

    /// Image placeholder height
    public let imagePlaceholderHeight: CGFloat

    /// Table border width
    public let tableBorderWidth: CGFloat

    /// Table corner radius
    public let tableCornerRadius: CGFloat

    public init(
        // Typography
        bodyFont: Font = .body,
        codeFont: Font = .system(.body, design: .monospaced),
        headingFonts: [Int: Font] = [
            1: .system(.largeTitle, weight: .bold),
            2: .system(.title, weight: .bold),
            3: .system(.title2, weight: .bold),
            4: .system(.title3, weight: .bold),
            5: .system(.headline, weight: .bold),
            6: .system(.subheadline, weight: .bold)
        ],
        tableHeaderFont: Font = .system(.body, weight: .semibold),
        tableBodyFont: Font = .body,
        taskListCheckboxFont: Font = .body,

        // Colors
        textColor: Color = .primary,
        headingColor: Color = .primary,
        linkColor: Color = .blue,
        codeTextColor: Color = .primary,
        codeBackgroundColor: Color = Color.gray.opacity(0.1),
        blockQuoteBorderColor: Color = Color.gray.opacity(0.5),
        blockQuoteBackgroundColor: Color = Color.gray.opacity(0.05),
        thematicBreakColor: Color = Color.gray.opacity(0.3),
        listMarkerColor: Color = .primary,
        strikethroughColor: Color = Color.gray,
        taskListCheckedColor: Color = Color.green,
        taskListUncheckedColor: Color = Color.gray.opacity(0.4),
        tableBorderColor: Color = Color.gray.opacity(0.3),
        tableBackgroundColor: Color = Color.clear,
        tableHeaderBackgroundColor: Color = Color.gray.opacity(0.1),
        tableCellBackgroundColor: Color = Color.clear,
        tableHeaderTextColor: Color = .primary,
        tableBodyTextColor: Color = .primary,

        // Spacing
        documentSpacing: CGFloat = 16,
        paragraphSpacing: CGFloat = 12,
        lineBreakSpacing: CGFloat = 4,
        blockQuoteSpacing: CGFloat = 12,
        blockQuoteContentSpacing: CGFloat = 8,
        blockQuotePadding: CGFloat = 16,
        blockQuoteVerticalPadding: CGFloat = 12,
        thematicBreakSpacing: CGFloat = 24,
        listItemSpacing: CGFloat = 8,
        listItemContentSpacing: CGFloat = 4,
        listMarkerSpacing: CGFloat = 8,
        listIndentation: CGFloat = 20,
        listMarkerWidth: CGFloat = 20,
        codeSpanPadding: CGFloat = 4,
        codeBlockPadding: CGFloat = 12,
        taskListSpacing: CGFloat = 8,
        taskListContentSpacing: CGFloat = 4,
        tableCellPadding: CGFloat = 8,

        // Dimensions
        blockQuoteBorderWidth: CGFloat = 4,
        blockQuoteCornerRadius: CGFloat = 8,
        codeCornerRadius: CGFloat = 6,
        imageMaxWidth: CGFloat = .infinity,
        imageCornerRadius: CGFloat = 8,
        imagePlaceholderHeight: CGFloat = 200,
        tableBorderWidth: CGFloat = 1,
        tableCornerRadius: CGFloat = 8
    ) {
        self.bodyFont = bodyFont
        self.codeFont = codeFont
        self.headingFonts = headingFonts
        self.tableHeaderFont = tableHeaderFont
        self.tableBodyFont = tableBodyFont
        self.taskListCheckboxFont = taskListCheckboxFont

        self.textColor = textColor
        self.headingColor = headingColor
        self.linkColor = linkColor
        self.codeTextColor = codeTextColor
        self.codeBackgroundColor = codeBackgroundColor
        self.blockQuoteBorderColor = blockQuoteBorderColor
        self.blockQuoteBackgroundColor = blockQuoteBackgroundColor
        self.thematicBreakColor = thematicBreakColor
        self.listMarkerColor = listMarkerColor
        self.strikethroughColor = strikethroughColor
        self.taskListCheckedColor = taskListCheckedColor
        self.taskListUncheckedColor = taskListUncheckedColor
        self.tableBorderColor = tableBorderColor
        self.tableBackgroundColor = tableBackgroundColor
        self.tableHeaderBackgroundColor = tableHeaderBackgroundColor
        self.tableCellBackgroundColor = tableCellBackgroundColor
        self.tableHeaderTextColor = tableHeaderTextColor
        self.tableBodyTextColor = tableBodyTextColor

        self.documentSpacing = documentSpacing
        self.paragraphSpacing = paragraphSpacing
        self.lineBreakSpacing = lineBreakSpacing
        self.blockQuoteSpacing = blockQuoteSpacing
        self.blockQuoteContentSpacing = blockQuoteContentSpacing
        self.blockQuotePadding = blockQuotePadding
        self.blockQuoteVerticalPadding = blockQuoteVerticalPadding
        self.thematicBreakSpacing = thematicBreakSpacing
        self.listItemSpacing = listItemSpacing
        self.listItemContentSpacing = listItemContentSpacing
        self.listMarkerSpacing = listMarkerSpacing
        self.listIndentation = listIndentation
        self.listMarkerWidth = listMarkerWidth
        self.codeSpanPadding = codeSpanPadding
        self.codeBlockPadding = codeBlockPadding
        self.taskListSpacing = taskListSpacing
        self.taskListContentSpacing = taskListContentSpacing
        self.tableCellPadding = tableCellPadding

        self.blockQuoteBorderWidth = blockQuoteBorderWidth
        self.blockQuoteCornerRadius = blockQuoteCornerRadius
        self.codeCornerRadius = codeCornerRadius
        self.imageMaxWidth = imageMaxWidth
        self.imageCornerRadius = imageCornerRadius
        self.imagePlaceholderHeight = imagePlaceholderHeight
        self.tableBorderWidth = tableBorderWidth
        self.tableCornerRadius = tableCornerRadius
    }

    // MARK: - Convenience Methods

    /// Get heading font for specific level
    public func headingFont(for level: Int) -> Font {
        return headingFonts[level] ?? bodyFont
    }

    /// Get heading spacing for specific level
    public func headingSpacing(for level: Int) -> CGFloat {
        // Larger headings get more spacing
        switch level {
        case 1: return 24
        case 2: return 20
        case 3: return 16
        case 4: return 14
        case 5: return 12
        case 6: return 10
        default: return 12
        }
    }

    /// Create a dark mode variant
    public func darkMode() -> SwiftUIStyleConfiguration {
        SwiftUIStyleConfiguration(copying: self, palette: .dark)
    }

    /// Create a compact variant with reduced spacing
    public func compact() -> SwiftUIStyleConfiguration {
        SwiftUIStyleConfiguration(copying: self, spatialScale: 0.75)
    }

    private enum Palette {
        case preserving
        case dark

        func color(_ original: Color, dark: Color) -> Color {
            self == .dark ? dark : original
        }
    }

    private init(
        copying source: SwiftUIStyleConfiguration,
        palette: Palette = .preserving,
        spatialScale: CGFloat = 1
    ) {
        self.init(
            bodyFont: source.bodyFont,
            codeFont: source.codeFont,
            headingFonts: source.headingFonts,
            tableHeaderFont: source.tableHeaderFont,
            tableBodyFont: source.tableBodyFont,
            taskListCheckboxFont: source.taskListCheckboxFont,

            textColor: source.textColor,
            headingColor: source.headingColor,
            linkColor: source.linkColor,
            codeTextColor: source.codeTextColor,
            codeBackgroundColor: palette.color(
                source.codeBackgroundColor,
                dark: Color.gray.opacity(0.2)
            ),
            blockQuoteBorderColor: palette.color(
                source.blockQuoteBorderColor,
                dark: Color.gray.opacity(0.4)
            ),
            blockQuoteBackgroundColor: palette.color(
                source.blockQuoteBackgroundColor,
                dark: Color.gray.opacity(0.1)
            ),
            thematicBreakColor: palette.color(
                source.thematicBreakColor,
                dark: Color.gray.opacity(0.4)
            ),
            listMarkerColor: source.listMarkerColor,
            strikethroughColor: palette.color(
                source.strikethroughColor,
                dark: Color.gray.opacity(0.7)
            ),
            taskListCheckedColor: source.taskListCheckedColor,
            taskListUncheckedColor: palette.color(
                source.taskListUncheckedColor,
                dark: Color.gray.opacity(0.4)
            ),
            tableBorderColor: palette.color(
                source.tableBorderColor,
                dark: Color.gray.opacity(0.4)
            ),
            tableBackgroundColor: source.tableBackgroundColor,
            tableHeaderBackgroundColor: palette.color(
                source.tableHeaderBackgroundColor,
                dark: Color.gray.opacity(0.2)
            ),
            tableCellBackgroundColor: source.tableCellBackgroundColor,
            tableHeaderTextColor: source.tableHeaderTextColor,
            tableBodyTextColor: source.tableBodyTextColor,

            documentSpacing: source.documentSpacing * spatialScale,
            paragraphSpacing: source.paragraphSpacing * spatialScale,
            lineBreakSpacing: source.lineBreakSpacing * spatialScale,
            blockQuoteSpacing: source.blockQuoteSpacing * spatialScale,
            blockQuoteContentSpacing: source.blockQuoteContentSpacing * spatialScale,
            blockQuotePadding: source.blockQuotePadding * spatialScale,
            blockQuoteVerticalPadding: source.blockQuoteVerticalPadding * spatialScale,
            thematicBreakSpacing: source.thematicBreakSpacing * spatialScale,
            listItemSpacing: source.listItemSpacing * spatialScale,
            listItemContentSpacing: source.listItemContentSpacing * spatialScale,
            listMarkerSpacing: source.listMarkerSpacing * spatialScale,
            listIndentation: source.listIndentation * spatialScale,
            listMarkerWidth: source.listMarkerWidth,
            codeSpanPadding: source.codeSpanPadding * spatialScale,
            codeBlockPadding: source.codeBlockPadding * spatialScale,
            taskListSpacing: source.taskListSpacing * spatialScale,
            taskListContentSpacing: source.taskListContentSpacing * spatialScale,
            tableCellPadding: source.tableCellPadding * spatialScale,

            blockQuoteBorderWidth: source.blockQuoteBorderWidth,
            blockQuoteCornerRadius: source.blockQuoteCornerRadius,
            codeCornerRadius: source.codeCornerRadius,
            imageMaxWidth: source.imageMaxWidth,
            imageCornerRadius: source.imageCornerRadius,
            imagePlaceholderHeight: source.imagePlaceholderHeight,
            tableBorderWidth: source.tableBorderWidth,
            tableCornerRadius: source.tableCornerRadius
        )
    }
}

// MARK: - Predefined Themes

@available(iOS 17.0, macOS 14.0, *)
public extension SwiftUIStyleConfiguration {

    /// GitHub-style theme
    static let github = SwiftUIStyleConfiguration(
        bodyFont: .system(.body),
        codeFont: .system(.body, design: .monospaced),
        headingFonts: [
            1: .system(.largeTitle, weight: .bold),
            2: .system(.title, weight: .bold),
            3: .system(.title2, weight: .bold),
            4: .system(.title3, weight: .bold),
            5: .system(.headline, weight: .bold),
            6: .system(.subheadline, weight: .bold)
        ],

        textColor: Color(red: 0.15, green: 0.15, blue: 0.15),
        headingColor: Color(red: 0.15, green: 0.15, blue: 0.15),
        linkColor: Color(red: 0.04, green: 0.52, blue: 0.78),
        codeTextColor: Color(red: 0.85, green: 0.11, blue: 0.35),
        codeBackgroundColor: Color(red: 0.97, green: 0.97, blue: 0.98),
        blockQuoteBorderColor: Color(red: 0.87, green: 0.87, blue: 0.87),
        blockQuoteBackgroundColor: Color(red: 0.98, green: 0.98, blue: 0.98),
        taskListCheckedColor: Color(red: 0.13, green: 0.54, blue: 0.13), // GitHub green
        taskListUncheckedColor: Color(red: 0.59, green: 0.63, blue: 0.67), // GitHub gray

        documentSpacing: 16,
        paragraphSpacing: 16,
        blockQuotePadding: 16,
        listIndentation: 24,
        codeBlockPadding: 16
    )

    /// Minimal theme with reduced visual elements
    static let minimal = SwiftUIStyleConfiguration(
        bodyFont: .system(.body),
        codeFont: .system(.body, design: .monospaced),

        textColor: .primary,
        headingColor: .primary,
        linkColor: .primary,
        codeTextColor: .primary,
        codeBackgroundColor: .clear,
        blockQuoteBorderColor: Color.gray.opacity(0.3),
        blockQuoteBackgroundColor: .clear,

        documentSpacing: 24,
        paragraphSpacing: 16,
        blockQuoteSpacing: 8,
        blockQuotePadding: 16,
        codeBlockPadding: 0,

        blockQuoteBorderWidth: 2,
        blockQuoteCornerRadius: 0,
        codeCornerRadius: 0
    )

    /// Academic/paper style theme
    static let academic = SwiftUIStyleConfiguration(
        bodyFont: .system(.body),
        codeFont: .system(.footnote, design: .monospaced),
        headingFonts: [
            1: .system(.title, weight: .bold),
            2: .system(.title2, weight: .bold),
            3: .system(.title3, weight: .semibold),
            4: .system(.headline, weight: .semibold),
            5: .system(.subheadline, weight: .medium),
            6: .system(.caption, weight: .medium)
        ],

        textColor: Color(red: 0.2, green: 0.2, blue: 0.2),
        headingColor: Color(red: 0.1, green: 0.1, blue: 0.1),
        linkColor: Color(red: 0.0, green: 0.0, blue: 0.8),

        documentSpacing: 20,
        paragraphSpacing: 14,
        listIndentation: 32,

        blockQuoteCornerRadius: 0,
        codeCornerRadius: 2
    )
}
