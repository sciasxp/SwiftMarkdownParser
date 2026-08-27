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

**Output Renderer**:
The interpretation of a complete Markdown Document into one presentation format, with that format's rules kept together.
_Avoid_: Shared rendering pipeline, render context

**Native Inline Projection**:
The SwiftUI-output interpretation of inline Markdown meaning into an ordered native presentation independent of its containing block, preserving styles, safe destinations, breaks, references, and rich-content requirements without silently discarding unsupported meaning.
_Avoid_: Inline rendering pipeline, text flattening

**Atomic Native Document Projection**:
The complete depth-first interpretation and validation of one Markdown Document before native identity, view materialization, rich-content adaptation, or other output work begins.
_Avoid_: Incremental node rendering, partial native output

**Native Presentation Semantics**:
The package-owned interpretation of native-output roles into deferred localized messages and pure presentation values, keeping VoiceOver meaning, visible fallback labels, errors, ordered markers, and code-token continuity consistent across SwiftUI modules.
_Avoid_: Hardcoded accessibility copy, localization helper bag

**Native View Materialization**:
The one-time conversion of projected native content into unary SwiftUI views with renderer-owned stable identity and centralized type erasure, completed before any view body evaluates.
_Avoid_: UUID in body, caller-owned AnyView wrapping

**Native Rich Content Seam**:
The SwiftUI-output seam where one host adapter may materialize a validated rich-content request or decline it. Image destination resolution and rejection belong to this seam; native links remain Native Inline Projection meaning, and declined or invalid rich content retains a readable accessible fallback.
_Avoid_: Rich-content handler bag, per-node closure bundle

**Native Adaptive Presentation**:
The SwiftUI-output interpretation of projected block content into container-aware native forms, choosing layout from available space and accessibility text size while preserving document order, labels, alignment, and host-provided content.
_Avoid_: Device-specific layout, screen-size branching

**Native Adaptive Label/Content**:
The native presentation relationship between one role-bearing label and its content, choosing axis, spacing, alignment, and content reservation from available space and accessibility text size while preserving semantic ownership and reading order.
_Avoid_: Per-caller label thresholds, visual label as accessibility meaning

**HTML Output**:
The browser-oriented representation of a Markdown Document, either as an embeddable fragment or a complete document.
_Avoid_: Rendered page, WebView content

**Browser Enrichment**:
The browser behavior and resources required to activate features present in HTML Output, added only when the document needs them.
_Avoid_: Script injection, global asset bundle

**Semantic Highlighting**:
The optional interpretation of code as ordered semantic tokens whose ranges belong to that exact code source.
_Avoid_: HTML highlighting, syntax-engine output
