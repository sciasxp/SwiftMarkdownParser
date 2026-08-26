# Centralize syntax-highlighting orchestration

SwiftMarkdownParser will expose one actor-isolated `SyntaxHighlighter`
interface for semantic code classification and keep its six built-in language
adapters internal. The module owns identifier normalization, aliases, truthful
support discovery, token validation, best-effort fallback, and bounded LRU
caching; HTML presentation remains in `HTMLCodeBlockRenderer`. We deliberately
remove the public engine registry and cache interfaces, accepting that callers
cannot register custom languages in exchange for one source of truth, valid
source-bound ranges, and a smaller interface shared by renderers and direct
consumers.
