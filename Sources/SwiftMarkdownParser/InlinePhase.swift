/// Raw inline text recorded by the Block Phase: the characters of one inline
/// fragment and the location of its first character.
struct InlineSource {
    let text: String
    let start: SourceLocation
}

/// The Inline Phase of document construction: interprets the inline text of
/// every block the Block Phase recognized, after the whole block structure,
/// and so every Link Reference Definition, is known.
struct InlinePhase {
    let budget: ParsingBudget
    let linkReferences: [String: LinkReference]
    let maximumNestingDepth: Int

    func document(from blocks: [ParsedBlock], range: SourceLocation) throws -> AST.DocumentNode {
        AST.DocumentNode(children: try blocks.map(node), sourceLocation: range)
    }

    private func node(_ block: ParsedBlock) throws -> any ASTNode {
        switch block {
        case let .paragraph(content, range):
            return AST.ParagraphNode(children: try inlines(content), sourceLocation: range)

        case let .heading(level, content, range):
            return AST.HeadingNode(level: level, children: try inlines(content), sourceLocation: range)

        case let .blockQuote(children, range):
            return AST.BlockQuoteNode(children: try children.map(node), sourceLocation: range)

        case let .list(isOrdered, startNumber, items, range):
            return AST.ListNode(
                isOrdered: isOrdered,
                startNumber: startNumber,
                items: try items.map(node),
                sourceLocation: range
            )

        case let .listItem(taskIsChecked, children, range):
            let children = try children.map(node)
            guard let taskIsChecked else {
                return AST.ListItemNode(children: children, sourceLocation: range)
            }
            var taskChildren = children
            if let paragraph = children.first as? AST.ParagraphNode {
                taskChildren = paragraph.children + children.dropFirst()
            }
            return AST.GFMTaskListItemNode(isChecked: taskIsChecked, children: taskChildren, sourceLocation: range)

        case let .table(rows, alignments, range):
            return AST.GFMTableNode(
                rows: try rows.map { row in
                    AST.GFMTableRowNode(
                        cells: try row.cells.map(cell),
                        isHeader: row.isHeader,
                        sourceLocation: row.range
                    )
                },
                alignments: alignments,
                sourceLocation: range
            )

        case let .complete(node):
            return node
        }
    }

    private func cell(_ cell: ParsedTableCell) throws -> AST.GFMTableCellNode {
        let text = cell.content.text
        let children: [any ASTNode]
        if text.isEmpty {
            children = []
        } else if needsInlineParsing(text) {
            children = try inlines(cell.content)
        } else {
            children = [AST.TextNode(content: text, sourceLocation: cell.range)]
        }
        return AST.GFMTableCellNode(
            children: children,
            isHeader: cell.isHeader,
            alignment: cell.alignment,
            sourceLocation: cell.range
        )
    }

    private func inlines(_ source: InlineSource) throws -> [any ASTNode] {
        guard !source.text.isEmpty else { return [] }
        return try InlineParser.parse(
            source,
            budget: budget,
            linkReferences: linkReferences,
            maximumNestingDepth: maximumNestingDepth
        )
    }

    private func needsInlineParsing(_ source: String) -> Bool {
        source.contains { "*_`[!~$\\&<".contains($0) } ||
            source.contains("http://") ||
            source.contains("https://") ||
            source.contains("www.") ||
            source.contains("@")
    }
}
