/// Renderer protocol and infrastructure for converting AST to various output formats
/// 
/// This file defines the pluggable renderer architecture that allows the same AST
/// to be rendered to different output formats (HTML, SwiftUI, PDF, etc.).
import Foundation

// MARK: - Renderer Protocol

/// Protocol for rendering AST nodes to a specific output format
public protocol MarkdownRenderer: Sendable {
    /// The output type produced by this renderer
    associatedtype Output
    
    /// Render a complete document AST to the output format
    /// - Parameter document: The root document node
    /// - Returns: The rendered output
    func render(document: AST.DocumentNode) async throws -> Output
    
    /// Render any AST node to the output format
    /// - Parameter node: The AST node to render
    /// - Returns: The rendered output
    func render(node: ASTNode) async throws -> Output
}

// MARK: - Renderer Context

/// Context passed to renderers for configuration and state
public struct RenderContext: Sendable {
    /// Base URL for resolving relative links
    public let baseURL: URL?
    
    /// Whether to sanitize HTML output for security
    public let sanitizeHTML: Bool
    
    /// Custom CSS classes or styling information
    public let styleConfiguration: StyleConfiguration
    
    /// Configuration for Mermaid diagram rendering
    public let mermaidConfiguration: MermaidConfiguration
    
    /// Link reference definitions from the document
    public let linkReferences: [String: LinkReference]
    
    /// Current rendering depth (for nested elements)
    public let depth: Int
    
    public init(
        baseURL: URL? = nil,
        sanitizeHTML: Bool = true,
        styleConfiguration: StyleConfiguration = .default,
        mermaidConfiguration: MermaidConfiguration = .default,
        linkReferences: [String: LinkReference] = [:],
        depth: Int = 0
    ) {
        self.baseURL = baseURL
        self.sanitizeHTML = sanitizeHTML
        self.styleConfiguration = styleConfiguration
        self.mermaidConfiguration = mermaidConfiguration
        self.linkReferences = linkReferences
        self.depth = depth
    }
    
    /// Create a new context with incremented depth
    public func incrementingDepth() -> RenderContext {
        RenderContext(
            baseURL: baseURL,
            sanitizeHTML: sanitizeHTML,
            styleConfiguration: styleConfiguration,
            mermaidConfiguration: mermaidConfiguration,
            linkReferences: linkReferences,
            depth: depth + 1
        )
    }
}

// MARK: - Style Configuration

/// Configuration for styling rendered output
public struct StyleConfiguration: Sendable {
    /// CSS classes for different element types
    public let cssClasses: [ASTNodeType: String]
    
    /// Custom attributes for elements
    public let customAttributes: [ASTNodeType: [String: String]]
    
    /// Whether to include source position attributes
    public let includeSourcePositions: Bool
    
    /// Code syntax highlighting configuration
    public let syntaxHighlighting: SyntaxHighlightingConfig
    
    public init(
        cssClasses: [ASTNodeType: String] = [:],
        customAttributes: [ASTNodeType: [String: String]] = [:],
        includeSourcePositions: Bool = false,
        syntaxHighlighting: SyntaxHighlightingConfig = .default
    ) {
        self.cssClasses = cssClasses
        self.customAttributes = customAttributes
        self.includeSourcePositions = includeSourcePositions
        self.syntaxHighlighting = syntaxHighlighting
    }
    
    public static let `default` = StyleConfiguration()
}

// MARK: - Syntax Highlighting Configuration

/// Configuration for code syntax highlighting
public struct SyntaxHighlightingConfig: Sendable {
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
    
    public static let `default` = SyntaxHighlightingConfig()
    
    /// Common programming languages for syntax highlighting
    public static let commonLanguages: Set<String> = [
        "swift", "objective-c", "javascript", "typescript", "python", "java",
        "kotlin", "c", "cpp", "csharp", "go", "rust", "php", "ruby", "scala",
        "html", "css", "xml", "json", "yaml", "markdown", "bash", "shell",
        "sql", "r", "matlab", "perl", "lua", "dart", "elixir", "haskell"
    ]
}

