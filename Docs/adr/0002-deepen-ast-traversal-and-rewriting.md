# Deepen AST traversal and rewriting

SwiftMarkdownParser will expose AST Traversal and AST Rewrite as one in-process
deep module with two additive interfaces: `depthFirst()` provides lazy
depth-first preorder visits with stable context, and `rewriting(_:)` performs
one immutable bottom-up pass whose replacements are not revisited. Built-in
containers preserve metadata while reconstructing children, typed table
relationships fail with `ASTRewriteError` when violated, and custom containers
opt into descendant rewriting through `ASTRewritableNode`; generic recursive
walkers in consumers and tests are replaced at this seam, while renderers
retain their semantic rendering recursion.
