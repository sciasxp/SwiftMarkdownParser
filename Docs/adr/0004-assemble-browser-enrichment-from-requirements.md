# Assemble browser enrichment from discovered requirements

HTML rendering will discover Mermaid, KaTeX, footnote, and task-list browser
requirements while producing the body, then pass those requirements to one
assembler that owns resource selection, deduplication, placement, document
composition, and the readiness/failure bootstrap. Configuration remains
data-only, bundled assets provide deterministic offline output, and
`MarkdownWebView` reports success only after required runtimes initialize. This
two-phase design avoids both unconditional asset injection and duplicated
script assembly across node renderers, configuration values, and presentation
adapters.
