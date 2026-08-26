/// HTML-specific rendering options, errors, and implementation support.
import Foundation

// MARK: - HTML Options

/// Immutable options consumed by `HTMLRenderer`.
public struct HTMLRenderOptions: Sendable {
    /// Base URL for resolving relative links
    public let baseURL: URL?

    /// Whether to sanitize HTML output for security
    public let sanitizeHTML: Bool

    /// Custom CSS classes or styling information
    public let styleConfiguration: HTMLStyleConfiguration

    /// Configuration for Mermaid diagram rendering
    public let mermaidConfiguration: MermaidConfiguration

    /// Configuration for KaTeX math rendering
    public let katexConfiguration: KaTeXConfiguration

    public init(
        baseURL: URL? = nil,
        sanitizeHTML: Bool = true,
        styleConfiguration: HTMLStyleConfiguration = .default,
        mermaidConfiguration: MermaidConfiguration = .default,
        katexConfiguration: KaTeXConfiguration = .default
    ) {
        self.baseURL = baseURL
        self.sanitizeHTML = sanitizeHTML
        self.styleConfiguration = styleConfiguration
        self.mermaidConfiguration = mermaidConfiguration
        self.katexConfiguration = katexConfiguration
    }
}

/// Metadata used only when producing a complete HTML document.
public struct HTMLDocumentMetadata: Sendable, Equatable {
    public let title: String
    public let language: String

    public init(title: String = "Markdown Document", language: String = "en") {
        self.title = title
        self.language = language
    }
}

// MARK: - Style Configuration

/// Configuration for styling rendered output
public struct HTMLStyleConfiguration: Sendable {
    /// CSS classes for different element types
    public let cssClasses: [ASTNodeType: String]

    /// Custom attributes for elements
    public let customAttributes: [ASTNodeType: [String: String]]

    /// Whether to include source position attributes
    public let includeSourcePositions: Bool

    /// Code syntax highlighting configuration
    public let syntaxHighlighting: HTMLSyntaxHighlightingOptions

    public init(
        cssClasses: [ASTNodeType: String] = [:],
        customAttributes: [ASTNodeType: [String: String]] = [:],
        includeSourcePositions: Bool = false,
        syntaxHighlighting: HTMLSyntaxHighlightingOptions = .default
    ) {
        self.cssClasses = cssClasses
        self.customAttributes = customAttributes
        self.includeSourcePositions = includeSourcePositions
        self.syntaxHighlighting = syntaxHighlighting
    }

    public static let `default` = HTMLStyleConfiguration()
}

// MARK: - Syntax Highlighting Configuration

/// Configuration for code syntax highlighting
public struct HTMLSyntaxHighlightingOptions: Sendable {
    /// Whether syntax highlighting is enabled
    public let enabled: Bool

    /// CSS class prefix for syntax highlighting
    public let cssPrefix: String

    /// Supported languages for highlighting
    public let supportedLanguages: Set<String>

    public init(
        enabled: Bool = false,
        cssPrefix: String = "language-",
        supportedLanguages: Set<String> = Self.commonLanguages
    ) {
        self.enabled = enabled
        self.cssPrefix = cssPrefix
        self.supportedLanguages = supportedLanguages
    }

    public static let `default` = HTMLSyntaxHighlightingOptions()

    /// Common programming languages for syntax highlighting
    public static let commonLanguages: Set<String> = [
        "swift", "objective-c", "javascript", "typescript", "python", "java",
        "kotlin", "c", "cpp", "csharp", "go", "rust", "php", "ruby", "scala",
        "html", "css", "xml", "json", "yaml", "markdown", "bash", "shell",
        "sql", "r", "matlab", "perl", "lua", "dart", "elixir", "haskell"
    ]
}

// MARK: - Renderer Error Types

/// Errors raised at the HTML output seam.
public enum HTMLRenderingError: Error, LocalizedError, Sendable {
    case unsupportedNodeType(ASTNodeType)

    public var errorDescription: String? {
        switch self {
        case .unsupportedNodeType(let type):
            return "Unsupported AST node type: \(type)"
        }
    }
}

// MARK: - Renderer Utilities

