---
title: "Example — Markdown tokenizer"
type: api
updated: 2026-05-28
sources:
  - path: Sources/Example/Tokenizer.swift
    sha: 0000000000000000000000000000000000000000
---

# Example — Markdown tokenizer

> This is a format example, not real content. Delete it after your first ingest.

`Tokenizer` turns a raw string into a flat array of `Token` values in a single
left-to-right pass (`Sources/Example/Tokenizer.swift:12-48`). It is allocation-
light: tokens hold ranges into the source, not copied substrings
(`Sources/Example/Tokenizer.swift:20-24`).

## Public surface

- `init(source: String)` — stores the source; does no work eagerly
  (`Sources/Example/Tokenizer.swift:14-16`).
- `func next() -> Token?` — returns the next token or `nil` at end
  (`Sources/Example/Tokenizer.swift:30-47`).

> TODO-VERIFY: whether `next()` is safe to call across threads — no isolation
> annotation is present in the source.

See also [[overview]], [[glossary]].
