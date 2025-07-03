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
    
    /// Link reference definitions from the document
    public let linkReferences: [String: LinkReference]
    
    /// Current rendering depth (for nested elements)
    public let depth: Int
    
    public init(
        baseURL: URL? = nil,
        sanitizeHTML: Bool = true,
        styleConfiguration: StyleConfiguration = .default,
        linkReferences: [String: LinkReference] = [:],
        depth: Int = 0
    ) {
        self.baseURL = baseURL
        self.sanitizeHTML = sanitizeHTML
        self.styleConfiguration = styleConfiguration
        self.linkReferences = linkReferences
        self.depth = depth
    }
    
    /// Create a new context with incremented depth
    public func incrementingDepth() -> RenderContext {
        RenderContext(
            baseURL: baseURL,
            sanitizeHTML: sanitizeHTML,
            styleConfiguration: styleConfiguration,
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
        enabled: Bool = true,
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
    func renderGFMTable(_ node: AST.GFMTableNode) -> String {
        var html = "<table"
        
        if let tableClass = context.styleConfiguration.cssClasses[.table] {
            html += " class=\"\(tableClass)\""
        }
        
        html += ">\n"
        
        // Separate header and body rows
        let headerRows = node.rows.filter { $0.isHeader }
        let bodyRows = node.rows.filter { !$0.isHeader }
        
        // Render header
        if !headerRows.isEmpty {
            html += "<thead>\n"
            for headerRow in headerRows {
                html += renderTableRow(headerRow, alignments: node.alignments)
            }
            html += "</thead>\n"
        }
        
        // Render body
        if !bodyRows.isEmpty {
            html += "<tbody>\n"
            for bodyRow in bodyRows {
                html += renderTableRow(bodyRow, alignments: node.alignments)
            }
            html += "</tbody>\n"
        }
        
        html += "</table>\n"
        return html
    }
    
    /// Render table row
    private func renderTableRow(_ row: AST.GFMTableRowNode, alignments: [GFMTableAlignment]) -> String {
        var html = "<tr"
        
        if let rowClass = context.styleConfiguration.cssClasses[.tableRow] {
            html += " class=\"\(rowClass)\""
        }
        
        html += ">\n"
        
        for (index, cell) in row.cells.enumerated() {
            html += renderTableCell(cell, alignment: index < alignments.count ? alignments[index] : .none)
        }
        
        html += "</tr>\n"
        return html
    }
    
    /// Render table cell
    private func renderTableCell(_ cell: AST.GFMTableCellNode, alignment: GFMTableAlignment) -> String {
        let tag = cell.isHeader ? "th" : "td"
        var html = "<\(tag)"
        
        // Add alignment
        if alignment != .none {
            html += " style=\"text-align: \(alignment.rawValue)\""
        }
        
        // Add CSS class
        if let cellClass = context.styleConfiguration.cssClasses[.tableCell] {
            html += " class=\"\(cellClass)\""
        }
        
        html += ">"
        html += RendererUtils.escapeHTML(cell.content)
        html += "</\(tag)>\n"
        
        return html
    }
} 