@testable import SwiftMarkdownParser

/// A mock ASTNode type that the HTMLRenderer does not handle.
/// Defined in a separate file (without `import Testing`) to avoid the
/// SourceLocation ambiguity between Testing.SourceLocation and
/// SwiftMarkdownParser.SourceLocation.
struct UnsupportedTestNode: ASTNode {
    let nodeType: ASTNodeType = .text
    let children: [ASTNode] = []
    let sourceLocation: SourceLocation? = nil
}

struct UnsupportedSwiftUITestNode: ASTNode {
    let nodeType = ASTNodeType(rawValue: "unsupported-swiftui")
    let children: [ASTNode] = []
    let sourceLocation: SourceLocation? = nil
}

struct RewritableTestContainer: ASTRewritableNode {
    let nodeType = ASTNodeType(rawValue: "rewritableTestContainer")
    let children: [ASTNode]
    let sourceLocation: SourceLocation? = nil

    func replacingChildren(with children: [ASTNode]) throws -> ASTNode {
        RewritableTestContainer(children: children)
    }
}

struct ReadOnlyTestContainer: ASTNode {
    let nodeType = ASTNodeType(rawValue: "readOnlyTestContainer")
    let children: [ASTNode]
    let sourceLocation: SourceLocation? = nil
}

/// Creates a SourceLocation without ambiguity (no Testing import here).
func makeTestSourceLocation(line: Int, column: Int, offset: Int) -> SourceLocation {
    SourceLocation(line: line, column: column, offset: offset)
}
