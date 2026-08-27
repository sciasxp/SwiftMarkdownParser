# ADR 0011: Deepen adaptive label/content presentation

## Status

Accepted

## Context

Native adaptive presentation used one private two-subview `Layout` for list
markers, task states, footnote identifiers, and Mermaid titles. The layout
centralized measurement and placement mechanics, but callers still selected
spacing, minimum content width, and accessibility-size behavior. Stacked table
fields implemented the same label/content relationship through a separate
vertical stack.

The interface was therefore almost as detailed as the implementation. It also
encoded “label first, content second” as an unchecked positional convention,
made separate axis decisions during measurement and placement, did not define
right-to-left placement or baseline behavior, and could return invalid geometry
for unconstrained proposals.

## Decision

Introduce the internal `NativeAdaptiveLabelContent` module at the existing
native adaptive presentation seam. Its interface accepts exactly one concrete
label, one concrete content view, the existing style, and one typed role: list
marker, task status, footnote identifier, Mermaid title, or table field. No new
public style option or host adapter is added.

Each role hides its spacing, minimum content reservation, Dynamic Type behavior,
and alignment policy. List and task pairs remain horizontal when their content
reservation fits. Footnote and Mermaid pairs prefer vertical presentation at
accessibility text sizes. A field remains vertical after its table has selected
the stacked presentation.

A private `Layout` measures both views and creates one finite geometry plan for
axis, size, and frames. Its cache reuses that plan when placement receives the
same effective width. Widths that are absent, infinite, negative, or not a
number are normalized; oversized labels receive a bounded proposal. Textual
pairs align by first baseline when both views provide one and otherwise fall
back to top alignment. Right-to-left layout mirrors physical placement while
preserving label-then-content semantic order.

Replace the old positional layout and the table's parallel field stack. The new
module must not create `AnyView`, allocate identity, rematerialize content,
invoke rich-content adapters, or own accessibility copy and grouping.

## Consequences

- Callers select a semantic role instead of reproducing geometry heuristics.
- Measurement and placement cannot disagree about the chosen axis for one
  effective proposal.
- All five native label/content relationships share finite geometry, Dynamic
  Type policy, baseline fallback, and right-to-left behavior.
- Visual labels may remain decorative or be replaced by complete accessibility
  descriptions because semantics stay outside the layout module.
- Existing style metrics continue to influence presentation without expanding
  the public `SwiftUIStyleConfiguration` interface.
- The public renderer, materialized identity, document order, and rich-content
  adapter effects remain unchanged.

## Validation

Focused geometry tests cover the exact axis threshold, accessibility policy for
every role, zero and unconstrained widths, oversized labels, first-baseline
alignment, and right-to-left placement. Public renderer pixel tests exercise
all five roles across wide, narrow, and accessibility presentations. A rich
adapter recorder verifies that evaluating alternate adaptive presentations does
not repeat host effects. Distinct Mermaid sources must also produce distinct
fallback pixels, proving that the readable source survives materialization.
