# Keep renderers output-specific

SwiftMarkdownParser will keep HTML and native SwiftUI output behind separate
interfaces that both accept a complete `AST.DocumentNode`. Shared renderer
protocols and configuration contexts are removed because the outputs do not
vary at one useful seam: HTML owns escaping, browser features, and document
composition, while SwiftUI owns main-actor view construction. We accept some
parallel tree dispatch to keep output policy local and prevent the least-common
denominator interface from leaking one renderer's requirements into the other.
