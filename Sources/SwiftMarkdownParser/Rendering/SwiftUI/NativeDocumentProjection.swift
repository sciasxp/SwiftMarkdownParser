import Foundation

/// Owns complete native-output interpretation and validation before any output work begins.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
struct NativeDocumentProjection {
    struct Plan {
        let blocks: [Block]
    }

    indirect enum Block {
        case inline(NativeInlinePlan)
        case paragraph(NativeInlinePlan)
        case heading(level: Int, content: NativeInlinePlan)
        case codeBlock(AST.CodeBlockNode)
        case list(List)
        case content([Block])
        case blockQuote([Block])
        case thematicBreak
        case rich(NativeRichContentProjection.Request)
        case task(isChecked: Bool, content: NativeInlinePlan)
        case table(Table)
        case footnote(identifier: String, children: [Block])
    }

    struct List {
        struct Item {
            let isTask: Bool
            let content: Block
        }

        let isOrdered: Bool
        let startNumber: Int?
        let items: [Item]
    }

    struct Table {
        struct Row {
            let isHeader: Bool
            let cells: [Cell]
        }

        struct Cell {
            let content: NativeInlinePlan
            let alignment: GFMTableAlignment
            let columnIndex: Int
        }

        let rows: [Row]
    }

    private let baseURL: URL?
    private let mermaidConfiguration: MermaidConfiguration

    init(options: SwiftUIRenderOptions) {
        self.baseURL = options.baseURL
        self.mermaidConfiguration = options.mermaidConfiguration
    }

    /// Interprets the complete document or fails before identity, views, or adapters exist.
    func project(_ document: AST.DocumentNode) throws -> Plan {
        Plan(blocks: try document.children.map(project))
    }

    private func project(_ node: any ASTNode) throws -> Block {
        switch node {
        case is AST.TextNode,
             is AST.EmphasisNode,
             is AST.StrongEmphasisNode,
             is AST.LinkNode,
             is AST.ImageNode,
             is AST.CodeSpanNode,
             is AST.LineBreakNode,
             is AST.SoftBreakNode,
             is AST.AutolinkNode,
             is AST.HTMLInlineNode,
             is AST.StrikethroughNode,
             is AST.FootnoteReferenceNode,
             is AST.InlineMathNode:
            return .inline(try inlinePlan([node]))

        case let paragraph as AST.ParagraphNode:
            return .paragraph(try inlinePlan(paragraph.children))
        case let heading as AST.HeadingNode:
            return .heading(level: heading.level, content: try inlinePlan(heading.children))
        case let codeBlock as AST.CodeBlockNode:
            return .codeBlock(codeBlock)
        case let list as AST.ListNode:
            return .list(.init(
                isOrdered: list.isOrdered,
                startNumber: list.startNumber,
                items: try list.items.map { item in
                    List.Item(isTask: item is AST.GFMTaskListItemNode, content: try project(item))
                }
            ))
        case let listItem as AST.ListItemNode:
            return .content(try listItem.children.map(project))
        case let blockQuote as AST.BlockQuoteNode:
            return .blockQuote(try blockQuote.children.map(project))
        case is AST.ThematicBreakNode:
            return .thematicBreak
        case let htmlBlock as AST.HTMLBlockNode:
            return .rich(.htmlBlock(htmlBlock))
        case let task as AST.GFMTaskListItemNode:
            return .task(isChecked: task.isChecked, content: try inlinePlan(task.children))
        case let table as AST.GFMTableNode:
            return .table(try tablePlan(table))
        case let footnote as AST.FootnoteDefinitionNode:
            return .footnote(
                identifier: footnote.identifier,
                children: try footnote.children.map(project)
            )
        case let mermaid as AST.MermaidDiagramNode:
            return .rich(.mermaid(node: mermaid, configuration: mermaidConfiguration))
        case let mathBlock as AST.MathBlockNode:
            return .rich(.mathBlock(mathBlock))
        default:
            throw SwiftUIRenderingError.unsupportedNodeType(node.nodeType)
        }
    }

    private func inlinePlan(_ nodes: [any ASTNode]) throws -> NativeInlinePlan {
        try NativeInlinePlan(nodes: nodes, baseURL: baseURL)
    }

    private func tablePlan(_ table: AST.GFMTableNode) throws -> Table {
        let rows = try table.rows.map { row in
            let cells = try row.cells.enumerated().map { index, cell in
                let nodes: [any ASTNode] = cell.children.isEmpty
                    ? [AST.TextNode(content: cell.content)]
                    : cell.children
                return Table.Cell(
                    content: try inlinePlan(nodes),
                    alignment: index < table.alignments.count ? table.alignments[index] : .none,
                    columnIndex: index
                )
            }
            return Table.Row(isHeader: row.isHeader, cells: cells)
        }
        return Table(rows: rows)
    }
}