// MARK: - Link Reference

/// Link reference definition
public struct LinkReference: Sendable, Equatable {
    /// The URL of the link
    public let url: String
    
    /// Optional title for the link
    public let title: String?
    
    /// Source location where the reference was defined
    public let sourceLocation: SourceLocation?
    
    public init(url: String, title: String? = nil, sourceLocation: SourceLocation? = nil) {
        self.url = url
        self.title = title
        self.sourceLocation = sourceLocation
    }
}

// MARK: - Renderer Error Types

/// Errors that can occur during rendering
public enum RendererError: Error, LocalizedError, Sendable {
    case unsupportedNodeType(ASTNodeType)
    case invalidURL(String)
    case renderingFailed(String)
    case missingLinkReference(String)
    case htmlSanitizationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedNodeType(let type):
            return "Unsupported AST node type: \(type)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .renderingFailed(let message):
            return "Rendering failed: \(message)"
        case .missingLinkReference(let label):
            return "Missing link reference: \(label)"
        case .htmlSanitizationFailed(let message):
            return "HTML sanitization failed: \(message)"
        }
    }
}

// MARK: - Renderer Utilities

/// Utility functions for renderers
public enum RendererUtils {
    /// Escape HTML special characters
    public static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    /// Escape HTML attribute values
    public static func escapeHTMLAttribute(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    /// Normalize URL for security
    public static func normalizeURL(_ url: String, baseURL: URL? = nil) -> String? {
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
    public static func cssClassName(for nodeType: ASTNodeType, prefix: String = "md-") -> String {
        return prefix + nodeType.rawValue.replacingOccurrences(of: "_", with: "-")
    }
    
    /// Generate HTML attributes from style configuration
    public static func htmlAttributes(
        for nodeType: ASTNodeType,
        sourceLocation: SourceLocation?,
        styleConfig: StyleConfiguration
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
    public static func formatHTMLAttributes(_ attributes: [String: String]) -> String {
        guard !attributes.isEmpty else { return "" }
        
        return " " + attributes
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(key)=\"\(escapeHTMLAttribute(value))\""
            }
            .joined(separator: " ")
    }
}

// MARK: - Renderer Registry

/// Registry for managing multiple renderer types
public actor RendererRegistry {
    private var renderers: [String: any MarkdownRenderer] = [:]
    
    public init() {}
    
    /// Register a renderer with a name
    public func register<R: MarkdownRenderer>(renderer: R, withName name: String) {
        renderers[name] = renderer
    }
    
    /// Get a registered renderer by name
    public func renderer(named name: String) -> (any MarkdownRenderer)? {
        return renderers[name]
    }
    
    /// Get all registered renderer names
    public func registeredNames() -> [String] {
        return Array(renderers.keys).sorted()
    }
    
    /// Remove a renderer
    public func unregister(name: String) {
        renderers.removeValue(forKey: name)
    }
}

// MARK: - HTML Renderer Implementation

extension HTMLRenderer {
    // This extension is now primarily for CommonMark nodes.
    // GFM-specific rendering is handled in the public extension below.
}

// MARK: - GFM Rendering for HTML

public extension HTMLRenderer {
    /// Render GFM table
    func renderGFMTable(_ node: AST.GFMTableNode) async throws -> String {
        var html = "<table"
        
        let attributes = RendererUtils.htmlAttributes(
            for: .table,
            sourceLocation: node.sourceLocation,
            styleConfig: context.styleConfiguration
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
            styleConfig: context.styleConfiguration
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
            styleConfig: context.styleConfiguration
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
                let childRenderer = HTMLRenderer(context: context, configuration: configuration)
                html += try await childRenderer.render(node: child)
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
            styleConfig: context.styleConfiguration
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
            let childRenderer = HTMLRenderer(context: context, configuration: configuration)
            html += try await childRenderer.render(node: child)
        }
        
        html += "</span>"
        html += "</li>\n"
        
        return html
    }
} 