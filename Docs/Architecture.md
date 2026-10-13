# Architecture

SwiftMarkdownParser is organized around a small set of deep modules. Each
public interface accepts or returns a complete semantic value, while parsing,
rewriting, output rules, browser enrichment, and syntax adapter selection stay
local to the module that owns them.

## End-to-end flow

```text
Markdown Source
    |
    v
SwiftMarkdownParser.parse(_:)
    |
    v
complete AST.DocumentNode
    |--------------------|----------------------|
    v                    v                      v
depthFirst() /       HTMLRenderer          SwiftUIRenderer
rewriting(_:)            |                      |
                         v                      v
                 HTML fragment/document       AnyView
                         |
                         v
                 MarkdownWebView (macOS)
```

`AST.DocumentNode` is the shared semantic value. Parsing never returns a
partial document, and renderers never accept Markdown source. This keeps
construction, analysis, transformation, and presentation independently
replaceable at explicit seams.

## Public modules

| Module | Interface | What it owns |
| --- | --- | --- |
| Markdown Document construction | `SwiftMarkdownParser.parse(_:)` | Token recognition, block and inline construction, reference resolution, source ranges, validation, and deterministic resource limits |
| AST Traversal | `ASTNode.depthFirst()` | Lazy preorder visits with stable ancestry, path, parent, and depth context |
| AST Rewrite | `AST.DocumentNode.rewriting(_:)` | One bottom-up immutable pass, metadata preservation, and typed-child validation |
| Syntax Highlighting | `SyntaxHighlighter.highlight(_:language:)` | Built-in adapter selection, aliases, support discovery, token validation, best-effort fallback, and bounded LRU caching |
| HTML Output | `HTMLRenderer.renderFragment(_:)` and `renderDocument(_:assembly:)` | HTML escaping, GFM output, semantic code spans, feature discovery, browser assets, host styles/scripts/regions, bootstrap behavior, and document composition |
| Native SwiftUI Output | `SwiftUIRenderer.render(_:)` | Main-actor semantic projection plus container-aware native presentation from the completed document |
| WebKit Presentation | `MarkdownWebView` | Loading complete HTML and reporting semantic browser-runtime readiness or failure |

The deletion test explains the depth of each module: removing one would force
its policy back into multiple callers or tests rather than making the policy
disappear.

## HTML and browser enrichment

HTML body rendering discovers the browser behavior actually required by the
document: Mermaid, KaTeX, footnote navigation, and task-list interaction.
`BrowserDocumentAssembler` then adds the required resources exactly once,
places them in the correct part of a fragment or complete document, and emits
one readiness/failure bootstrap.

For complete documents, `HTMLDocumentAssembly` is the structured host interface for
metadata, trusted styles, trusted scripts, and addressable marker regions. The internal
assembler validates and projects those regions in the rendered body, then emits the
head and body once. Hosts do not patch completed HTML or duplicate shell placement.

Mermaid and KaTeX resources can be bundled, loaded from pinned CDN versions,
or supplied through validated custom URLs. Bundled resources are inlined for
deterministic offline output. Configuration values remain data; they do not
assemble scripts or styles themselves.

## Syntax highlighting

`SyntaxHighlighter` is an actor because adapter work and its cache share mutable
state. Callers provide code and a language identifier and receive optional,
sorted, non-overlapping semantic tokens. Unsupported identifiers or adapter
failures return `nil`, which lets output renderers preserve the original code as
plain escaped text.

The six language adapters are internal. `HTMLCodeBlockRenderer` translates
tokens into escaped semantic `<span>` elements and preserves every unclassified
gap. Keeping semantic classification separate from HTML presentation lets the
same public highlighting interface serve non-HTML callers without exposing the
adapter registry or cache representation.

## Native SwiftUI presentation

