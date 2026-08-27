# ADR 0012: Normalize native table meaning once

## Status

Accepted

## Context

The public GFM table AST retains overlapping compatibility metadata. A table
stores column alignments, each cell also stores an alignment, rows identify
themselves as headers, and cells repeat a header flag. Parser-produced tables
keep those values consistent, but programmatically constructed tables can make
them disagree.

Native document projection previously selected table-level alignment while
adaptive presentation rediscovered the first header row, separated header and
body rows, associated headers with body cells by index, and decided what a
header-only table meant. The materialized table repeated row roles and cell
alignment even though presentation needed one canonical column schema. Table
meaning was therefore distributed across projection, materialization, and view
evaluation.

## Decision

Deepen `NativeDocumentProjection` rather than introduce another public module.
Its table plan exposes canonical columns and ordered data rows. Each column owns
its index, table-level alignment, and one optional inline header plan. Each data
cell owns only its inline content and column index.

Only the first AST row can supply column headers, and only when its row-level
header flag is set. If it is not a header, every row remains data even when a
later row or individual cell claims otherwise. The table alignment vector is
the column-level source of truth; a missing entry becomes `.none`. Cell-level
header and alignment fields remain public AST compatibility data but do not
participate in native output interpretation.

The normalized column count is the maximum of the alignment vector and every
row's cell count. Ragged rows retain only their real cells, columns may have no
header, and no semantic empty value is synthesized. Empty, headerless, and
header-only tables remain valid. Legacy cells without inline children become a
plain-text inline plan as before.

Materialization converts every optional column header and data cell exactly
once. It assigns stable identity to columns and rows through
`NativeViewMaterializer`. `NativeAdaptivePresentation` consumes this value for
both the dense grid and stacked records. It may map canonical alignment into
SwiftUI geometry, but it does not inspect AST flags, partition rows, search for
headers, or reinvoke rich-content adapters.

## Consequences

- Programmatic AST inconsistencies have deterministic native meaning without a
  new rendering error or public interface change.
- Grid and stacked presentations share one header, row, and alignment model.
- Header rich content can be repeated visually without repeating host-adapter
  effects or identity allocation.
- Header-only tables cannot fall back to a record that labels a header with
  itself; headerless records do not invent labels.
- HTML remains output-specific and is unchanged by this native projection
  decision.
- The normalized plan uses storage proportional to the number of columns and
  cells and is discarded after one render.

## Validation

Projection tests construct conflicting row and cell flags, conflicting
alignments, ragged rows, later header flags, headerless tables, and header-only
tables, then assert only on the canonical table plan. Renderer coverage verifies
that one rich column header crosses the host adapter once while wide, narrow,
and accessibility presentations are evaluated. Existing adaptive pixel tests
exercise aligned grids and labeled rows, followed by the complete package test
suite and rendered-image inspection.
