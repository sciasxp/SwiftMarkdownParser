/// Abstract Syntax Tree (AST) nodes for markdown parsing
/// 
/// This file defines the complete AST structure that represents parsed markdown
/// in a renderer-agnostic format. Renderers can traverse this AST to produce
/// output in various formats (HTML, SwiftUI, PDF, etc.).
import Foundation

// MARK: - Core AST Protocol

/// Base protocol for all AST nodes
public protocol ASTNode: Sendable {
    /// The type of the AST node
    var nodeType: ASTNodeType { get }
    
    /// Child nodes (for container nodes)
    var children: [ASTNode] { get }
    
    /// Source location information for debugging
    var sourceLocation: SourceLocation? { get }
}

/// Types of AST nodes
public enum ASTNodeType: String, CaseIterable, Sendable {
    // Document structure
    case document
    
    // Block elements
    case paragraph
    case heading
    case blockQuote
    case codeBlock
    case htmlBlock
    case thematicBreak
    case list
    case listItem
    case table
    case tableRow
    case tableCell
    
    // Inline elements
    case text
    case emphasis
    case strongEmphasis
    case strikethrough
    case link
    case image
    case codeSpan
    case htmlInline
    case lineBreak
    case softBreak
    
    // GFM Extensions
    case taskListItem
    case autolink
}

/// Source location information for error reporting and debugging
public struct SourceLocation: Sendable, Equatable {
    public let line: Int
    public let column: Int
    public let offset: Int
    
    public init(line: Int, column: Int, offset: Int) {
        self.line = line
        self.column = column
        self.offset = offset
    }
}

// MARK: - Document Node

/// Root document node containing all parsed content
public struct DocumentNode: ASTNode {
    public let nodeType: ASTNodeType = .document
    public let children: [ASTNode]
    public let sourceLocation: SourceLocation?
    
    public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
        self.children = children
        self.sourceLocation = sourceLocation
    }
}

// MARK: - Block Nodes

/// Paragraph containing inline content
public struct ParagraphNode: ASTNode {
    public let nodeType: ASTNodeType = .paragraph
    public let children: [ASTNode]
    public let sourceLocation: SourceLocation?
    
    public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
        self.children = children
        self.sourceLocation = sourceLocation
    }
}

/// Heading with level and content
public struct HeadingNode: ASTNode {
    public let nodeType: ASTNodeType = .heading
    public let children: [ASTNode]
    public let sourceLocation: SourceLocation?
    public let level: Int // 1-6
    public let isSetext: Bool // true for setext, false for ATX
    
    public init(level: Int, isSetext: Bool = false, children: [ASTNode], sourceLocation: SourceLocation? = nil) {
        self.level = max(1, min(6, level))
        self.isSetext = isSetext
        self.children = children
        self.sourceLocation = sourceLocation
    }
}

/// Block quote containing other blocks
public struct BlockQuoteNode: ASTNode {
    public let nodeType: ASTNodeType = .blockQuote
    public let children: [ASTNode]
    public let sourceLocation: SourceLocation?
    
    public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
        self.children = children
        self.sourceLocation = sourceLocation
    }
}

/// Code block with optional language and content
public struct CodeBlockNode: ASTNode {
    public let nodeType: ASTNodeType = .codeBlock
    public let children: [ASTNode] = [] // Code blocks are leaf nodes
    public let sourceLocation: SourceLocation?
    public let content: String
    public let language: String?
    public let isFenced: Bool
    public let fenceChar: Character? // '`' or '~' for fenced blocks
    
    public init(content: String, language: String? = nil, isFenced: Bool, fenceChar: Character? = nil, sourceLocation: SourceLocation? = nil) {
        self.content = content
        self.language = language
        self.isFenced = isFenced
        self.fenceChar = fenceChar
        self.sourceLocation = sourceLocation
    }
}

/// Raw HTML block
public struct HTMLBlockNode: ASTNode {
    public let nodeType: ASTNodeType = .htmlBlock
    public let children: [ASTNode] = [] // HTML blocks are leaf nodes
    public let sourceLocation: SourceLocation?
    public let content: String
    public let htmlType: HTMLBlockType
    
    public init(content: String, htmlType: HTMLBlockType, sourceLocation: SourceLocation? = nil) {
        self.content = content
        self.htmlType = htmlType
        self.sourceLocation = sourceLocation
    }
}

/// HTML block types according to CommonMark spec
public enum HTMLBlockType: Int, CaseIterable, Sendable {
    case script = 1      // <script>, <pre>, <style>
    case comment = 2     // <!-- -->
    case processing = 3  // <?...?>
    case declaration = 4 // <!...>
    case cdata = 5       // <![CDATA[...]]>
    case element = 6     // Block-level HTML elements
    case complete = 7    // Complete tags
}

