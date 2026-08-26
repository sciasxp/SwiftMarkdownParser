# SwiftMarkdownParser

SwiftMarkdownParser interprets Markdown source as a semantic document that can be rendered or analyzed consistently.

## Language

**Markdown Source**:
Text written in the Supported Dialect and submitted for interpretation.
_Avoid_: Raw document, input blob

**Markdown Document**:
The complete semantic interpretation of one Markdown Source, with all recognized block, inline, and reference meaning resolved.
_Avoid_: Partial document, staged document

**Supported Dialect**:
The single Markdown language recognized by the product: CommonMark 0.30, GitHub Flavored Markdown, math expressions, and Mermaid fenced diagrams.
_Avoid_: Strict mode, optional GFM mode, pluggable grammar

**AST Traversal**:
A lazy depth-first preorder view of a node tree, including the root and stable ancestry, path, and depth context.
_Avoid_: Visitor framework, recursive walker

**AST Rewrite**:
One immutable, bottom-up pass that can retain, remove, replace, or expand nodes while preserving built-in node metadata.
_Avoid_: Mutable AST, rewrite pipeline
