# ADR 0016: Recognize Link Reference Definitions in the Block Phase

## Status

Accepted and implemented. Stage 1 (paragraph continuation, then separate the
Block Phase from the Inline Phase) and stage 2 (recognize Link Reference
Definitions in the Block Phase) have landed; the line-based pre-read described
below is gone.

Example numbers follow the official CommonMark 0.30 numbering (`spec.json`,
starting at 1).

## Context

`ReferenceDefinitionResolver` read the source line by line before
tokenization. It knew only fenced code blocks, recorded every line shaped like
`[label]: destination`, and replaced those lines with spaces so offsets stayed
put. The tokenizer reads a whitespace-only line as blank rather than as an
indented code block, which also kept a blanked line out of the document. Inline parsing ran eagerly inside the block parser, at
five sites, on the document token stream.

Because the pre-read did not know the block structure, it got Link Reference
Definitions wrong:

- A definition inside a `$$` math block or an HTML block is consumed.
- A definition line right after paragraph text (`text\n[a]: url`) is consumed,
  although CommonMark says a definition cannot interrupt a paragraph.
- A definition inside a block quote or a list item is not recognized, although
  it applies to the whole document.
- A destination or title on the following line is not recognized, nor is a
  multi-line label or title.

It already handled `~~~` fences, unclosed fences, and indented code.

CommonMark recognizes a definition when a paragraph closes, from the start of
the paragraph's raw text. That needs a Block Phase that keeps raw paragraph
text and an Inline Phase that runs after every block, and so every definition,
is known. Forward references (`[foo]` before `[foo]: /url`) then keep working.

The Block Phase also had no paragraph continuation: every line was its own
paragraph. Eager inline parsing on the document token stream hid part of that,
because a code span or strikethrough could consume tokens past the line ending.
Parsing a single line as an inline fragment before paragraphs continued would
have turned those constructs into literal text split across paragraphs, and a
fence on a list item's first line into an unclosed fence that swallowed the
rest of the document (examples 318 and 324). Paragraph continuation therefore
comes first.

## Decision

### Stage 1: paragraph continuation, then separate the phases

1. **Paragraph continuation.** A paragraph takes every Paragraph Continuation
   Line (CommonMark 0.30 section 4.8), lazy or not, until a blank line or a
   block that can interrupt it: an ATX heading, a fence, a thematic break, a
   block quote, a non-empty bullet item or an ordered item starting at 1 (any
   item when the line closes a list item), an HTML block of types 1 to 6, a
   `$$` math block, or a table header row followed by its delimiter row. A
   setext underline after the lines turns them into a heading. The Block Phase
   tracks the open containers (block quotes, and list items by content column)
   to match continuation lines. The whole paragraph is one inline fragment;
   container prefixes and indentation on its continuation lines become spaces,
   so offsets and columns are kept. Line endings inside it are soft breaks; two
   trailing spaces or a backslash make them hard. A list item's marker line
   starts the item's first block, and fence content drops the item's
   indentation.
2. **Fragments everywhere.** ATX heading text is parsed as a fragment too, and
   the inline parser's entry point on the document token stream is removed.
3. **Separate the phases.** `BlockParser` is the Block Phase. It returns
   `ParsedBlock` values instead of AST nodes. Paragraphs, headings (ATX and
   setext), list items, and table cells keep their raw inline text as an
   `InlineSource`: the characters and the location of the first one. Every
   other block is already complete. `InlinePhase` builds the Markdown Document
   from those blocks after the Block Phase finishes, parsing each
   `InlineSource` through `InlineParser.parse`: each fragment gets its own
   `MarkdownSourceText`, anchored at its start, and its own tokens.

The pre-read stays in stage 1.

### Stage 2: recognize definitions in the Block Phase

- When a paragraph closes, the Block Phase reads the Link Reference Definitions
  at the start of its raw text with `LinkReferenceDefinitionParser`, as
  CommonMark 0.30 section 4.7 specifies, including inside block quotes and list
  items, with labels, destinations, and titles that continue on the following
  lines. Backslash escapes are decoded in destinations and titles. The first
  definition of a label wins; the definitions leave the paragraph, and a
  paragraph of only definitions leaves no block.
- A definition cannot interrupt a paragraph (strict CommonMark). Lines that are
  only definitions cannot be a setext heading's text, so `===` after them
  continues the paragraph and `---` is a thematic break (examples 215 and 216).
- The Block Phase hands the definitions to the Inline Phase, which still runs
  after every block, so forward references keep working.
- `ReferenceDefinitionResolver` and the blanking of definition lines
  (`MarkdownSourceText.blankingCharacters`) are deleted. The tokenizer keeps
  reading a whitespace-only line as blank: real blank lines of four or more
  spaces need it, or they become empty code blocks and split lists (example
  117 regressed without it). Only its comment about blanked definitions goes.

### Acceptance

The CommonMark 0.30 section 4.7 examples (192-218) and ten block-context
cases are ported as Source → Document tests in
`LinkReferenceDefinitionTests`. The section 4.8 examples (219-226), inline
constructs that cross a line (42, 335-337, 640), lazy continuation, interrupting
blocks, soft and hard breaks, and examples 318 and 324 are in
`ParagraphContinuationTests`, which pass without known issues.

A case that still fails is marked with `withKnownIssue` and names its cause.
After stage 2 every case passes except example 194, whose definition is
recognized but whose shortcut reference `[Foo*bar\]]` is not: the Inline Phase
matches a shortcut reference on its decoded link text (`Foo*bar]`) instead of
its raw label (`Foo*bar\]`). That is inline label matching, outside the Block
Phase, and stays a known issue with that cause. Example 202 passes because
escapes are decoded.

