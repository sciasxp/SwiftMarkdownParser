# Deepen native adaptive presentation

SwiftMarkdownParser will keep semantic AST interpretation in `SwiftUIRenderer`
and concentrate container-aware block layout in the internal
`NativeAdaptivePresentation` module. Its single `present(_:)` interface accepts
already-projected native blocks and owns document laziness, decoration budgets,
marker/content reflow, accessibility-size variants, dense table grids, labeled
table rows, and Mermaid fallback composition.

Adaptation follows the SwiftUI layout proposal and Dynamic Type category. It
does not infer behavior from a device model, global screen bounds, horizontal
size class, or host window state. Inline and rich-content adapters materialize
before this seam, so alternative presentation candidates preserve meaning and
do not repeat host side effects.

We accept that the adaptive vocabulary is internal and output-specific. Hosts
continue to learn only `SwiftUIRenderer.render(_:)` and their existing style and
rich-content options. Removing this module would force the same layout policy
back into lists, quotes, footnotes, tasks, tables, and fallbacks, which is the
deletion test for its depth.