/// Thematic break (horizontal rule)
public struct ThematicBreakNode: ASTNode {
    public let nodeType: ASTNodeType = .thematicBreak
    public let children: [ASTNode] = [] // Thematic breaks are leaf nodes
    public let sourceLocation: SourceLocation?
    public let character: Character // '-', '*', or '_'
    
    public init(character: Character = "-", sourceLocation: SourceLocation? = nil) {
        self.character = character
        self.sourceLocation = sourceLocation
    }
}

/// List container (ordered or unordered)
public struct ListNode: ASTNode {
    public let nodeType: ASTNodeType = .list
    public let children: [ASTNode] // ListItemNodes
    public let sourceLocation: SourceLocation?
    public let isOrdered: Bool
    public let startNumber: Int? // For ordered lists
    public let delimiter: Character? // '.' or ')' for ordered lists
    public let bulletChar: Character? // '-', '*', or '+' for unordered lists
    public let isTight: Bool // Tight vs loose list
    
    public init(isOrdered: Bool, startNumber: Int? = nil, delimiter: Character? = nil, 
                bulletChar: Character? = nil, isTight: Bool = true, 
                children: [ASTNode], sourceLocation: SourceLocation? = nil) {
        self.isOrdered = isOrdered
        self.startNumber = startNumber
        self.delimiter = delimiter
        self.bulletChar = bulletChar
        self.isTight = isTight
        self.children = children
        self.sourceLocation = sourceLocation
    }
}

/// List item containing blocks
public struct ListItemNode: ASTNode {
    public let nodeType: ASTNodeType = .listItem
    public let children: [ASTNode]
    public let sourceLocation: SourceLocation?
    
    public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
        self.children = children
        self.sourceLocation = sourceLocation
    }
}

// MARK: - Table Nodes (GFM Extension)

/// Table container
public struct TableNode: ASTNode {
    public let nodeType: ASTNodeType = .table
    public let children: [ASTNode] // TableRowNodes
    public let sourceLocation: SourceLocation?
    public let columnAlignments: [TableColumnAlignment]
    
    public init(children: [ASTNode], columnAlignments: [TableColumnAlignment], sourceLocation: SourceLocation? = nil) {
        self.children = children
        self.columnAlignments = columnAlignments
        self.sourceLocation = sourceLocation
    }
}

/// Table row
public struct TableRowNode: ASTNode {
    public let nodeType: ASTNodeType = .tableRow
    public let children: [ASTNode] // TableCellNodes
    public let sourceLocation: SourceLocation?
    public let isHeader: Bool
    
    public init(children: [ASTNode], isHeader: Bool = false, sourceLocation: SourceLocation? = nil) {
        self.children = children
        self.isHeader = isHeader
        self.sourceLocation = sourceLocation
    }
}

/// Table cell
public struct TableCellNode: ASTNode {
    public let nodeType: ASTNodeType = .tableCell
    public let children: [ASTNode] // Inline content
    public let sourceLocation: SourceLocation?
    public let alignment: TableColumnAlignment
    
    public init(children: [ASTNode], alignment: TableColumnAlignment = .none, sourceLocation: SourceLocation? = nil) {
        self.children = children
        self.alignment = alignment
        self.sourceLocation = sourceLocation
    }
}

/// Table column alignment
public enum TableColumnAlignment: String, CaseIterable, Sendable {
    case none = "none"
    case left = "left"
    case center = "center"
    case right = "right"
}

// MARK: - Inline Nodes

/// Plain text content
public struct TextNode: ASTNode {
    public let nodeType: ASTNodeType = .text
    public let children: [ASTNode] = [] // Text nodes are leaf nodes
    public let sourceLocation: SourceLocation?
    public let content: String
    
    public init(content: String, sourceLocation: SourceLocation? = nil) {
        self.content = content
        self.sourceLocation = sourceLocation
    }
}

/// Emphasized text (italic)
public struct EmphasisNode: ASTNode {
    public let nodeType: ASTNodeType = .emphasis
    public let children: [ASTNode]
    public let sourceLocation: SourceLocation?
    public let delimiter: Character // '*' or '_'
    
    public init(children: [ASTNode], delimiter: Character = "*", sourceLocation: SourceLocation? = nil) {
        self.children = children
        self.delimiter = delimiter
        self.sourceLocation = sourceLocation
    }
}

/// Strong emphasis (bold)
public struct StrongEmphasisNode: ASTNode {
    public let nodeType: ASTNodeType = .strongEmphasis
    public let children: [ASTNode]
    public let sourceLocation: SourceLocation?
    public let delimiter: Character // '*' or '_'
    
    public init(children: [ASTNode], delimiter: Character = "*", sourceLocation: SourceLocation? = nil) {
        self.children = children
        self.delimiter = delimiter
        self.sourceLocation = sourceLocation
    }
}

