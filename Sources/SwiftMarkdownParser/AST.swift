/// Abstract Syntax Tree (AST) definitions for markdown parsing
/// 
/// This file defines the core AST node types and structures used throughout
/// the markdown parser. The AST provides a renderer-agnostic representation
/// of parsed markdown documents.

import Foundation

// MARK: - Core AST Protocol

/// Base protocol for all AST nodes
public protocol ASTNode: Sendable {
    /// The type of this AST node
    var nodeType: ASTNodeType { get }
    
    /// Child nodes (if any)
    var children: [ASTNode] { get }
    
    /// Source location information
    var sourceLocation: SourceLocation? { get }
}

/// Types of AST nodes
public struct ASTNodeType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    // Document structure
    public static let document = ASTNodeType(rawValue: "document")
    
    // Block elements
    public static let paragraph = ASTNodeType(rawValue: "paragraph")
    public static let heading = ASTNodeType(rawValue: "heading")
    public static let blockQuote = ASTNodeType(rawValue: "blockQuote")
    public static let list = ASTNodeType(rawValue: "list")
    public static let listItem = ASTNodeType(rawValue: "listItem")
    public static let codeBlock = ASTNodeType(rawValue: "codeBlock")
    public static let thematicBreak = ASTNodeType(rawValue: "thematicBreak")
    public static let table = ASTNodeType(rawValue: "table")
    public static let tableRow = ASTNodeType(rawValue: "tableRow")
    public static let tableCell = ASTNodeType(rawValue: "tableCell")
    
    // Inline elements
    public static let text = ASTNodeType(rawValue: "text")
    public static let emphasis = ASTNodeType(rawValue: "emphasis")
    public static let strongEmphasis = ASTNodeType(rawValue: "strongEmphasis")
    public static let link = ASTNodeType(rawValue: "link")
    public static let image = ASTNodeType(rawValue: "image")
    public static let codeSpan = ASTNodeType(rawValue: "codeSpan")
    public static let lineBreak = ASTNodeType(rawValue: "lineBreak")
    public static let strikethrough = ASTNodeType(rawValue: "strikethrough")
    public static let htmlBlock = ASTNodeType(rawValue: "htmlBlock")
    public static let htmlInline = ASTNodeType(rawValue: "htmlInline")
    
    // GFM Extensions
    public static let taskListItem = ASTNodeType(rawValue: "taskListItem")
    public static let autolink = ASTNodeType(rawValue: "autolink")
}

// MARK: - Source Location

/// Represents a location in the source markdown text
public struct SourceLocation: Sendable, Equatable {
    /// Line number (1-based)
    public let line: Int
    
    /// Column number (1-based)
    public let column: Int
    
    /// Character offset from start of document (0-based)
    public let offset: Int
    
    public init(line: Int, column: Int, offset: Int) {
        self.line = line
        self.column = column
        self.offset = offset
    }
}

// MARK: - AST Namespace

/// Namespace for AST node implementations
public enum AST {
    
    // MARK: - Document Structure
    
