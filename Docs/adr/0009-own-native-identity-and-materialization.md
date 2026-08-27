# ADR 0009: Own native identity and materialization

## Status

Accepted

## Context

Native SwiftUI output created collection identity independently in adaptive
document children, list items, table rows, table cells, and inline fragments.
Each implementation allocated a fresh `UUID`, while `AnyView` construction was
spread across the document renderer, adaptive presentation, rich-content
fallbacks, and inline styling.

Those values were usually created before `body`, but the invariant was implicit
and had no owner. A new collection or style path could easily allocate identity
during body evaluation, hide structural identity behind another type-erased row,
or replace identity while decorating an already materialized rich view.

## Decision

Introduce the main-actor-confined `NativeViewMaterializer` module. Its interface
allocates cheap monotonic `NativeViewIdentity` values, materializes arbitrary
SwiftUI content into one concrete unary `NativeMaterializedView`, and transforms
an existing materialized view while preserving its identity.

Inject one materializer into the native modules owned by a `SwiftUIRenderer`.
Represent document children and block children directly as materialized views.
Derive list-item and table-cell identity from their materialized content, assign
table-row identity through the materializer, and materialize inline fragments
before `NativeInlineContent.body` evaluates.

Keep `AnyView` inside the materializer implementation, at the public
`SwiftUIRenderer.render(_:)` return, and in the public rich-content adapter that
must accept arbitrary host views. Remove local `UUID` allocation and ad hoc
internal type erasure rather than layering the new owner over them.

## Consequences

- Every native `ForEach` receives stable, unique, cheap identity that outlives
  its body evaluations.
- Styling and link decoration retain the identity of the rich content they wrap.
- Adaptive layouts reuse one materialized content graph instead of reconstructing
  alternate erased rows.
- Internal presentation code handles a concrete unary view type instead of raw
  `AnyView` values.
- Identity is stable for the lifetime of the returned render and unique across
  materializations owned by the renderer; it is not a persisted AST identity.
- The public renderer and rich-content adapter remain source compatible.

## Validation

Module tests verify monotonic uniqueness, identity preservation through
transformations, and pixel materialization. Existing tests continue to cover
large lazy documents, adaptive tables, mixed inline content, rich host adapters,
localization, and complete native documents through the public seam.
