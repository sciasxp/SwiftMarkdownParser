# ADR 0008: Concentrate native semantics and localization

## Status

Accepted

## Context

Native SwiftUI output attached user-facing meaning in three implementations:
the document renderer, adaptive block presentation, and rich-content fallbacks.
English labels were hardcoded in views, dynamic sentences were assembled at
call sites, and the shallow `SwiftUIRenderSemantics` utility owned only ordered
markers and code-token gap preservation. There was no package localization
resource.

This distribution made a terminology or accessibility correction a multi-file
change and made localization incomplete by construction. It also blurred the
distinction between package-owned interface text and verbatim Markdown content.

## Decision

Replace `SwiftUIRenderSemantics` with the in-process
`NativePresentationSemantics` module. Its interface accepts one typed `Message`
and returns a deferred `LocalizedStringResource`; it also owns the two pure
native-output decisions for ordered markers and semantic code runs.

Inject one semantic module value into `SwiftUIRenderer`,
`NativeAdaptivePresentation`, and `NativeRichContentProjection`. Views request
complete semantic messages instead of assembling or hardcoding labels. Keep
Markdown source, alternative text, identifiers, language names, and diagram
types as verbatim interpolation values.

Store interface text in a package-owned String Catalog, resolve it with
`#bundle`, use English as the source language, and ship Brazilian Portuguese.
Keep translator comments at the typed message construction site. Test every
message through the same module interface in a non-default locale.

## Consequences

- Visible native fallback text, VoiceOver meaning, and renderer errors share one
  vocabulary and one localization owner.
- Dynamic messages remain reorderable by translators instead of concatenating
  separately localized fragments.
- Host locale overrides reach deferred package resources.
- Adding native interface text requires a typed role, a source value, and each
  supported translation together.
- Markdown document content is not accidentally extracted or translated.
- The package now declares a default localization and processes a String
  Catalog resource.

## Validation

Module tests resolve every semantic role through the Brazilian Portuguese
catalog, including all interpolated values. SwiftUI output tests continue to
materialize representative, adaptive, rich, and accessible documents through
the document seam.