    /// Root document node
    public struct DocumentNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .document
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.children = children
            self.sourceLocation = sourceLocation
        }
    }
    
    // MARK: - Block Elements
    
    /// Paragraph node
    public struct ParagraphNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .paragraph
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.children = children
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Heading node (ATX or Setext)
    public struct HeadingNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .heading
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        /// Heading level (1-6)
        public let level: Int
        
        public init(level: Int, children: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.level = level
            self.children = children
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Block quote node
    public struct BlockQuoteNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .blockQuote
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.children = children
            self.sourceLocation = sourceLocation
        }
    }
    
    /// List container node
    public struct ListNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .list
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        /// Whether this is an ordered list
        public let isOrdered: Bool
        
        /// Starting number for ordered lists
        public let startNumber: Int?
        
        /// List items
        public let items: [ASTNode]
        
        public init(isOrdered: Bool, startNumber: Int? = nil, items: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.isOrdered = isOrdered
            self.startNumber = startNumber
            self.items = items
            self.sourceLocation = sourceLocation
            self.children = items
        }
    }
    
    /// List item node
    public struct ListItemNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .listItem
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.children = children
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Code block node (fenced or indented)
    public struct CodeBlockNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .codeBlock
        public let children: [ASTNode] = []
        public let sourceLocation: SourceLocation?
        
        /// Code content
        public let content: String
        
        /// Programming language (for fenced blocks)
        public let language: String?
        
        /// Info string (for fenced blocks)
        public let info: String?
        
        /// Whether this is a fenced code block
        public let isFenced: Bool
        
        public init(content: String, language: String? = nil, info: String? = nil, isFenced: Bool = false, sourceLocation: SourceLocation? = nil) {
            self.content = content
            self.language = language
            self.info = info
            self.isFenced = isFenced
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Thematic break node (horizontal rule)
    public struct ThematicBreakNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .thematicBreak
        public let children: [ASTNode] = []
        public let sourceLocation: SourceLocation?
        
        /// Character used for the break (-, *, _)
        public let character: Character
        
        public init(character: Character = "-", sourceLocation: SourceLocation? = nil) {
            self.character = character
            self.sourceLocation = sourceLocation
        }
    }
    
    // MARK: - Inline Elements
    
    /// Plain text node
    public struct TextNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .text
        public let children: [ASTNode] = []
        public let sourceLocation: SourceLocation?
        
        /// Text content
        public let content: String
        
        public init(content: String, sourceLocation: SourceLocation? = nil) {
            self.content = content
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Emphasis node (italic)
    public struct EmphasisNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .emphasis
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.children = children
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Strong emphasis node (bold)
    public struct StrongEmphasisNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .strongEmphasis
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.children = children
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Link node
    public struct LinkNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .link
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        /// Link URL
        public let url: String
        
        /// Link title (optional)
        public let title: String?
        
        public init(url: String, title: String? = nil, children: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.url = url
            self.title = title
            self.children = children
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Image node
    public struct ImageNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .image
        public let children: [ASTNode] = []
        public let sourceLocation: SourceLocation?
        
        /// Image URL
        public let url: String
        
        /// Alt text
        public let altText: String
        
        /// Image title (optional)
        public let title: String?
        
        public init(url: String, altText: String, title: String? = nil, sourceLocation: SourceLocation? = nil) {
            self.url = url
            self.altText = altText
            self.title = title
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Inline code span node
    public struct CodeSpanNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .codeSpan
        public let children: [ASTNode] = []
        public let sourceLocation: SourceLocation?
        
        /// Code content
        public let content: String
        
        public init(content: String, sourceLocation: SourceLocation? = nil) {
            self.content = content
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Line break node
    public struct LineBreakNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .lineBreak
        public let children: [ASTNode] = []
        public let sourceLocation: SourceLocation?
        
        /// Whether this is a hard break (two spaces + newline)
        public let isHard: Bool
        
        public init(isHard: Bool = false, sourceLocation: SourceLocation? = nil) {
            self.isHard = isHard
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Strikethrough node (GFM extension)
    public struct StrikethroughNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .strikethrough
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        /// Content to be struck through
        public let content: [ASTNode]
        
        public init(content: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.content = content
            self.children = content
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Autolink node (GFM extension)
    public struct AutolinkNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .autolink
        public let children: [ASTNode] = []
        public let sourceLocation: SourceLocation?
        
        /// The URL
        public let url: String
        
        /// Display text
        public let text: String
        
        public init(url: String, text: String, sourceLocation: SourceLocation? = nil) {
            self.url = url
            self.text = text
            self.sourceLocation = sourceLocation
        }
    }
    
    /// HTML block node
    public struct HTMLBlockNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .htmlBlock
        public let children: [ASTNode] = []
        public let sourceLocation: SourceLocation?
        
        /// HTML content
        public let content: String
        
        public init(content: String, sourceLocation: SourceLocation? = nil) {
            self.content = content
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Inline HTML node
    public struct HTMLInlineNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .htmlInline
        public let children: [ASTNode] = []
        public let sourceLocation: SourceLocation?
        
        /// HTML content
        public let content: String
        
        public init(content: String, sourceLocation: SourceLocation? = nil) {
            self.content = content
            self.sourceLocation = sourceLocation
        }
    }
    
    /// Soft line break node
    public struct SoftBreakNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .lineBreak
        public let children: [ASTNode] = []
        public let sourceLocation: SourceLocation?
        
        public init(sourceLocation: SourceLocation? = nil) {
            self.sourceLocation = sourceLocation
        }
    }
    
    // MARK: - GFM Extensions
    
    /// Task list item node (GFM extension)
    public struct GFMTaskListItemNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .taskListItem
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        /// Whether the task is checked
        public let isChecked: Bool
        
        public init(isChecked: Bool, children: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.isChecked = isChecked
            self.children = children
            self.sourceLocation = sourceLocation
        }
    }
    
    /// GFM Table node
    public struct GFMTableNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .table
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        /// Table rows
        public let rows: [GFMTableRowNode]
        
        /// Column alignments
        public let alignments: [GFMTableAlignment]
        
        public init(rows: [GFMTableRowNode], alignments: [GFMTableAlignment], sourceLocation: SourceLocation? = nil) {
            self.rows = rows
            self.alignments = alignments
            self.children = rows.map { $0 as ASTNode }
            self.sourceLocation = sourceLocation
        }
    }
    
    /// GFM Table row node
    public struct GFMTableRowNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .tableRow
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        /// Table cells
        public let cells: [GFMTableCellNode]
        
        /// Whether this is a header row
        public let isHeader: Bool
        
        public init(cells: [GFMTableCellNode], isHeader: Bool, sourceLocation: SourceLocation? = nil) {
            self.cells = cells
            self.isHeader = isHeader
            self.children = cells.map { $0 as ASTNode }
            self.sourceLocation = sourceLocation
        }
    }
    
    /// GFM Table cell node
    public struct GFMTableCellNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .tableCell
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        /// Cell content (plain text for backwards compatibility)
        public let content: String
        
        /// Whether this is a header cell
        public let isHeader: Bool
        
        /// Cell alignment
        public let alignment: GFMTableAlignment
        
        public init(content: String, isHeader: Bool, alignment: GFMTableAlignment = .none, sourceLocation: SourceLocation? = nil) {
            self.content = content
            self.isHeader = isHeader
            self.alignment = alignment
            self.children = []
            self.sourceLocation = sourceLocation
        }
        
        /// Initialize with inline content nodes
        public init(children: [ASTNode], isHeader: Bool, alignment: GFMTableAlignment = .none, sourceLocation: SourceLocation? = nil) {
            self.children = children
            self.isHeader = isHeader
            self.alignment = alignment
            // Generate plain text content for backwards compatibility
            self.content = Self.extractPlainText(from: children)
            self.sourceLocation = sourceLocation
        }
        
        /// Recursively extracts plain text content from AST nodes
        public static func extractPlainText(from nodes: [ASTNode]) -> String {
            return nodes.compactMap { node in
                switch node {
                case let textNode as AST.TextNode:
                    return textNode.content
                case let codeSpanNode as AST.CodeSpanNode:
                    return codeSpanNode.content
                case let autolinkNode as AST.AutolinkNode:
                    return autolinkNode.text
                case let imageNode as AST.ImageNode:
                    return imageNode.altText
                case let htmlInlineNode as AST.HTMLInlineNode:
                    return htmlInlineNode.content
                case let htmlBlockNode as AST.HTMLBlockNode:
                    return htmlBlockNode.content
                default:
                    // For nodes with children (emphasis, strong, links, etc.)
                    return extractPlainText(from: node.children)
                }
            }.joined()
        }
    }
    
    /// A temporary node to hold a fragment of other nodes during parsing.
    /// This should be flattened and removed from the final AST.
    public struct FragmentNode: ASTNode, Sendable {
        public let nodeType: ASTNodeType = .text // Behaves like text for most purposes
        public let children: [ASTNode]
        public let sourceLocation: SourceLocation?
        
        public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
            self.children = children
            self.sourceLocation = sourceLocation
        }
    }
}

// MARK: - GFM Table Alignment

/// Table cell alignment options
public enum GFMTableAlignment: String, Sendable, CaseIterable {
    case none = "none"
    case left = "left"
    case center = "center"
    case right = "right"
} 