# ADR 0014: Own line endings and positions in Source Text

## Status

Accepted. Narrows the line-ending behavior introduced by commit `cd57b66`.

## Context

Every construction stage decided for itself what ends a line and how a position
becomes a `SourceLocation`. The tokenizer tracked line and column state while it
advanced and restored it by hand at every backtracking site. The
reference-definition resolver searched for the next newline and counted offsets
on its own. `SourceLocation.extending(over:)` started a new line only at LF, and
the block parser built document and table ranges with that method.

Commit `cd57b66` made the tokenizer and resolver treat every Unicode newline
(`Character.isNewline`) as a line ending, which fixed CRLF but also split lines
at U+2028, U+2029, NEL, VT, and FF. CommonMark 0.30 defines a line ending as LF,
CR, or CRLF only. The same source could therefore produce lines in the tokenizer
that `extending(over:)` did not count, and ranges disagreed by stage.

## Decision

Introduce the internal `MarkdownSourceText` module. Document construction builds
it once from the Markdown Source; it holds the characters and a table of line
starts. It is the only place that defines:

1. what ends a line: LF, CR, or CRLF, where CRLF is one Swift `Character`;
2. `SourceLocation` arithmetic: line, column, and offset for a position, and the
   range between two positions;
3. line iteration.

U+2028, U+2029, NEL, VT, and FF no longer end a line. They follow the
tokenizer's ordinary whitespace path, and a regression test pins this.

The tokenizer derives every location from the table instead of tracking line
and column, so backtracking only rewinds a position. The resolver iterates the
table's lines and returns a blanked copy that keeps the same line table, so the
tokenizer reuses it instead of rescanning. `SourceLocation.extending(over:)`
delegates to the module, and the block parser takes document and table ranges
from it. Inline parsing builds a small source text for each inline fragment,
anchored at the fragment's starting location.

Building a table charges one unit of work per character to the parse's
`ParsingBudget`, like the tokenizer's per-character advance. The document's
table replaces the up-front charge of one unit per source character that the
parse used to start with, so a document costs the same work as before.

Offsets and columns still count Swift `Character` values. No public interface
changes.

## Consequences

- One definition of a line ending; tokens, references, tables, and document
  ranges agree on line numbers for LF, CR, and CRLF sources.
- Intentionally reverses the Unicode-newline part of `cd57b66`: sources using
  U+2028, U+2029, NEL, VT, or FF as separators now keep them inside one line.
  CRLF and CR handling from that commit is kept.
- `extending(over:)` now starts a new line at CR and CRLF, so CRLF sources report
  correct end lines.
- Location lookup is a binary search over line starts instead of incremental
  state. The document's table costs one pass, charged in place of the parse's
  former up-front charge.

## Validation

`MarkdownSourceTextTests` exercises the module through its interface: line
endings, line iteration, locations with custom origins, ranges, blanking, and
budget accounting. Document-construction tests pin that Unicode separators do
not end headings or start reference definitions, that CRLF tables report
correct row and cell ranges, and the existing CRLF tests keep passing.
