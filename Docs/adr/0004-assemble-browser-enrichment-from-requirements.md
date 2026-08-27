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

The bootstrap report is a versioned browser-runtime observation, not a host
presentation completion. Version 1 publishes `status`, `requiredFeatures`,
`failedFeatures`, and diagnostic `detail` exactly once through both the
`swift-markdown-runtime` DOM event and the `markdownRuntime` WebKit handler.
Feature initialization records the active requirement, and asset failures are
mapped to their owning features when possible. This lets a host translate a
Mermaid-only failure differently from mixed or unclassified failures without
inspecting rendered DOM content.

The package's private WebView decoder accepts the previous unversioned report
as a legacy internal input, rejects unknown numbered versions, and keeps the
public `onRender` success/failure interface unchanged. Host-session identity,
ordering, deadlines, cancellation, artifact publication, and fallback policy
remain outside the package.
