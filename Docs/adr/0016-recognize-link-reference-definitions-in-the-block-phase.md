# ADR 0016: Recognize Link Reference Definitions in the Block Phase

## Status

Accepted. Stage 1 (paragraph continuation, then separate the Block Phase from
the Inline Phase) is implemented. Stage 2 (recognize Link Reference Definitions
in the Block Phase) is pending; until it lands, the line-based pre-read
described below still resolves definitions.

Example numbers follow the official CommonMark 0.30 numbering (`spec.json`,
starting at 1).

## Context

`ReferenceDefinitionResolver` reads the source line by line before
tokenization. It knows only fenced code blocks, records every line shaped like
`[label]: destination`, and replaces those lines with spaces so offsets stay
put. The tokenizer then needs a branch so a blanked line is not read as an
indented code block. Inline parsing ran eagerly inside the block parser, at
five sites, on the document token stream.

Because the pre-read does not know the block structure, it gets Link Reference
Definitions wrong:

- A definition inside a `$$` math block or an HTML block is consumed.
- A definition line right after paragraph text (`text\n[a]: url`) is consumed,
  although CommonMark says a definition cannot interrupt a paragraph.
- A definition inside a block quote or a list item is not recognized, although
  it applies to the whole document.
- A destination or title on the following line is not recognized, nor is a
  multi-line label or title.

It already handles `~~~` fences, unclosed fences, and indented code.

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

- When a paragraph closes, the Block Phase strips Link Reference Definitions
  from the start of its raw text, as CommonMark specifies, including inside
  block quotes and list items, with destinations, titles, and labels that
  continue on the following lines.
- A definition cannot interrupt a paragraph (strict CommonMark).
- Delete `ReferenceDefinitionResolver`, the blanking of definition lines, and
  the tokenizer's blank-line branch for them.

### Acceptance

The CommonMark 0.30 section 4.7 examples (192-218) and ten block-context
cases are ported as Source → Document tests in
`LinkReferenceDefinitionTests`. The section 4.8 examples (219-226), inline
constructs that cross a line (42, 335-337, 640), lazy continuation, interrupting
blocks, soft and hard breaks, and examples 318 and 324 are in
`ParagraphContinuationTests`, which pass without known issues.

A case that still fails is marked with `withKnownIssue` and names its causes:
"Link Reference Definitions are not recognized by the Block Phase yet" or
"backslash escapes in link destinations and titles are not decoded" (example
202). Stage 2 is done when every case passes without it; example 202 also
needs escapes decoded in destinations and titles.

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
  characters (`* * *`, `- - -`) is a thematic break. An HTML block ends with the
  list item that holds it. An empty list item ends at a blank line.
- A backslash with nothing after it is literal.

Of the 652 CommonMark 0.30 examples, 153 change their HTML. Under whitespace
normalization (whitespace collapsed, ignored between tags), the examples that
pass go from 221 to 296 and none that passed fails. Most of the changed
examples that still fail do so for limitations that predate this ADR, such as
tight lists rendered with `<p>` and emphasis that does not cross a line.
Example 236 (`>     foo` followed by `    bar`) is a known deviation: indented
code inside a block quote is not recognized, so the lazy line now continues the
misread paragraph instead of starting a code block. No text is lost.

### Work cost

Paragraph and heading text is tokenized twice: once in the document and once as
its own fragment. The cost stays linear in the source size; doubling every
document below doubles its cost. Measured as the smallest
`ResourceLimits.maximumWork` that parses (`develop` against stage 1):

| Document | Characters | develop | Stage 1 | Factor |
|---|---|---|---|---|
| heading, paragraph, two list items (pinned) | 58 | 420 | 565 | 1.35 |
| prose, 1,000 lines in one paragraph | 73,000 | 550,000 | 487,128 | 0.89 |
| prose, 1,000 paragraphs | 74,000 | 557,001 | 621,001 | 1.11 |
| one line of 63,000 characters | 63,001 | 126,042 | 252,033 | 2.00 |
| `` `a `` × 3,000 on one line | 9,000 | 58,507 | 94,501 | 1.62 |
| `` `a `` and a line ending × 3,000 | 9,000 | 69,001 | 97,504 | 1.41 |
| `[a` and a line ending × 3,000 | 9,000 | 206,999 | 123,018 | 0.59 |
| list of 2,000 items | 34,000 | 158,004 | 308,016 | 1.95 |
| block quote of 2,000 lines | 38,000 | 270,006 | 246,031 | 0.91 |
| table of 500 rows | 5,020 | 32,140 | 32,140 | 1.00 |
| fence of 2,000 lines | 20,008 | 62,037 | 56,037 | 0.90 |

The worst case is about twice the cost on `develop`: very long lines and long
lists, whose text was tokenized once. Ordinary prose costs 6.5 to 8.5 units per
character, so a document at the default `maximumSourceLength` (2,000,000)
still fits the default `maximumWork` (25,000,000). The pinned cost lives in
`MarkdownDocumentConstructionTests`.

## Validation

- The whole suite passes. Changes to existing tests: the pinned work costs, and
  the known-issue markers that paragraph continuation resolved (example 216).
- A differential dump of the complete AST, ranges included, for the 652
  CommonMark examples and nine extra documents (CRLF, tabs, emoji, hard breaks,
  tables, block quotes, lists) is identical before and after the phase
  separation. HTML for the 652 examples is identical before and after ATX
  headings became fragments.