/// Implementation details shared within the HTML output module.
enum RendererUtils {
    /// Escape HTML special characters
    static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Escape HTML attribute values
    static func escapeHTMLAttribute(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Normalize URL for security
    static func normalizeURL(_ url: String, baseURL: URL? = nil) -> String? {
        // Remove javascript: and data: URLs for security
        let lowercased = url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lowercased.hasPrefix("javascript:") || lowercased.hasPrefix("data:") {
            return nil
        }

        // Handle relative URLs
        if let baseURL = baseURL, !url.contains("://") {
            return URL(string: url, relativeTo: baseURL)?.absoluteString ?? url
        }

        return url
    }

    /// Generate CSS class name from node type
    static func cssClassName(for nodeType: ASTNodeType, prefix: String = "md-") -> String {
        return prefix + nodeType.rawValue.replacingOccurrences(of: "_", with: "-")
    }

    /// Generate HTML attributes from style configuration
    static func htmlAttributes(
        for nodeType: ASTNodeType,
        sourceLocation: SourceLocation?,
        styleConfig: HTMLStyleConfiguration
    ) -> [String: String] {
        var attributes: [String: String] = [:]

        // Add CSS class only if explicitly configured
        if let cssClass = styleConfig.cssClasses[nodeType] {
            attributes["class"] = cssClass
        }
        // Note: Removed the automatic fallback to cssClassName for default styling
        // This keeps HTML output clean by default, CSS classes only when explicitly requested

        // Add custom attributes
        if let customAttrs = styleConfig.customAttributes[nodeType] {
            attributes.merge(customAttrs) { _, new in new }
        }

        // Add source position if enabled
        if styleConfig.includeSourcePositions, let location = sourceLocation {
            attributes["data-source-line"] = String(location.line)
            attributes["data-source-column"] = String(location.column)
        }

        return attributes
    }

    /// Format HTML attributes as string
    static func formatHTMLAttributes(_ attributes: [String: String]) -> String {
        guard !attributes.isEmpty else { return "" }

        return " " + attributes
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(key)=\"\(escapeHTMLAttribute(value))\""
            }
            .joined(separator: " ")
    }
}

// MARK: - GFM Rendering for HTML

extension HTMLRenderer {
    /// Render GFM table
    func renderGFMTable(_ node: AST.GFMTableNode) async throws -> String {
        var html = "<table"

        let attributes = RendererUtils.htmlAttributes(
            for: .table,
            sourceLocation: node.sourceLocation,
            styleConfig: options.styleConfiguration
        )

        html += RendererUtils.formatHTMLAttributes(attributes)
        html += ">\n"

        // Separate header and body rows
        let headerRows = node.rows.filter { $0.isHeader }
        let bodyRows = node.rows.filter { !$0.isHeader }

        // Render header
        if !headerRows.isEmpty {
            html += "<thead>\n"
            for headerRow in headerRows {
                html += try await renderTableRow(headerRow, alignments: node.alignments)
            }
            html += "</thead>\n"
        }

        // Render body
        if !bodyRows.isEmpty {
            html += "<tbody>\n"
            for bodyRow in bodyRows {
                html += try await renderTableRow(bodyRow, alignments: node.alignments)
            }
            html += "</tbody>\n"
        }

        html += "</table>\n"
        return html
    }

    /// Render table row
    private func renderTableRow(_ row: AST.GFMTableRowNode, alignments: [GFMTableAlignment]) async throws -> String {
        var html = "<tr"

        let attributes = RendererUtils.htmlAttributes(
            for: .tableRow,
            sourceLocation: row.sourceLocation,
            styleConfig: options.styleConfiguration
        )

        html += RendererUtils.formatHTMLAttributes(attributes)
        html += ">\n"

        for (index, cell) in row.cells.enumerated() {
            html += try await renderTableCell(cell, alignment: index < alignments.count ? alignments[index] : .none)
        }

        html += "</tr>\n"
        return html
    }

