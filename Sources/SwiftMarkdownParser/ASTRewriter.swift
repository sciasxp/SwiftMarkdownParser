public import Foundation

/// A container node that can rebuild itself after its children are rewritten.
///
/// Existing `ASTNode` conformances remain valid. Custom nodes with descendants
/// adopt this protocol only when they want descendant rewriting support.
public protocol ASTRewritableNode: ASTNode {
    /// Reconstructs the same logical container with a new ordered child list.
    /// Implementations preserve their non-child metadata or throw when the
    /// supplied children violate a typed structural invariant.
    func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode
}

/// The one-shot action applied to a visited node during rewriting.
public enum ASTRewrite: Sendable {
    /// Retain the node, including any already-rewritten descendants.
    case keep

    /// Remove the node from its parent.
    case remove

    /// Replace the node with one node. The replacement is not revisited.
    case replace(any ASTNode)

    /// Replace the node with zero or more sibling nodes. Replacements are not revisited.
    case replaceMany([any ASTNode])
}

/// Structural errors produced by AST rewriting.
public enum ASTRewriteError: Error, LocalizedError, Sendable, Equatable {
    case invalidDocumentRoot(actual: [ASTNodeType])
    case nonRewritableContainer(ASTNodeType)
    case invalidChildType(parent: ASTNodeType, expected: ASTNodeType, actual: ASTNodeType)

    public var errorDescription: String? {
        switch self {
        case .invalidDocumentRoot(let actual):
            let types = actual.map(\.rawValue).joined(separator: ", ")
            return "AST rewriting must produce exactly one document root; produced [\(types)]."
        case .nonRewritableContainer(let type):
            return "The custom \(type.rawValue) container does not support descendant rewriting."
        case .invalidChildType(let parent, let expected, let actual):
            return "The \(parent.rawValue) node requires \(expected.rawValue) children, not \(actual.rawValue)."
        }
    }
}

public extension AST.DocumentNode {
    /// Rewrites this document bottom-up in one deterministic pass.
    ///
    /// Every visit observes descendants already rewritten by the same pass.
    /// `ancestors` describe the node's position in the original document.
    /// Replacement nodes are inserted as supplied and are not visited again.
    func rewriting(
        _ transform: (ASTTraversal.Element) throws -> ASTRewrite
    ) throws -> AST.DocumentNode {
        let result = try ASTRewriter.rewrite(
            node: self,
            ancestors: [],
            path: [],
            transform: transform
        )

        guard result.nodes.count == 1,
              let document = result.nodes.first as? AST.DocumentNode else {
            throw ASTRewriteError.invalidDocumentRoot(actual: result.nodes.map(\.nodeType))
        }
        return document
    }
}

private enum ASTRewriter {
    struct Result {
        let nodes: [any ASTNode]
        let changed: Bool
    }

    static func rewrite(
        node: any ASTNode,
        ancestors: [any ASTNode],
        path: [Int],
        transform: (ASTTraversal.Element) throws -> ASTRewrite
    ) throws -> Result {
        var rewrittenChildren: [any ASTNode] = []
        var descendantsChanged = false

        for (index, child) in node.children.enumerated() {
            let result = try rewrite(
                node: child,
                ancestors: ancestors + [node],
                path: path + [index],
                transform: transform
            )
            rewrittenChildren.append(contentsOf: result.nodes)
            descendantsChanged = descendantsChanged || result.changed
        }

        let currentNode: any ASTNode
        if descendantsChanged {
            guard let container = node as? any ASTRewritableNode else {
                throw ASTRewriteError.nonRewritableContainer(node.nodeType)
            }
            currentNode = try container.replacingChildren(with: rewrittenChildren)
        } else {
            currentNode = node
        }

        let visit = ASTTraversal.Element(
            node: currentNode,
            ancestors: ancestors,
            path: path
        )

        switch try transform(visit) {
        case .keep:
            return Result(nodes: [currentNode], changed: descendantsChanged)
        case .remove:
            return Result(nodes: [], changed: true)
        case .replace(let replacement):
            return Result(nodes: [replacement], changed: true)
        case .replaceMany(let replacements):
            return Result(nodes: replacements, changed: true)
        }
    }
}

// MARK: - Built-in container reconstruction

extension AST.DocumentNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.DocumentNode(children: children, sourceLocation: sourceLocation)
    }
}

extension AST.ParagraphNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.ParagraphNode(children: children, sourceLocation: sourceLocation)
    }
}

extension AST.HeadingNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.HeadingNode(level: level, children: children, sourceLocation: sourceLocation)
    }
}

extension AST.BlockQuoteNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.BlockQuoteNode(children: children, sourceLocation: sourceLocation)
    }
}

extension AST.ListNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.ListNode(
            isOrdered: isOrdered,
            startNumber: startNumber,
            items: children,
            sourceLocation: sourceLocation
        )
    }
}

extension AST.ListItemNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.ListItemNode(children: children, sourceLocation: sourceLocation)
    }
}

extension AST.EmphasisNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.EmphasisNode(children: children, sourceLocation: sourceLocation)
    }
}

extension AST.StrongEmphasisNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.StrongEmphasisNode(children: children, sourceLocation: sourceLocation)
    }
}

extension AST.LinkNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.LinkNode(
            url: url,
            title: title,
            children: children,
            sourceLocation: sourceLocation
        )
    }
}

extension AST.StrikethroughNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.StrikethroughNode(content: children, sourceLocation: sourceLocation)
    }
}

extension AST.GFMTaskListItemNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.GFMTaskListItemNode(
            isChecked: isChecked,
            children: children,
            sourceLocation: sourceLocation
        )
    }
}

extension AST.GFMTableNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        let rows: [AST.GFMTableRowNode] = try requireChildren(
            children,
            parent: .table,
            expected: .tableRow
        )
        return AST.GFMTableNode(
            rows: rows,
            alignments: alignments,
            sourceLocation: sourceLocation
        )
    }
}

extension AST.GFMTableRowNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        let cells: [AST.GFMTableCellNode] = try requireChildren(
            children,
            parent: .tableRow,
            expected: .tableCell
        )
        return AST.GFMTableRowNode(
            cells: cells,
            isHeader: isHeader,
            sourceLocation: sourceLocation
        )
    }
}

extension AST.GFMTableCellNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.GFMTableCellNode(
            children: children,
            isHeader: isHeader,
            alignment: alignment,
            sourceLocation: sourceLocation
        )
    }
}

extension AST.FragmentNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.FragmentNode(children: children, sourceLocation: sourceLocation)
    }
}

extension AST.FootnoteDefinitionNode: ASTRewritableNode {
    public func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        AST.FootnoteDefinitionNode(
            identifier: identifier,
            children: children,
            sourceLocation: sourceLocation
        )
    }
}

private func requireChildren<T: ASTNode>(
    _ children: [any ASTNode],
    parent: ASTNodeType,
    expected: ASTNodeType
) throws -> [T] {
    try children.map { child in
        guard let typedChild = child as? T else {
            throw ASTRewriteError.invalidChildType(
                parent: parent,
                expected: expected,
                actual: child.nodeType
            )
        }
        return typedChild
    }
}
