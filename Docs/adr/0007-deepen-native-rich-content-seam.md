# ADR 0007: Deepen the native rich-content seam

## Status

Accepted

## Context

Native SwiftUI output supports images, Mermaid, block and inline math, and block
and inline HTML. The previous public surface exposed a bag of optional closures
for most formats plus a separate image closure. Selection, URL resolution, and
fallback behavior were consequently split across the renderer and inline
projection. Adding a rich format would deepen that distribution rather than the
module that owns rich-content policy.

The host must remain free to supply WebKit, KaTeX, Mermaid, image pipelines, or
other visual implementations. Native output must also remain complete, readable,
and accessible when the host declines a request.

## Decision

Expose one closed `SwiftUIRichContentRequest` value and one
`SwiftUIRichContentAdapter.render(_:)` operation. The adapter may return a
type-erased SwiftUI view or `nil`; `nil` explicitly declines the request and
selects the native fallback.

Keep request selection, safe image resolution, adapter invocation, and every
native rich-content fallback inside `NativeRichContentProjection`. Unsafe or
unresolved image destinations never become public adapter requests. Invoke the
adapter at most once for each projected request, so adaptive layouts can reuse
the result without repeating host work.

Use `AnyView` only at the public host boundary where arbitrary application views
require type erasure. Keep internal fallback construction concrete until that
boundary. Replace the old handler bag and separate image handler instead of
maintaining a compatibility shim.

## Consequences

- Hosts implement and test one exhaustive operation for all rich content.
- Native fallbacks and accessibility behavior have one owner.
- URL validation cannot be accidentally skipped by an image adapter.
- Adaptive presentation does not multiply host side effects.
- Adding a new request is a deliberate source-visible change to the closed enum
  and requires a fallback in the same module.
- Existing callers must migrate from per-format closures to the adapter.

## Validation

Tests exercise every request through the same adapter, adapter decline, resolved
and unsafe image destinations through the public document interface, rich inline
content in each native container, single materialization across adaptive layouts,
inline failure before adapter effects, and pixel materialization of mixed rich
inline output including an invalid image inside a valid link.
