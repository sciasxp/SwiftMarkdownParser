enum MarkdownDocumentValidator {
    static func validate(_ document: AST.DocumentNode, sourceLength: Int) throws {
        try validateNode(document, parentRange: nil, sourceLength: sourceLength)
    }

    private static func validateNode(
        _ node: ASTNode,
        parentRange: SourceLocation?,
        sourceLength: Int
    ) throws {
        guard !(node is AST.FragmentNode) else {
            throw MarkdownParsingError.internalInvariant(
                message: "A temporary fragment escaped document construction.",
                location: node.sourceLocation
            )
        }
        guard let range = node.sourceLocation else {
            throw MarkdownParsingError.internalInvariant(
                message: "A parser-produced \(node.nodeType.rawValue) node has no source range.",
                location: parentRange
            )
        }
        guard range.offset >= 0,
              range.endOffset >= range.offset,
              range.endOffset <= sourceLength else {
            throw MarkdownParsingError.internalInvariant(
                message: "A \(node.nodeType.rawValue) node has an invalid source range.",
                location: range
            )
        }
        if let parentRange {
            guard range.offset >= parentRange.offset,
                  range.endOffset <= parentRange.endOffset else {
                throw MarkdownParsingError.internalInvariant(
                    message: "A \(node.nodeType.rawValue) node escapes its parent source range.",
                    location: range
                )
            }
        }

        for child in node.children {
            try validateNode(child, parentRange: range, sourceLength: sourceLength)
        }
    }
}
