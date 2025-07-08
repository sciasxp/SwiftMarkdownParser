/// SwiftUI rendering context and styling configuration
/// 
/// This file provides the configuration and styling system for the SwiftUI renderer,
/// including fonts, colors, spacing, and behavior customization.

import SwiftUI
import Foundation

// MARK: - SwiftUIRenderContext

/// Context for SwiftUI rendering with configuration and styling
@available(iOS 17.0, macOS 14.0, *)
public struct SwiftUIRenderContext: Sendable {
    /// Base URL for resolving relative links and images
    public let baseURL: URL?
    
    /// Style configuration for visual appearance
    public let styleConfiguration: SwiftUIStyleConfiguration
    
    /// Link handler for tap actions
    public let linkHandler: (@Sendable (URL) -> Void)?
    
    /// Image handler for custom image loading
    public let imageHandler: (@Sendable (URL) -> AnyView)?
    
    /// Maximum rendering depth to prevent infinite recursion
    public let maxDepth: Int
    
    /// Current rendering depth
    public let currentDepth: Int
    
    /// Whether to enable accessibility features
    public let enableAccessibility: Bool
    
    /// Whether to enable performance optimizations
    public let enablePerformanceOptimizations: Bool
    
    public init(
        baseURL: URL? = nil,
        styleConfiguration: SwiftUIStyleConfiguration = SwiftUIStyleConfiguration(),
        linkHandler: (@Sendable (URL) -> Void)? = nil,
        imageHandler: (@Sendable (URL) -> AnyView)? = nil,
        maxDepth: Int = 50,
        currentDepth: Int = 0,
        enableAccessibility: Bool = true,
        enablePerformanceOptimizations: Bool = true
    ) {
        self.baseURL = baseURL
        self.styleConfiguration = styleConfiguration
        self.linkHandler = linkHandler
        self.imageHandler = imageHandler
        self.maxDepth = maxDepth
        self.currentDepth = currentDepth
        self.enableAccessibility = enableAccessibility
        self.enablePerformanceOptimizations = enablePerformanceOptimizations
    }
    
    /// Create a new context with incremented depth
    public func incrementingDepth() -> SwiftUIRenderContext {
        SwiftUIRenderContext(
            baseURL: baseURL,
            styleConfiguration: styleConfiguration,
            linkHandler: linkHandler,
            imageHandler: imageHandler,
            maxDepth: maxDepth,
            currentDepth: currentDepth + 1,
            enableAccessibility: enableAccessibility,
            enablePerformanceOptimizations: enablePerformanceOptimizations
        )
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
        taskListCheckedColor: Color = .green,
        taskListUncheckedColor: Color = Color.gray.opacity(0.5),
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
        var config = self
        return SwiftUIStyleConfiguration(
            codeBackgroundColor: Color.gray.opacity(0.2),
            blockQuoteBorderColor: Color.gray.opacity(0.4),
            blockQuoteBackgroundColor: Color.gray.opacity(0.1),
            thematicBreakColor: Color.gray.opacity(0.4),
            strikethroughColor: Color.gray.opacity(0.7),
            taskListUncheckedColor: Color.gray.opacity(0.4),
            tableBorderColor: Color.gray.opacity(0.4),
            tableHeaderBackgroundColor: Color.gray.opacity(0.2)
        )
    }
    
    /// Create a compact variant with reduced spacing
    public func compact() -> SwiftUIStyleConfiguration {
        SwiftUIStyleConfiguration(
            bodyFont: bodyFont,
            codeFont: codeFont,
            headingFonts: headingFonts,
            tableHeaderFont: tableHeaderFont,
            tableBodyFont: tableBodyFont,
            taskListCheckboxFont: taskListCheckboxFont,
            
            textColor: textColor,
            headingColor: headingColor,
            linkColor: linkColor,
            codeTextColor: codeTextColor,
            codeBackgroundColor: codeBackgroundColor,
            blockQuoteBorderColor: blockQuoteBorderColor,
            blockQuoteBackgroundColor: blockQuoteBackgroundColor,
            thematicBreakColor: thematicBreakColor,
            listMarkerColor: listMarkerColor,
            strikethroughColor: strikethroughColor,
            taskListCheckedColor: taskListCheckedColor,
            taskListUncheckedColor: taskListUncheckedColor,
            tableBorderColor: tableBorderColor,
            tableBackgroundColor: tableBackgroundColor,
            tableHeaderBackgroundColor: tableHeaderBackgroundColor,
            tableCellBackgroundColor: tableCellBackgroundColor,
            tableHeaderTextColor: tableHeaderTextColor,
            tableBodyTextColor: tableBodyTextColor,
            
            documentSpacing: documentSpacing * 0.75,
            paragraphSpacing: paragraphSpacing * 0.75,
            lineBreakSpacing: lineBreakSpacing * 0.75,
            blockQuoteSpacing: blockQuoteSpacing * 0.75,
            blockQuoteContentSpacing: blockQuoteContentSpacing * 0.75,
            blockQuotePadding: blockQuotePadding * 0.75,
            blockQuoteVerticalPadding: blockQuoteVerticalPadding * 0.75,
            thematicBreakSpacing: thematicBreakSpacing * 0.75,
            listItemSpacing: listItemSpacing * 0.75,
            listItemContentSpacing: listItemContentSpacing * 0.75,
            listMarkerSpacing: listMarkerSpacing * 0.75,
            listIndentation: listIndentation * 0.75,
            listMarkerWidth: listMarkerWidth,
            codeSpanPadding: codeSpanPadding * 0.75,
            codeBlockPadding: codeBlockPadding * 0.75,
            taskListSpacing: taskListSpacing * 0.75,
            taskListContentSpacing: taskListContentSpacing * 0.75,
            tableCellPadding: tableCellPadding * 0.75,
            
            blockQuoteBorderWidth: blockQuoteBorderWidth,
            blockQuoteCornerRadius: blockQuoteCornerRadius,
            codeCornerRadius: codeCornerRadius,
            imageMaxWidth: imageMaxWidth,
            imageCornerRadius: imageCornerRadius,
            imagePlaceholderHeight: imagePlaceholderHeight,
            tableBorderWidth: tableBorderWidth,
            tableCornerRadius: tableCornerRadius
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