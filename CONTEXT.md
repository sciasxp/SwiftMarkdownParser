# SwiftMarkdownParser

SwiftMarkdownParser interprets Markdown source as a semantic document that can be rendered or analyzed consistently.

## Language

**Markdown Source**:
Text written in the Supported Dialect and submitted for interpretation.
_Avoid_: Raw document, input blob

**Source Text**:
The characters of one Markdown Source together with its lines, the single authority on what ends a line (LF, CR, or CRLF only) and on the line, column, and character offset of every position.
_Avoid_: Raw string scanning, newline helper

**Destination**:
The target of one link, image, or autolink, decided once for every output: safe only when, after normalizing as browsers do, it names http, https, or mailto or is a relative reference or fragment, and resolved against the host's base URL into the one URL it represents.
_Avoid_: URL normalization, renderer-specific URL check

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
The SwiftUI-output interpretation of inline Markdown meaning into an ordered native presentation independent of its containing block, preserving styles, Destinations, breaks, references, and rich-content requirements without silently discarding unsupported meaning.
_Avoid_: Inline rendering pipeline, text flattening

**Atomic Native Document Projection**:
The complete depth-first interpretation and validation of one Markdown Document before native identity, view materialization, rich-content adaptation, or other output work begins.
_Avoid_: Incremental node rendering, partial native output

**Native Table Projection**:
The one-time SwiftUI-output normalization of a GFM table into canonical columns with optional headers and alignment plus ordered data rows, completed inside Atomic Native Document Projection before materialization or adaptive presentation.
_Avoid_: Layout-time header discovery, cell-owned column alignment

**Native Presentation Semantics**:
The package-owned interpretation of native-output roles into deferred localized messages and pure presentation values, keeping VoiceOver meaning, visible fallback labels, errors, ordered markers, and code-token continuity consistent across SwiftUI modules.
_Avoid_: Hardcoded accessibility copy, localization helper bag

**Native View Materialization**:
The one-time conversion of projected native content into unary SwiftUI views with renderer-owned stable identity and centralized type erasure, completed before any view body evaluates.
_Avoid_: UUID in body, caller-owned AnyView wrapping

**Native Rich Content Seam**:
The SwiftUI-output seam where one host adapter may materialize a validated rich-content request or decline it. Only images whose Destination is safe become requests; native links remain Native Inline Projection meaning, and declined or invalid rich content retains a readable accessible fallback.
_Avoid_: Rich-content handler bag, per-node closure bundle

**Native Adaptive Presentation**:
The SwiftUI-output interpretation of projected block content into container-aware native forms, choosing layout from available space and accessibility text size while preserving document order, labels, alignment, and host-provided content.
_Avoid_: Device-specific layout, screen-size branching

**Native Presentation Style**:
The immutable, role-oriented interpretation of the public SwiftUI style configuration, materialized once per renderer with normalized metrics, so every native module receives the fonts, colors, spacing, and label/content geometry contracts of the role it presents.
_Avoid_: Passing the public configuration through views, per-view metric arithmetic

**Native Adaptive Label/Content**:
The native presentation relationship between one label and its content, applying the axis preference, spacing, alignment, and content reservation supplied by Native Presentation Style to the available space and accessibility text size while preserving semantic ownership and reading order.
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
