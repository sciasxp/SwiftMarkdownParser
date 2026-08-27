# ADR 0010: Plan native documents before materialization

## Status

Accepted

## Context

Native SwiftUI rendering previously validated and materialized one AST node at a
time. A supported rich-content node near the start of a document could invoke a
host adapter and allocate view identity before a later unsupported node caused
the render to fail. Inline projection already validated a complete inline tree,
but the document renderer did not provide the same atomic boundary across
blocks or nested containers.

The public interface accepts a complete `AST.DocumentNode`, so callers reasonably
expect either one complete native result or one deterministic error. Interleaved
validation and output work made that contract depend on node position and left
host-visible effects even when no view was returned.

## Decision

Introduce the main-actor-confined `NativeDocumentProjection` module. It walks the
complete document in deterministic depth-first order and produces a typed,
one-shot plan before output work begins. The plan incorporates `NativeInlinePlan`
values and deferred `NativeRichContentProjection.Request` values, but contains no
SwiftUI views, materialized identity, adapter results, or syntax-highlighting
results.

If interpretation encounters an unsupported node, projection stops and reports
the first such node in depth-first order. Because projection precedes all output
work, a failure occurs before view materialization, identity allocation, rich
adapter invocation, or syntax highlighting.

After projection succeeds, `SwiftUIRenderer` materializes the complete plan.
This phase may await syntax highlighting but is nonthrowing. Existing ownership
remains separate: inline projection materializes inline meaning, rich-content
projection owns destinations and host adaptation, adaptive presentation owns
container behavior, semantics owns localized meaning, and the materializer owns
identity and type erasure. Remove the old recursive throwing renderer and its
global asynchronous array helper instead of retaining a second path.

## Consequences

- A failed render has no partial view graph and no host-visible rich-adapter
  effects.
- Unsupported nodes are reported deterministically in depth-first document
  order, including inside nested block and inline containers.
- Materialization can rely on a complete validated plan and does not throw.
- The temporary plan consumes memory proportional to the document and is
  discarded after one render.
- Syntax highlighting may update its private cache only after validation; that
  internal cache work is not observable through the host output seam.
- The public `SwiftUIRenderer` and rich-content adapter interfaces remain source
  compatible.

## Validation

Public renderer tests verify that earlier rich requests produce zero adapter
effects when a later top-level or nested node is unsupported, that the first
depth-first error wins, and that a thousand-block document still renders. The
existing pixel render tests verify that adaptive and rich inline presentation
remain materializable after the new projection boundary.