/// Strikethrough text (GFM extension)
public struct StrikethroughNode: ASTNode {
    public let nodeType: ASTNodeType = .strikethrough
    public let children: [ASTNode]
    public let sourceLocation: SourceLocation?
    
    public init(children: [ASTNode], sourceLocation: SourceLocation? = nil) {
        self.children = children
        self.sourceLocation = sourceLocation
    }
}

/// Link with URL and optional title
public struct LinkNode: ASTNode {
    public let nodeType: ASTNodeType = .link
    public let children: [ASTNode] // Link text content
    public let sourceLocation: SourceLocation?
    public let url: String
    public let title: String?
    public let isReference: Bool // true for reference links
    public let referenceLabel: String? // for reference links
    
    public init(url: String, title: String? = nil, isReference: Bool = false, 
                referenceLabel: String? = nil, children: [ASTNode], sourceLocation: SourceLocation? = nil) {
        self.url = url
        self.title = title
        self.isReference = isReference
        self.referenceLabel = referenceLabel
        self.children = children
        self.sourceLocation = sourceLocation
    }
}

/// Image with URL, alt text, and optional title
public struct ImageNode: ASTNode {
    public let nodeType: ASTNodeType = .image
    public let children: [ASTNode] // Alt text content
    public let sourceLocation: SourceLocation?
    public let url: String
    public let title: String?
    public let isReference: Bool // true for reference images
    public let referenceLabel: String? // for reference images
    
    public init(url: String, title: String? = nil, isReference: Bool = false,
                referenceLabel: String? = nil, children: [ASTNode], sourceLocation: SourceLocation? = nil) {
        self.url = url
        self.title = title
        self.isReference = isReference
        self.referenceLabel = referenceLabel
        self.children = children
        self.sourceLocation = sourceLocation
    }
}

/// Inline code span
public struct CodeSpanNode: ASTNode {
    public let nodeType: ASTNodeType = .codeSpan
    public let children: [ASTNode] = [] // Code spans are leaf nodes
    public let sourceLocation: SourceLocation?
    public let content: String
    
    public init(content: String, sourceLocation: SourceLocation? = nil) {
        self.content = content
        self.sourceLocation = sourceLocation
    }
}

/// Inline HTML
public struct HTMLInlineNode: ASTNode {
    public let nodeType: ASTNodeType = .htmlInline
    public let children: [ASTNode] = [] // HTML inline nodes are leaf nodes
    public let sourceLocation: SourceLocation?
    public let content: String
    
    public init(content: String, sourceLocation: SourceLocation? = nil) {
        self.content = content
        self.sourceLocation = sourceLocation
    }
}

/// Hard line break
public struct LineBreakNode: ASTNode {
    public let nodeType: ASTNodeType = .lineBreak
    public let children: [ASTNode] = [] // Line breaks are leaf nodes
    public let sourceLocation: SourceLocation?
    public let isHard: Bool // true for hard breaks, false for soft breaks
    
    public init(isHard: Bool = true, sourceLocation: SourceLocation? = nil) {
        self.isHard = isHard
        self.sourceLocation = sourceLocation
    }
}

/// Soft line break
public struct SoftBreakNode: ASTNode {
    public let nodeType: ASTNodeType = .softBreak
    public let children: [ASTNode] = [] // Soft breaks are leaf nodes
    public let sourceLocation: SourceLocation?
    
    public init(sourceLocation: SourceLocation? = nil) {
        self.sourceLocation = sourceLocation
    }
}

// MARK: - GFM Extension Nodes

/// Task list item (GFM extension)
public struct TaskListItemNode: ASTNode {
    public let nodeType: ASTNodeType = .taskListItem
    public let children: [ASTNode]
    public let sourceLocation: SourceLocation?
    public let isChecked: Bool
    
    public init(isChecked: Bool, children: [ASTNode], sourceLocation: SourceLocation? = nil) {
        self.isChecked = isChecked
        self.children = children
        self.sourceLocation = sourceLocation
    }
}

/// Autolink (GFM extension)
public struct AutolinkNode: ASTNode {
    public let nodeType: ASTNodeType = .autolink
    public let children: [ASTNode] = [] // Autolinks are leaf nodes
    public let sourceLocation: SourceLocation?
    public let url: String
    public let linkType: AutolinkType
    
    public init(url: String, linkType: AutolinkType, sourceLocation: SourceLocation? = nil) {
        self.url = url
        self.linkType = linkType
        self.sourceLocation = sourceLocation
    }
}

/// Autolink types
public enum AutolinkType: String, CaseIterable, Sendable {
    case url = "url"
    case email = "email"
    case www = "www"       // www.example.com
    case `protocol` = "protocol" // http://example.com
} 