`SwiftUIRenderer` delegates eight independent forms of native output policy.
`NativePresentationStyle` materializes the public `SwiftUIStyleConfiguration`
once per renderer into immutable, role-oriented values (document, inline,
paragraph, heading, code block, quote, list, task, table, image, and thematic
break). It normalizes non-finite or negative metrics and owns every
label/content geometry contract, so native modules receive only the role value
they present and never read the public configuration directly.
`NativeDocumentProjection` first interprets and validates the complete document
into a typed, one-shot plan in deterministic depth-first order. The plan embeds
`NativeInlinePlan` values and rich-content requests, but contains no views,
identity, adapter results, or syntax-highlighting work. Its table projection
normalizes the first row into optional column headers, resolves alignment from
the table's column schema once, and preserves every remaining row and cell in
order. Cell-level header and alignment fields remain AST compatibility data;
presentation modules never reconcile them.
`NativePresentationSemantics` maps typed roles to deferred package-localized
meaning and owns pure ordered-marker and code-token continuity decisions.
`NativeViewMaterializer` assigns stable unary view identity and centralizes
internal type erasure. `NativeInlineProjection` materializes already-planned
ordered inline meaning while leaving image destination policy outside its seam.
`NativeRichContentProjection` resolves and validates image destinations,
projects image, Mermaid, math, and HTML requests through one optional host
adapter, and owns their readable native fallbacks. `NativeAdaptivePresentation`
then presents materialized blocks according to the container proposal and
Dynamic Type category. Inside that presentation seam,
`NativeAdaptiveLabelContent` owns the relationship between one label and its
content for list markers, tasks, footnotes, Mermaid fallbacks, and stacked
table fields. It applies the `NativeAdaptiveLabelContentMetrics` supplied by the
owning `NativePresentationStyle` role and hides axis selection, finite
geometry, baseline fallback, and right-to-left placement. The style, not the
layout, decides each relationship's spacing, content reservation, alignment,
and Dynamic Type axis preference.

Only after document projection succeeds does the renderer materialize blocks,
invoke host adapters, assign identity, or request syntax highlighting.
Materialization is asynchronous but nonthrowing. This makes a failed document
atomic at the native output seam: no partial view graph or host-visible adapter
effect escapes, and the first unsupported node in depth-first order wins. The
temporary plan is proportional to the document and is discarded after one
render.

The adaptive presentation module owns document laziness, decoration budgets,
accessible footnotes, task rows, Mermaid fallback composition, and the choice
between a dense table grid and labeled rows. It consumes canonical columns and
data rows; it does not search for a header, partition rows, or choose between
table-level and cell-level alignment. The adaptive label/content module owns
the repeated pair geometry without interpreting accessibility copy, Markdown
meaning, or style policy. Neither inspects device models, screen bounds, or host window state.
The rich-content module resolves and validates image destinations before they
cross the host seam, invokes the adapter at most once per request, and treats
`nil` as a decision to preserve the native fallback. Alternative layouts reuse
the already projected content instead of reinvoking the adapter.

The semantic module is an in-process dependency shared by the renderer and both
presentation modules. Its localization resources live in the package bundle,
use English as the source language, and include Brazilian Portuguese. Markdown
source, identifiers, programming-language names, and diagram types remain
verbatim values inside translator-reorderable messages.

The materialization module is main-actor confined and shared by the native
modules belonging to one renderer. It allocates cheap monotonic identities
outside `body`, preserves identity while applying styles or links, and exposes a
concrete unary `NativeMaterializedView` to every `ForEach`. `AnyView` remains
localized inside that module, at the public renderer return, and at the host
rich-content adapter seam.

## Extension rules

- Change Markdown semantics inside document construction and verify them from
  Markdown Source to complete `AST.DocumentNode`.
- Implement generic analysis with `depthFirst()` and transformations with one
  `rewriting(_:)` pass instead of adding recursive walkers to callers.
- Keep output-specific behavior inside its renderer. Do not introduce a shared
  renderer interface unless behavior truly varies through two adapters.
- Add a built-in highlighting language through an internal adapter and module
  tests. The public interface intentionally does not accept caller-registered
  engines.
- Add browser behavior by discovering a requirement during HTML body rendering,
  assembling its assets centrally, and extending readiness/failure tests.
- Add native rich content by extending `SwiftUIRichContentRequest` and its
  centralized fallback together. Do not add a parallel per-node handler or
  bypass destination validation.
