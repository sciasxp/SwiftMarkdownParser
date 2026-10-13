@testable import SwiftMarkdownParser

/// A mock ASTNode type that the HTMLRenderer does not handle.
/// Defined in a separate file (without `import Testing`) to avoid the
/// SourceLocation ambiguity between Testing.SourceLocation and
/// SwiftMarkdownParser.SourceLocation.
struct UnsupportedTestNode: ASTNode {
    let nodeType: ASTNodeType = .text
    let children: [any ASTNode] = []
    let sourceLocation: SourceLocation? = nil
}

struct UnsupportedSwiftUITestNode: ASTNode {
    let nodeType: ASTNodeType
    let children: [any ASTNode] = []
    let sourceLocation: SourceLocation? = nil

    init(_ rawValue: String = "unsupported-swiftui") {
        self.nodeType = ASTNodeType(rawValue: rawValue)
    }
}

struct RewritableTestContainer: ASTRewritableNode {
    let nodeType = ASTNodeType(rawValue: "rewritableTestContainer")
    let children: [any ASTNode]
    let sourceLocation: SourceLocation? = nil

    func replacingChildren(with children: [any ASTNode]) throws -> any ASTNode {
        RewritableTestContainer(children: children)
    }
}

struct ReadOnlyTestContainer: ASTNode {
    let nodeType = ASTNodeType(rawValue: "readOnlyTestContainer")
    let children: [any ASTNode]
    let sourceLocation: SourceLocation? = nil
}

/// Creates a SourceLocation without ambiguity (no Testing import here).
func makeTestSourceLocation(line: Int, column: Int, offset: Int) -> SourceLocation {
    SourceLocation(line: line, column: column, offset: offset)
}

/// Builds a source position without naming `SourceLocation` in files that
/// import Testing, where the name is ambiguous.
func sourcePosition(line: Int, column: Int, offset: Int) -> SourceLocation {
    SourceLocation(line: line, column: column, offset: offset)
}

/// Unambiguous name for `SourceLocation` in files that import Testing.
typealias MarkdownSourceLocation = SourceLocation
