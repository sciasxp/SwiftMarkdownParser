---
name: fix-markdown
description: Fix markdownlint violations in Markdown files. Use when editing .md files, resolving markdownlint violations, or when asked to fix markdown style.
argument-hint: "[file.md]"
disable-model-invocation: true
---

# Fix Markdown

Apply markdownlint rules to fix violations in the target file.

**Target**: $ARGUMENTS

## Workflow

1. Read the target `.md` file.
2. Run through: headers (level, style, blanks), lists (indent, blanks), trailing spaces, final newline, code block language and blanks.
3. Apply fixes following the rules below.
4. Prefer ATX headers (`#`, `##`) and fenced code blocks with a language for consistency.

## Quick Fixes by Category

### Headers

- **MD001** - Don't skip levels (use ## after #, ### after ##).
- **MD002** - First header must be top-level (e.g. `#`).
- **MD003** - Use one header style in the file (atx `#`, atx_closed `# H #`, or setext).
- **MD018/MD019** - One space after `#` in atx headers; **MD020/MD021** - one space inside `# H #` if closed.
- **MD022** - Blank line before and after every header.
- **MD023** - Headers must start at column 1 (no leading spaces).
- **MD024** - No duplicate header text (unless `allow_different_nesting`).
- **MD025** - Only one top-level (h1) header per document.
- **MD026** - No trailing punctuation (e.g. `.`, `?`) in header text.
- **MD041** - First line of file should be a top-level header.

### Lists

- **MD004** - Use one unordered list marker (`*`, `+`, or `-`) consistently.
- **MD005** - Same indentation for items at the same level.
- **MD006** - Top-level list items start at column 1 (no leading indent).
- **MD007** - Nested list indent: default 3 spaces (or 4 if configured).
- **MD030** - One space (or configured) after list marker (`-`, `*`, `1.`).
- **MD032** - Blank line before and after lists.

### Whitespace & Line Breaks

- **MD009** - No trailing spaces (except configured `br_spaces` for line break).
- **MD010** - No hard tabs; use spaces.
- **MD012** - No multiple consecutive blank lines (single blank only).
- **MD047** - File must end with a single newline.

### Code Blocks

- **MD031** - Blank line before and after fenced code blocks.
- **MD040** - Fenced code blocks must have a language (e.g. ` ```bash `).
- **MD046** - Use fenced style (not indented) by default.

### Links, Emphasis, HTML

- **MD011** - Link syntax is `[text](url)` not `(text)[url]`.
- **MD034** - Wrap bare URLs in angle brackets `<url>` or use `[text](url)`.
- **MD037** - No spaces between emphasis markers and text (`**bold**` not `** bold **`).
- **MD038** - No spaces inside code spans.
- **MD039** - No spaces inside link text: `[text](url)` not `[ text ](url)`.
- **MD033** - Prefer Markdown over inline HTML (or allow specific elements).

### Other

- **MD013** - Line length (default 80); often disabled for code blocks/tables.
- **MD014** - Omit `$` before shell commands unless showing output.
- **MD035** - Use one horizontal rule style (e.g. `---`) consistently.
- **MD036** - Use a header instead of a single-line bold/italic "section" line.

## Full Reference

- Per-rule details and examples: [reference.md](reference.md)
- Upstream: [markdownlint RULES.md](https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md)
