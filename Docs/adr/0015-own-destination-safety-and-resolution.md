# ADR 0015: Own destination safety and resolution in MarkdownDestination

## Status

Accepted. Narrows the image-resolution ownership recorded in ADR 0007.

## Context

Three places decided whether a link, image, or autolink destination was safe and
which URL it represented: `HTMLSupport.normalizeURL` for HTML links, images,
and autolinks; `NativeInlineProjection.resolvedURL` for native links and
autolinks; and `NativeRichContentProjection.resolvedImageURL` for native images.
Each was a private copy of the same idea, and the copies had drifted.

Apart from empty input in native output, all three refused only destinations
whose trimmed, lowercased text started with
`javascript:` or `data:`. Browsers read an `href` with the WHATWG URL parser,
which trims C0 controls and spaces and removes TAB, LF, and CR anywhere before
it reads the scheme. A destination such as `java<TAB>script:alert(1)` passed
the prefix check, reached `href` unchanged, and ran as `javascript:` in the
browser. Markdown Source reaches this through a reference definition
(`[x]: <java<TAB>script:alert(1)>`), and any document built or rewritten by the
host reaches it directly. `vbscript:`, explicit `file:`, and every other scheme
were also accepted.

Resolution against the host base URL differed too. HTML resolved only when the
destination did not contain `://` and otherwise emitted the source text; the
native modules always used Foundation.

## Decision

Introduce the internal `MarkdownDestination` module in the core, outside
`Rendering/`. It is the only place that decides:

1. whether a destination is safe; and
2. which resolved URL it represents.

The policy is a fixed list with no new public interface:

- **Normalize before deciding.** Trim C0 controls, spaces, and Unicode
  whitespace from both ends, and remove TAB, LF, and CR everywhere, as the
  WHATWG URL parser does.
- **Allow** an explicit `http`, `https`, or `mailto` scheme, relative
  references, and fragments (`#...`).
- **Refuse** every other explicit scheme, including `javascript:`, `vbscript:`,
  `data:`, and `file:`, and refuse a destination that is empty after
  normalization or that Foundation cannot represent.
- **Read the scheme by Unicode scalar.** A combining mark, joiner, or
  variation selector right after the colon (`javascript:\u{301}alert(1)`)
  fuses with it into one `Character`, which hid the scheme from a
  `Character`-based check; the destination was then treated as relative and
  Foundation kept its scheme while resolving it.
- **Resolve** relative references with one algorithm, Foundation's
  `URL(string:relativeTo:)`, against the renderer's `baseURL`.
- **Check the resolved URL again.** The scheme of the URL that will be
  followed must be in the allowlist, and Foundation's `scheme` must agree with
  the scheme a browser reads from its serialization. The only exception is a
  `file:` URL that results from resolving a relative reference against a
  host-chosen `file:` base; the host decided that base, the Markdown did not.
  Even then, a protocol-relative reference whose `file:` result names a host
  is refused: `//evil.com/share` against `file:///docs/` would become
  `file://evil.com/share`, a network share the host never chose. A relative
  path against a base that already names a host, such as
  `file://server/share/`, keeps that host.

`HTMLRenderer` serializes the resolved URL's `absoluteString` and escapes it as
an attribute; it no longer applies the `contains("://")` heuristic. Native Inline
Projection and the Native Rich Content Seam use the resolved `URL` directly.
When a destination is refused, each output keeps its existing fallback: the
link's text, the image's alt text, or the autolink's text.

## Relationship to ADR 0003

ADR 0003 keeps renderers output-specific and removed shared renderer protocols
and contexts. This module does not reintroduce one. Whether a destination is
safe, and what it points to, is meaning of the Markdown Document, the same for
every output; it is not a rendering protocol. Each renderer still owns how it
presents a destination: HTML serialization and escaping, or native link and
image presentation.

## Relationship to ADR 0007

ADR 0007 placed safe image resolution inside `NativeRichContentProjection`.
That seam still owns adapter invocation and fallbacks, and it still keeps
unsafe destinations out of public adapter requests, but the decision itself now
belongs to `MarkdownDestination`.

## Consequences

- Splitting a scheme with TAB, LF, or CR no longer bypasses the check in any
  output.
- A combining mark, ZWJ, ZWNJ, or variation selector after the scheme's colon
  no longer bypasses the check, with or without a base URL.
- Behavior change: a protocol-relative reference against a `file:` base, such
  as `[x](//evil.com/share)`, renders as its fallback text. Against an `http`
  or `https` base it still takes the base's scheme.
- Behavior change: destinations with schemes outside the allowlist, such as
  `vbscript:`, `ftp:`, `irc:`, or explicit `file:`, now render as their
  fallback text in HTML and native output. An empty destination, such as
  `[x]()`, also renders as text instead of `href=""`.
- HTML serializes Foundation's representation, so characters that are invalid
  in a URL are percent-encoded (`my page.html` becomes `my%20page.html`), as
  CommonMark's reference output does.
- Known limit: inline pointy-bracket destinations keep their angle brackets in
  the Markdown Document (`[a](<my page.html>)` has the destination
  `<my page.html>`), a construction defect outside this decision. HTML used to
  emit `href="<my page.html>"` and now emits `href="%3Cmy%20page.html%3E"`;
  both are broken by that defect, not by this policy.
- Known limit: raw HTML blocks and inline HTML are outside this module. Their
  safety still depends on `HTMLRenderOptions.sanitizeHTML` and on the host.
