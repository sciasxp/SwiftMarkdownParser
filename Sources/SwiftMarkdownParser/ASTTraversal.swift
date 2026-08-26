/// A lazy, depth-first preorder traversal of an AST.
///
/// The root is the first element. Children follow in their stored order.
/// Traversal is immutable and keeps only the pending traversal stack plus the
/// ancestry of pending nodes.
public struct ASTTraversal: Sequence, Sendable {
    /// One node and its stable position in the traversed tree.
    public struct Element: Sendable {
        public let node: ASTNode
        public let ancestors: [ASTNode]
        public let path: [Int]

        /// The immediate parent, or `nil` for the root.
        public var parent: ASTNode? { ancestors.last }

        /// The node depth, where the root has depth zero.
        public var depth: Int { path.count }

        init(node: ASTNode, ancestors: [ASTNode], path: [Int]) {
            self.node = node
            self.ancestors = ancestors
            self.path = path
        }
    }

    public struct Iterator: IteratorProtocol {
        private var pending: [Element]

        init(root: ASTNode) {
            self.pending = [Element(node: root, ancestors: [], path: [])]
        }

        public mutating func next() -> Element? {
            guard let current = pending.popLast() else { return nil }

            let ancestors = current.ancestors + [current.node]
            for (index, child) in current.node.children.enumerated().reversed() {
                pending.append(Element(
                    node: child,
                    ancestors: ancestors,
                    path: current.path + [index]
                ))
            }

            return current
        }
    }

    private let root: ASTNode

    init(root: ASTNode) {
        self.root = root
    }

    public func makeIterator() -> Iterator {
        Iterator(root: root)
    }
}

public extension ASTNode {
    /// Traverses this node and its descendants in depth-first preorder.
    func depthFirst() -> ASTTraversal {
        ASTTraversal(root: self)
    }
}