    /// Render table cell
    private func renderTableCell(_ cell: AST.GFMTableCellNode, alignment: GFMTableAlignment) async throws -> String {
        let tag = cell.isHeader ? "th" : "td"
        var html = "<\(tag)"

        // Add alignment
        if alignment != .none {
            html += " style=\"text-align: \(alignment.rawValue)\""
        }

        // Add CSS class and custom attributes
        var attributes = RendererUtils.htmlAttributes(
            for: .tableCell,
            sourceLocation: cell.sourceLocation,
            styleConfig: options.styleConfiguration
        )

        // Add scope attribute for header cells
        if cell.isHeader {
            attributes["scope"] = "col"
        }

        html += RendererUtils.formatHTMLAttributes(attributes)
        html += ">"

        // Render inline content if available, otherwise use plain text
        if !cell.children.isEmpty {
            for child in cell.children {
                html += try await render(node: child)
            }
        } else {
            html += RendererUtils.escapeHTML(cell.content)
        }

        html += "</\(tag)>\n"

        return html
    }

    /// Render GFM task list item
    func renderGFMTaskListItem(_ node: AST.GFMTaskListItemNode) async throws -> String {
        var html = "<li"

        // Add CSS class for task list item
        var attributes = RendererUtils.htmlAttributes(
            for: .taskListItem,
            sourceLocation: node.sourceLocation,
            styleConfig: options.styleConfiguration
        )

        // Add default CSS class if not explicitly configured
        if attributes["class"] == nil {
            attributes["class"] = node.isChecked ? "task-list-item task-list-item-checked" : "task-list-item task-list-item-unchecked"
        } else {
            // Append state-specific classes to existing class
            let baseClass = attributes["class"]!
            attributes["class"] = node.isChecked ? "\(baseClass) task-list-item-checked" : "\(baseClass) task-list-item-unchecked"
        }

        // Add inline styling for better visual prominence when checked
        var styleAttributes: [String] = []
        if node.isChecked {
            styleAttributes.append("background-color: rgba(33, 136, 33, 0.08)")  // GitHub green with low opacity
            styleAttributes.append("border-radius: 6px")
            styleAttributes.append("padding: 4px 8px")
            styleAttributes.append("margin: 2px 0")
        } else {
            styleAttributes.append("padding: 4px 8px")
            styleAttributes.append("margin: 2px 0")
        }

        if !styleAttributes.isEmpty {
            attributes["style"] = styleAttributes.joined(separator: "; ")
        }

        html += RendererUtils.formatHTMLAttributes(attributes)
        html += ">"

        // Add checkbox input with enhanced styling
        html += "<input type=\"checkbox\""

        // Add checked state
        if node.isChecked {
            html += " checked"
        }

        // Make disabled for read-only rendering
        html += " disabled"

        // Add accessibility attributes
        html += " aria-checked=\"\(node.isChecked ? "true" : "false")\""
        html += " aria-label=\"\(node.isChecked ? "Completed task" : "Incomplete task")\""

        // Add CSS class for checkbox with enhanced styling
        let checkboxClass = node.isChecked ? "task-list-checkbox task-list-checkbox-checked" : "task-list-checkbox task-list-checkbox-unchecked"
        html += " class=\"\(checkboxClass)\""

        // Add inline styling for the checkbox to make it more prominent
        var checkboxStyles: [String] = []
        checkboxStyles.append("margin-right: 8px")
        checkboxStyles.append("transform: scale(1.2)")
        checkboxStyles.append("vertical-align: middle")

        if node.isChecked {
            checkboxStyles.append("accent-color: #218838")  // GitHub green
            checkboxStyles.append("filter: brightness(1.1)")
        } else {
            checkboxStyles.append("accent-color: #6c757d")  // GitHub gray
        }

        html += " style=\"\(checkboxStyles.joined(separator: "; "))\""

        html += " />"

        // Add a space between checkbox and content
        html += " "

        // Wrap content in a span for styling completed tasks
        if node.isChecked {
            html += "<span class=\"task-list-content task-list-content-checked\" style=\"opacity: 0.8; text-decoration: line-through; text-decoration-color: #218838; text-decoration-thickness: 1px;\">"
        } else {
            html += "<span class=\"task-list-content task-list-content-unchecked\">"
        }

        // Render task content
        for child in node.children {
            html += try await render(node: child)
        }

        html += "</span>"
        html += "</li>\n"

        return html
    }
}
