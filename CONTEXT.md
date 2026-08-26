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
