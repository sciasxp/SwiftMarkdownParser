# Markdownlint Rules Reference

Condensed rule descriptions and fix examples. Rule IDs match markdownlint output.

## Headers

### MD001 – Header increment

Headers must not skip levels.

```markdown
# H1
### H3
```

```markdown
# H1
## H2
### H3
```

### MD002 – First header top-level

First header in the file must be top-level (e.g. `#`).

### MD003 – Header style

Use one header style in the document (atx `#`, atx_closed `# H #`, or setext). Default is consistent.

### MD018 – Space after hash (atx)

One space after `#` in atx headers.

```markdown
#Header
```

```markdown
# Header
```

### MD019 – Single space after hash (atx)

Only one space after `#` in atx headers.

### MD020 – Space inside closed atx

Spaces required inside `#` on both sides for closed atx: `# H #`.

### MD021 – Single space inside closed atx

Only one space inside the closing `#` for closed atx headers.

### MD022 – Blanks around headers

Blank line before and after every header (except at start/end of file).

```markdown
# Header
Some text
## H2
```

```markdown
# Header

Some text

## H2
```

### MD023 – Header at start of line

Headers must start at column 1 (no leading spaces).

### MD024 – No duplicate header content

No two headers with the same text (unless `allow_different_nesting` is set, e.g. for changelogs).

### MD025 – Single top-level header

Only one h1 (top-level) header per document.

### MD026 – No trailing punctuation in headers

Remove trailing `.,;:!?` from header text.

### MD041 – First line is top-level header

First line of the file should be a top-level header.

---

## Lists

### MD004 – Unordered list style

Use one marker for unordered lists: `*`, `+`, or `-` (default: consistent).

### MD005 – List indent consistency

Items at the same level must share the same indentation.

### MD006 – Top-level list at column 1

Top-level list items must not be indented.

### MD007 – Unordered list indent

Nested list items: default 3 spaces (configurable, often 2 or 4).

### MD029 – Ordered list prefix

Ordered lists: either all `1.` (style `one`) or incrementing `1.`, `2.`, … (style `ordered`).

### MD030 – Space after list marker

One space (or configured count) after `-`, `*`, `+`, or `1.`.

### MD032 – Blanks around lists

Blank line before and after lists (except at start/end of file).

---

## Whitespace and line breaks

### MD009 – No trailing spaces

No trailing spaces on lines (except configured `br_spaces` for explicit line break).

### MD010 – No hard tabs

Use spaces, not tab characters, for indentation.

### MD012 – No multiple blank lines

At most one consecutive blank line.

### MD047 – Single trailing newline

File must end with exactly one newline character.

---

## Code blocks

### MD031 – Blanks around fenced code

Blank line before and after fenced code blocks (triple backticks).

### MD040 – Language on fenced code blocks

Specify a language after the opening fence, e.g. ` ```bash ` or ` ```text `.

### MD046 – Code block style

Use fenced code blocks (default), not indented-only blocks.

---

## Links and emphasis

### MD011 – Link syntax

Use `[text](url)` not `(text)[url]`.

### MD034 – No bare URLs

Wrap URLs in angle brackets `<url>` or use `[text](url)`.

### MD037 – No space inside emphasis

`**bold**` and `*italic*`, not `** bold **` or `* italic *`.

### MD038 – No space inside code spans

`` `code` `` not `` ` code ` ``.

### MD039 – No space inside link text

`[text](url)` not `[ text ](url)`.

### MD033 – No inline HTML

Prefer Markdown; or allow specific elements via config.

---

## Other

### MD013 – Line length

Default max 80 characters per line; often disabled for code blocks and tables.

### MD014 – Dollar signs in shell blocks

Omit `$` before commands unless you are showing both command and output.

### MD035 – Horizontal rule style

Use one style for horizontal rules (e.g. `---`) throughout the file.

### MD036 – No emphasis as header

Use a real header (`#`, `##`) instead of a single-line bold/italic “section” line.

### MD027 – Blockquote spacing

Only one space after `>` in blockquotes.

### MD028 – No blank line inside blockquote

Don’t separate two blockquote blocks with only a blank line; add `>` on the blank line or insert text between quotes.

---

Source: [markdownlint RULES.md](https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md)