- Add native AST interpretation through `NativeDocumentProjection` and include
  its inline meaning in the typed plan. Never interleave document validation
  with view materialization, identity allocation, adapter effects, or syntax
  highlighting.
- Extend native table meaning inside `NativeDocumentProjection.Table`. Keep
  column headers and alignment canonical there; adaptive presentation must not
  inspect AST header flags or reconstruct the table schema.
- Add native user-facing meaning as a typed
  `NativePresentationSemantics.Message` and translate it in the package string
  catalog. Do not assemble localized sentences in a view.
- Add a native label/content relationship by giving the owning role in
  `NativePresentationStyle` a `NativeAdaptiveLabelContentMetrics` value
  (spacing, minimum content width, standard/accessibility axis preference, and
  alignment) and passing it to `NativeAdaptiveLabelContent`. Do not choose
  thresholds or axes in presentation callers, create new view identity, or
  reinterpret its accessibility meaning inside layout.
- Materialize native views through `NativeViewMaterializer`. Do not allocate
  collection identity or perform ad hoc type erasure in presentation callers.

## Source layout

```text
Sources/SwiftMarkdownParser/
├── Parsing/
│   ├── SwiftMarkdownParser.swift      public document-construction seam
│   └── LinkReference.swift            link reference definitions
├── MarkdownSourceText.swift           line endings, lines, and source positions
├── Tokenizer.swift                    internal tokenizer
├── BlockParser.swift                  internal block parser
├── InlineParser.swift                 internal inline parser
├── ReferenceDefinitionResolver.swift  reference-definition resolution
├── ParsingBudget.swift                deterministic resource limits
├── MarkdownDocumentValidator.swift    document validation
├── GFMExtensions.swift                GFM table utilities
├── AST.swift                          semantic document node types
├── ASTTraversal.swift                 shared traversal
├── ASTRewriter.swift                  immutable rewriting
├── Rendering/HTML/                    HTML, browser enrichment, and WebKit adapter
├── Rendering/SwiftUI/                 native SwiftUI output
├── SyntaxHighlighter.swift            public highlighting orchestration
├── SyntaxHighlighting.swift           public token, theme, and language types
├── *SyntaxEngine.swift                internal built-in language adapters
└── Resources/
    ├── Browser/                       bundled KaTeX/Mermaid assets and licenses
    └── Localizable.xcstrings          native SwiftUI string catalog
```

## Decision records

- [ADR 0001: Deepen Markdown Document construction](adr/0001-deepen-markdown-document-construction.md)
- [ADR 0002: Deepen AST traversal and rewriting](adr/0002-deepen-ast-traversal-and-rewriting.md)
- [ADR 0003: Keep renderers output-specific](adr/0003-keep-renderers-output-specific.md)
- [ADR 0004: Assemble browser enrichment from discovered requirements](adr/0004-assemble-browser-enrichment-from-requirements.md)
- [ADR 0005: Centralize syntax-highlighting orchestration](adr/0005-centralize-syntax-highlighting-orchestration.md)
- [ADR 0006: Deepen native adaptive presentation](adr/0006-deepen-native-adaptive-presentation.md)
- [ADR 0007: Deepen the native rich-content seam](adr/0007-deepen-native-rich-content-seam.md)
- [ADR 0008: Concentrate native semantics and localization](adr/0008-concentrate-native-semantics-and-localization.md)
- [ADR 0009: Own native identity and materialization](adr/0009-own-native-identity-and-materialization.md)
- [ADR 0010: Plan native documents before materialization](adr/0010-plan-native-documents-before-materialization.md)
- [ADR 0011: Deepen adaptive label/content presentation](adr/0011-deepen-adaptive-label-content-presentation.md)
- [ADR 0012: Normalize native table meaning once](adr/0012-normalize-native-table-meaning-once.md)
- [ADR 0013: Deepen native presentation style](adr/0013-deepen-native-presentation-style.md)
- [ADR 0014: Own line endings and positions in Source Text](adr/0014-own-line-endings-and-positions-in-source-text.md)
