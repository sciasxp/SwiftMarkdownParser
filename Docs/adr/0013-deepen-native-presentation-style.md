# ADR 0013: Deepen native presentation style

## Status

Accepted. Amends [ADR 0011](0011-deepen-adaptive-label-content-presentation.md).

## Context

Native output received the public `SwiftUIStyleConfiguration` directly. The
renderer, inline projection, rich-content projection, and adaptive presentation
each selected the fonts, colors, and metrics they needed and performed their own
arithmetic, such as halving indentation and padding at accessibility sizes or
deriving minimum content widths. Only the label/content geometry normalized
negative or non-finite metrics; every other caller used host values as given.

ADR 0011 gave `NativeAdaptiveLabelContent` a typed role enum and let each role
derive its spacing, content reservation, alignment, and Dynamic Type policy
inside the layout module. Geometry therefore depended on style policy, and the
layout module had to read the public configuration to interpret a role.

The `compact()` and `darkMode()` variants also rebuilt the complete
configuration field by field, which made it easy for a new option to be dropped
or scaled by accident.

## Decision

Introduce the internal `NativePresentationStyle` module. The renderer
materializes it once from `SwiftUIStyleConfiguration` and shares it with every
native module. It exposes immutable role values: document, inline, paragraph,
heading (per level with a fallback), code block, quote, list, task, table,
image, and thematic break. Each value holds only what its presenter needs.

The style normalizes metrics once: negative and non-finite values become zero,
while an unbounded or not-a-number image width means no maximum. Small
accessibility-size adjustments, such as list indentation and quote padding, are
methods on the owning role value.

Replace the label/content role enum with `NativeAdaptiveLabelContentMetrics`.
The owning style role supplies standard and accessibility geometry: spacing,
minimum content width, axis preference, and alignment. List markers, task
status, footnote identifiers, Mermaid titles (owned by the code-block role),
and stacked table fields each carry their own metrics value. `NativeAdaptiveLabelContent` keeps
only measurement, axis selection, finite geometry, baseline fallback, and
right-to-left placement.

`compact()` and `darkMode()` derive from one private copying initializer. Dark
mode replaces only its deliberate palette, and compact mode scales only the
documented spatial metrics. No public interface is added or removed.

## Consequences

- Native modules depend on the role value they present instead of the whole
  public configuration.
- Metric normalization and accessibility-size adjustments live in one place.
- The label/content module is pure geometry. Adding a relationship means adding
  a metrics value to the owning style role, not a new case in the layout.
- Host customizations survive `compact()` and `darkMode()` unless the variant
  deliberately changes them.
- The public renderer, materialized identity, document order, and rich-content
  adapter effects remain unchanged.

## Validation

Renderer tests verify that the style owns Dynamic Type policy for every
label/content relationship, that metrics are normalized without mutating the
host configuration, that dark mode preserves every customization outside its
palette, and that compact mode scales only spatial metrics. Standard, compact,
and dark styles are materialized through the public renderer, followed by the
existing adaptive geometry and pixel tests.