No 4.7 example is out of scope. Rendering a raw HTML block as escaped text is
out of scope: it is the HTML renderer's raw-HTML policy, not construction.

## Consequences

### Intentional behavior changes

- Consecutive lines form one paragraph with soft breaks, lazy lines included,
  instead of one paragraph per line. Setext headings can span lines, and a
  setext underline may be a single `=` or `-`.
- A code span turns its line endings into spaces.
- The marker line of a list item starts any block, so `- # foo` is a heading
  and ``- ``` `` opens a fence inside the item. A thematic break made of list marker
  characters (`* * *`, `- - -`) is a thematic break, on a list item's marker
  line, on its continuation lines, and after it, where it ends the list. An HTML
  block ends with the list item that holds it. An empty list item ends at a blank
  line.
- A fence ends with the list item or block quote that holds it: a non-blank line
  that does not match the open containers ends the fence, which takes no lazy
  lines, and container markers never become code. A list inside a block quote
  continues on the quote's marked lines. A `$$` math block ends the same way;
  an unclosed `$$` stays paragraph text.
- A backslash with nothing after it is literal.
- Stage 2: a definition cannot interrupt a paragraph, so `text` followed by
  `[a]: url` stays one paragraph; a definition inside a `$$` math block or an
  HTML block stays content; a definition in a block quote or list item applies
  to the whole document. A line that is not a complete definition, such as
  `[^1]: The note.` (a footnote, which is not supported) or `[foo]: /url "t" ok`,
  is now paragraph text instead of being consumed. A raw destination nests at
  most 32 levels of parentheses, a limit CommonMark allows; a deeper one is not
  a definition, where `develop` accepted it.

Of the 652 CommonMark 0.30 examples, 153 change their HTML with paragraph
continuation and 167 after stage 2. Under whitespace normalization (whitespace collapsed, ignored
between tags), the examples that pass go from 212 on `develop` to 295 with
paragraph continuation, 298 once fences end with their containers, and 315
after stage 2 (strict comparison: 201, 233, 234, 249). None that passed fails. Most of the changed
examples that still fail do so for limitations that predate this ADR, such as
tight lists rendered with `<p>` and emphasis that does not cross a line.
Example 236 (`>     foo` followed by `    bar`) is a known deviation: indented
code inside a block quote is not recognized, so the lazy line now continues the
misread paragraph instead of starting a code block. No text is lost. Example
589 (`![[foo]]` with `[[foo]]: /url "title"`) no longer defines the invalid
label, so the image is not resolved and its `!` is dropped, a loss the inline
parser already had on `develop` for any unresolved image such as `![nope]`.

### Work cost

Paragraph and heading text is tokenized twice: once in the document and once as
its own fragment. The cost stays linear in the source size; doubling every
document below doubles its cost. Measured as the smallest
`ResourceLimits.maximumWork` that parses (`develop` against stage 2):

| Document | Characters | develop | Stage 2 | Factor |
|---|---|---|---|---|
| heading, paragraph, two list items | 51 | 362 | 474 | 1.31 |
| prose, 1,000 lines in one paragraph | 79,000 | 484,000 | 472,104 | 0.98 |
| prose, 1,000 paragraphs | 80,000 | 491,001 | 582,001 | 1.19 |
| one line of 63,000 characters | 63,001 | 289,829 | 384,316 | 1.33 |
| `` `a `` × 3,000 on one line | 9,000 | 58,507 | 94,501 | 1.62 |
| `` `a `` and a line ending × 3,000 | 9,000 | 69,001 | 97,504 | 1.41 |
| `[a` and a line ending × 3,000 | 9,000 | 206,999 | 123,018 | 0.59 |
| ``- item *a* `b` `` × 2,000 | 30,000 | 220,004 | 418,016 | 1.90 |
| block quote of 2,000 lines | 38,000 | 270,006 | 246,031 | 0.91 |
| table of 500 rows | 5,020 | 32,140 | 32,140 | 1.00 |
| fence of 2,000 lines | 20,008 | 62,037 | 48,037 | 0.77 |
| 1,000 definitions and 1,000 references | 16,001 | 98,024 | 108,063 | 1.10 |

Stage 2 changes only the definitions row (97,014 at the end of stage 1): the
definition lines are now tokenized as paragraph text. Reading definitions
charges no work of its own; it is linear in the paragraph, and the setext check
reads a paragraph's definitions at most twice. The pinned document in
`MarkdownDocumentConstructionTests` still costs 565 units (420 on `develop`).

The worst case is about twice the cost on `develop`: very long lines and long
lists, whose text was tokenized once. Ordinary prose costs 6 to 7.5 units per
character, so prose at the default `maximumSourceLength` (2,000,000) still fits
the default `maximumWork` (25,000,000). Dense lists do not: a list such as
``- item *a* `b` `` costs about 14 units per character, so such a list above
about 1,800,000 characters, which parsed on `develop`, now exceeds the default
`maximumWork` (1,875,000 characters cost 25,160,719 units). The default limit
is unchanged. The pinned cost lives in `MarkdownDocumentConstructionTests`.

## Validation

- The whole suite passes with one known issue (example 194). Changes to
  existing tests: the pinned work costs; the known-issue markers that paragraph
  continuation (example 216) and stage 2 resolved; the signature notation,
  which now shows autolinks, so the case "Definition cannot interrupt a
  paragraph" expects its URL as a GFM autolink; and the two tests of
  `blankingCharacters`, deleted with it.
- A differential dump of the complete AST, ranges included, for the 652
  CommonMark examples and nine extra documents (CRLF, tabs, emoji, hard breaks,
  tables, block quotes, lists) is identical before and after the phase
  separation. HTML for the 652 examples is identical before and after ATX
  headings became fragments.
