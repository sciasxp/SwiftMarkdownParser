import Testing
import Foundation
@testable import SwiftMarkdownParser

/// Comprehensive test suite for HTMLRenderer functionality.
///
/// This test suite covers all aspects of HTML rendering including:
/// - Basic CommonMark elements
/// - GFM extensions (tables, strikethrough, task lists)
/// - Security features (sanitization, URL validation)
/// - Custom styling and CSS classes
/// - Edge cases and error handling
@Suite struct HTMLRendererTests {

    let renderer: HTMLRenderer
    let parser: SwiftMarkdownParser

    init() {
        renderer = HTMLRenderer()
        parser = SwiftMarkdownParser()
    }

    // MARK: - Basic HTML Elements Tests

    @Test func renderTextNode_escapeHTMLCharacters() async throws {
        let textNode = AST.TextNode(content: "Hello & <world> \"quoted\" 'text'")
        let html = try await renderer.render(node: textNode)
        #expect(html == "Hello &amp; &lt;world&gt; &quot;quoted&quot; &#39;text&#39;")
    }

    @Test func renderTextNode_emptyString() async throws {
        let textNode = AST.TextNode(content: "")
        let html = try await renderer.render(node: textNode)
        #expect(html == "")
    }

    @Test func renderTextNode_specialCharacters() async throws {
        let textNode = AST.TextNode(content: "© ® ™ € £ ¥")
        let html = try await renderer.render(node: textNode)
        #expect(html == "© ® ™ € £ ¥")
    }

    @Test func renderParagraphNode_basicParagraph() async throws {
        let textNode = AST.TextNode(content: "This is a paragraph.")
        let paragraph = AST.ParagraphNode(children: [textNode])
        let html = try await renderer.render(node: paragraph)
        #expect(html == "<p>This is a paragraph.</p>\n")
    }

    @Test func renderParagraphNode_multipleChildren() async throws {
        let children: [ASTNode] = [
            AST.TextNode(content: "Hello "),
            AST.EmphasisNode(children: [AST.TextNode(content: "world")]),
            AST.TextNode(content: "!")
        ]
        let paragraph = AST.ParagraphNode(children: children)
        let html = try await renderer.render(node: paragraph)
        #expect(html == "<p>Hello <em>world</em>!</p>\n")
    }

    @Test func renderParagraphNode_empty() async throws {
        let paragraph = AST.ParagraphNode(children: [])
        let html = try await renderer.render(node: paragraph)
        #expect(html == "<p></p>\n")
    }

    @Test func renderHeadingNode_allLevels() async throws {
        for level in 1...6 {
            let textNode = AST.TextNode(content: "Heading \(level)")
            let heading = AST.HeadingNode(level: level, children: [textNode])
            let html = try await renderer.render(node: heading)
            #expect(html == "<h\(level)>Heading \(level)</h\(level)>\n")
        }
    }

    @Test func renderHeadingNode_withInlineElements() async throws {
        let children: [ASTNode] = [
            AST.TextNode(content: "Bold "),
            AST.StrongEmphasisNode(children: [AST.TextNode(content: "heading")]),
            AST.TextNode(content: " with "),
            AST.CodeSpanNode(content: "code")
        ]
        let heading = AST.HeadingNode(level: 2, children: children)
        let html = try await renderer.render(node: heading)
        #expect(html == "<h2>Bold <strong>heading</strong> with <code>code</code></h2>\n")
    }

    // MARK: - Emphasis and Strong Tests

    @Test func renderEmphasisNode_basicEmphasis() async throws {
        let textNode = AST.TextNode(content: "emphasized")
        let emphasis = AST.EmphasisNode(children: [textNode])
        let html = try await renderer.render(node: emphasis)
        #expect(html == "<em>emphasized</em>")
    }

    @Test func renderEmphasisNode_nestedElements() async throws {
        let children: [ASTNode] = [
            AST.TextNode(content: "italic with "),
            AST.StrongEmphasisNode(children: [AST.TextNode(content: "bold")])
        ]
        let emphasis = AST.EmphasisNode(children: children)
        let html = try await renderer.render(node: emphasis)
        #expect(html == "<em>italic with <strong>bold</strong></em>")
    }

    @Test func renderStrongEmphasisNode_basicStrong() async throws {
        let textNode = AST.TextNode(content: "strong")
        let strong = AST.StrongEmphasisNode(children: [textNode])
        let html = try await renderer.render(node: strong)
        #expect(html == "<strong>strong</strong>")
    }

    @Test func renderStrongEmphasisNode_nestedElements() async throws {
        let children: [ASTNode] = [
            AST.TextNode(content: "bold with "),
            AST.EmphasisNode(children: [AST.TextNode(content: "italic")])
        ]
        let strong = AST.StrongEmphasisNode(children: children)
        let html = try await renderer.render(node: strong)
        #expect(html == "<strong>bold with <em>italic</em></strong>")
    }

    // MARK: - Link and Image Tests

    @Test func renderLinkNode_basicLink() async throws {
        let textNode = AST.TextNode(content: "Swift")
        let link = AST.LinkNode(url: "https://swift.org", title: nil, children: [textNode])
        let html = try await renderer.render(node: link)
        #expect(html == "<a href=\"https://swift.org\">Swift</a>")
    }

    @Test func renderLinkNode_withTitle() async throws {
        let textNode = AST.TextNode(content: "Swift")
        let link = AST.LinkNode(url: "https://swift.org", title: "Swift Programming Language", children: [textNode])
        let html = try await renderer.render(node: link)
        #expect(html == "<a href=\"https://swift.org\" title=\"Swift Programming Language\">Swift</a>")
    }

    @Test func renderLinkNode_complexContent() async throws {
        let children: [ASTNode] = [
            AST.TextNode(content: "Visit "),
            AST.StrongEmphasisNode(children: [AST.TextNode(content: "Swift.org")])
        ]
        let link = AST.LinkNode(url: "https://swift.org", title: nil, children: children)
        let html = try await renderer.render(node: link)
        #expect(html == "<a href=\"https://swift.org\">Visit <strong>Swift.org</strong></a>")
    }

    @Test func renderLinkNode_unsafeURL() async throws {
        let textNode = AST.TextNode(content: "Unsafe")
        let link = AST.LinkNode(url: "javascript:alert('xss')", title: nil, children: [textNode])
        let html = try await renderer.render(node: link)
        #expect(html == "Unsafe") // Should render as plain text
    }

    @Test func renderLinkNode_dataURL() async throws {
        let textNode = AST.TextNode(content: "Data")
        let link = AST.LinkNode(url: "data:text/html,<script>alert('xss')</script>", title: nil, children: [textNode])
        let html = try await renderer.render(node: link)
        #expect(html == "Data") // Should render as plain text
    }

    @Test func renderImageNode_basicImage() async throws {
        let image = AST.ImageNode(url: "https://example.com/image.jpg", altText: "Alt text", title: nil)
        let html = try await renderer.render(node: image)
        #expect(html == "<img alt=\"Alt text\" src=\"https://example.com/image.jpg\" />")
    }

    @Test func renderImageNode_withTitle() async throws {
        let image = AST.ImageNode(url: "https://example.com/image.jpg", altText: "Alt text", title: "Image title")
        let html = try await renderer.render(node: image)
        #expect(html == "<img alt=\"Alt text\" src=\"https://example.com/image.jpg\" title=\"Image title\" />")
    }

    @Test func renderImageNode_unsafeURL() async throws {
        let image = AST.ImageNode(url: "javascript:alert('xss')", altText: "Alt text", title: nil)
        let html = try await renderer.render(node: image)
        #expect(html == "Alt text") // Should render as plain text
    }

    @Test func renderImageNode_emptyAlt() async throws {
        let image = AST.ImageNode(url: "https://example.com/image.jpg", altText: "", title: nil)
        let html = try await renderer.render(node: image)
        #expect(html == "<img alt=\"\" src=\"https://example.com/image.jpg\" />")
    }

    // MARK: - List Tests

    @Test func renderListNode_unorderedList() async throws {
        let item1 = AST.ListItemNode(children: [AST.ParagraphNode(children: [AST.TextNode(content: "Item 1")])])
        let item2 = AST.ListItemNode(children: [AST.ParagraphNode(children: [AST.TextNode(content: "Item 2")])])
        let list = AST.ListNode(isOrdered: false, startNumber: nil, items: [item1, item2])

        let html = try await renderer.render(node: list)
        let expected = "<ul>\n<li><p>Item 1</p>\n</li>\n<li><p>Item 2</p>\n</li>\n</ul>\n"
        #expect(html == expected)
    }

    @Test func renderListNode_orderedList() async throws {
        let item1 = AST.ListItemNode(children: [AST.ParagraphNode(children: [AST.TextNode(content: "First")])])
        let item2 = AST.ListItemNode(children: [AST.ParagraphNode(children: [AST.TextNode(content: "Second")])])
        let list = AST.ListNode(isOrdered: true, startNumber: 1, items: [item1, item2])

        let html = try await renderer.render(node: list)
        let expected = "<ol>\n<li><p>First</p>\n</li>\n<li><p>Second</p>\n</li>\n</ol>\n"
        #expect(html == expected)
    }

    @Test func renderListNode_orderedListWithCustomStart() async throws {
        let item1 = AST.ListItemNode(children: [AST.ParagraphNode(children: [AST.TextNode(content: "Fifth")])])
        let item2 = AST.ListItemNode(children: [AST.ParagraphNode(children: [AST.TextNode(content: "Sixth")])])
        let list = AST.ListNode(isOrdered: true, startNumber: 5, items: [item1, item2])

        let html = try await renderer.render(node: list)
        let expected = "<ol start=\"5\">\n<li><p>Fifth</p>\n</li>\n<li><p>Sixth</p>\n</li>\n</ol>\n"
        #expect(html == expected)
    }

    @Test func renderListItemNode_multipleChildren() async throws {
        let paragraph = AST.ParagraphNode(children: [AST.TextNode(content: "Item text")])
        let codeBlock = AST.CodeBlockNode(content: "code example", language: "swift")
        let listItem = AST.ListItemNode(children: [paragraph, codeBlock])

        let html = try await renderer.render(node: listItem)
        let expected = "<li><p>Item text</p>\n<pre><code class=\"language-swift\">code example</code></pre>\n</li>\n"
        #expect(html == expected)
    }

    // MARK: - BlockQuote Tests

    @Test func renderBlockQuoteNode_singleParagraph() async throws {
        let paragraph = AST.ParagraphNode(children: [AST.TextNode(content: "This is a quote.")])
        let blockQuote = AST.BlockQuoteNode(children: [paragraph])

        let html = try await renderer.render(node: blockQuote)
        let expected = "<blockquote>\n<p>This is a quote.</p>\n</blockquote>\n"
        #expect(html == expected)
    }

    @Test func renderBlockQuoteNode_multipleParagraphs() async throws {
        let paragraph1 = AST.ParagraphNode(children: [AST.TextNode(content: "First paragraph.")])
        let paragraph2 = AST.ParagraphNode(children: [AST.TextNode(content: "Second paragraph.")])
        let blockQuote = AST.BlockQuoteNode(children: [paragraph1, paragraph2])

        let html = try await renderer.render(node: blockQuote)
        let expected = "<blockquote>\n<p>First paragraph.</p>\n<p>Second paragraph.</p>\n</blockquote>\n"
        #expect(html == expected)
    }

    @Test func renderBlockQuoteNode_nestedBlockQuote() async throws {
        let innerParagraph = AST.ParagraphNode(children: [AST.TextNode(content: "Nested quote.")])
        let innerBlockQuote = AST.BlockQuoteNode(children: [innerParagraph])
        let outerParagraph = AST.ParagraphNode(children: [AST.TextNode(content: "Outer quote.")])
        let outerBlockQuote = AST.BlockQuoteNode(children: [outerParagraph, innerBlockQuote])

        let html = try await renderer.render(node: outerBlockQuote)
        let expected = "<blockquote>\n<p>Outer quote.</p>\n<blockquote>\n<p>Nested quote.</p>\n</blockquote>\n</blockquote>\n"
        #expect(html == expected)
    }

    // MARK: - Code Tests

    @Test func renderCodeBlockNode_basicCodeBlock() async throws {
        let codeBlock = AST.CodeBlockNode(content: "let x = 42", language: nil)
        let html = try await renderer.render(node: codeBlock)
        #expect(html == "<pre><code>let x = 42</code></pre>\n")
    }

    @Test func renderCodeBlockNode_withLanguage() async throws {
        let codeBlock = AST.CodeBlockNode(content: "let x = 42", language: "swift")
        let html = try await renderer.render(node: codeBlock)
        #expect(html == "<pre><code class=\"language-swift\">let x = 42</code></pre>\n")
    }

    @Test func renderCodeBlockNode_escapeHTML() async throws {
        let codeBlock = AST.CodeBlockNode(content: "<script>alert('xss')</script>", language: "html")
        let html = try await renderer.render(node: codeBlock)
        #expect(html == "<pre><code class=\"language-html\">&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;</code></pre>\n")
    }

    @Test func renderCodeBlockNode_multilineCode() async throws {
        let code = """
        function hello() {
            console.log("Hello, World!");
        }
        """
        let codeBlock = AST.CodeBlockNode(content: code, language: "javascript")
        let html = try await renderer.render(node: codeBlock)
        let expected = "<pre><code class=\"language-javascript\">function hello() {\n    console.log(&quot;Hello, World!&quot;);\n}</code></pre>\n"
        #expect(html == expected)
    }

    @Test func renderCodeSpanNode_basicCodeSpan() async throws {
        let codeSpan = AST.CodeSpanNode(content: "let x = 42")
        let html = try await renderer.render(node: codeSpan)
        #expect(html == "<code>let x = 42</code>")
    }

    @Test func renderCodeSpanNode_escapeHTML() async throws {
        let codeSpan = AST.CodeSpanNode(content: "<script>")
        let html = try await renderer.render(node: codeSpan)
        #expect(html == "<code>&lt;script&gt;</code>")
    }

    // MARK: - Line Break Tests

    @Test func renderLineBreakNode_hardBreak() async throws {
        let lineBreak = AST.LineBreakNode(isHard: true)
        let html = try await renderer.render(node: lineBreak)
        #expect(html == "<br />\n")
    }

    @Test func renderLineBreakNode_softBreak() async throws {
        let lineBreak = AST.LineBreakNode(isHard: false)
        let html = try await renderer.render(node: lineBreak)
        #expect(html == "\n")
    }

    @Test func renderSoftBreakNode() async throws {
        let softBreak = AST.SoftBreakNode()
        let html = try await renderer.render(node: softBreak)
        #expect(html == " ")
    }

    // MARK: - Thematic Break Tests

    @Test func renderThematicBreakNode() async throws {
        let thematicBreak = AST.ThematicBreakNode()
        let html = try await renderer.render(node: thematicBreak)
        #expect(html == "<hr />\n")
    }

    // MARK: - Autolink Tests

    @Test func renderAutolinkNode_basicAutolink() async throws {
        let autolink = AST.AutolinkNode(url: "https://example.com", text: "https://example.com")
        let html = try await renderer.render(node: autolink)
        #expect(html == "<a href=\"https://example.com\">https://example.com</a>")
    }

    @Test func renderAutolinkNode_emailAutolink() async throws {
        let autolink = AST.AutolinkNode(url: "mailto:test@example.com", text: "test@example.com")
        let html = try await renderer.render(node: autolink)
        #expect(html == "<a href=\"mailto:test@example.com\">test@example.com</a>")
    }

    @Test func renderAutolinkNode_unsafeURL() async throws {
        let autolink = AST.AutolinkNode(url: "javascript:alert('xss')", text: "javascript:alert('xss')")
        let html = try await renderer.render(node: autolink)
        #expect(html == "javascript:alert(&#39;xss&#39;)") // Should render as plain text
    }

    // MARK: - HTML Block and Inline Tests

    @Test func renderHTMLBlockNode_withSanitization() async throws {
        let htmlBlock = AST.HTMLBlockNode(content: "<script>alert('xss')</script>")
        let html = try await renderer.render(node: htmlBlock)
        #expect(html == "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;")
    }

    @Test func renderHTMLBlockNode_withoutSanitization() async throws {
        let context = RenderContext(sanitizeHTML: false)
        let customRenderer = HTMLRenderer(context: context)
        let htmlBlock = AST.HTMLBlockNode(content: "<div>Safe HTML</div>")
        let html = try await customRenderer.render(node: htmlBlock)
        #expect(html == "<div>Safe HTML</div>")
    }

    @Test func renderHTMLInlineNode_withSanitization() async throws {
        let htmlInline = AST.HTMLInlineNode(content: "<em>emphasis</em>")
        let html = try await renderer.render(node: htmlInline)
        #expect(html == "&lt;em&gt;emphasis&lt;/em&gt;")
    }

    @Test func renderHTMLInlineNode_withoutSanitization() async throws {
        let context = RenderContext(sanitizeHTML: false)
        let customRenderer = HTMLRenderer(context: context)
        let htmlInline = AST.HTMLInlineNode(content: "<strong>bold</strong>")
        let html = try await customRenderer.render(node: htmlInline)
        #expect(html == "<strong>bold</strong>")
    }

    // MARK: - GFM Extension Tests

    @Test func renderStrikethroughNode_basicStrikethrough() async throws {
        let textNode = AST.TextNode(content: "deleted")
        let strikethrough = AST.StrikethroughNode(content: [textNode])
        let html = try await renderer.render(node: strikethrough)
        #expect(html == "<del>deleted</del>")
    }

    @Test func renderStrikethroughNode_nestedElements() async throws {
        let children: [ASTNode] = [
            AST.TextNode(content: "deleted "),
            AST.EmphasisNode(children: [AST.TextNode(content: "italic")])
        ]
        let strikethrough = AST.StrikethroughNode(content: children)
        let html = try await renderer.render(node: strikethrough)
        #expect(html == "<del>deleted <em>italic</em></del>")
    }

    @Test func renderGFMTableNode_basicTable() async throws {
        let headerCell1 = AST.GFMTableCellNode(content: "Name", isHeader: true)
        let headerCell2 = AST.GFMTableCellNode(content: "Age", isHeader: true)
        let headerRow = AST.GFMTableRowNode(cells: [headerCell1, headerCell2], isHeader: true)

        let dataCell1 = AST.GFMTableCellNode(content: "John", isHeader: false)
        let dataCell2 = AST.GFMTableCellNode(content: "25", isHeader: false)
        let dataRow = AST.GFMTableRowNode(cells: [dataCell1, dataCell2], isHeader: false)

        let table = AST.GFMTableNode(rows: [headerRow, dataRow], alignments: [.none, .none])
        let html = try await renderer.render(node: table)

        let expected = """
        <table>
        <thead>
        <tr>
        <th scope="col">Name</th>
        <th scope="col">Age</th>
        </tr>
        </thead>
        <tbody>
        <tr>
        <td>John</td>
        <td>25</td>
        </tr>
        </tbody>
        </table>

        """
        #expect(html == expected)
    }

    @Test func renderGFMTableNode_withAlignment() async throws {
        let headerCell1 = AST.GFMTableCellNode(content: "Left", isHeader: true)
        let headerCell2 = AST.GFMTableCellNode(content: "Center", isHeader: true)
        let headerCell3 = AST.GFMTableCellNode(content: "Right", isHeader: true)
        let headerRow = AST.GFMTableRowNode(cells: [headerCell1, headerCell2, headerCell3], isHeader: true)

        let dataCell1 = AST.GFMTableCellNode(content: "L", isHeader: false)
        let dataCell2 = AST.GFMTableCellNode(content: "C", isHeader: false)
        let dataCell3 = AST.GFMTableCellNode(content: "R", isHeader: false)
        let dataRow = AST.GFMTableRowNode(cells: [dataCell1, dataCell2, dataCell3], isHeader: false)

        let table = AST.GFMTableNode(rows: [headerRow, dataRow], alignments: [.left, .center, .right])
        let html = try await renderer.render(node: table)

        #expect(html.contains("style=\"text-align: left\""))
        #expect(html.contains("style=\"text-align: center\""))
        #expect(html.contains("style=\"text-align: right\""))
    }

    // MARK: - Custom Styling Tests

    @Test func renderWithCustomCSSClasses() async throws {
        let context = RenderContext(
            styleConfiguration: StyleConfiguration(
                cssClasses: [
                    .paragraph: "custom-paragraph",
                    .heading: "custom-heading",
                    .emphasis: "custom-italic"
                ]
            )
        )
        let customRenderer = HTMLRenderer(context: context)

        let textNode = AST.TextNode(content: "Hello")
        let paragraph = AST.ParagraphNode(children: [textNode])
        let html = try await customRenderer.render(node: paragraph)

        #expect(html == "<p class=\"custom-paragraph\">Hello</p>\n")
    }

    @Test func renderWithSourcePositions() async throws {
        let sourceLocation = makeTestSourceLocation(line: 5, column: 10, offset: 100)
        let context = RenderContext(
            styleConfiguration: StyleConfiguration(
                includeSourcePositions: true
            )
        )
        let customRenderer = HTMLRenderer(context: context)

        let textNode = AST.TextNode(content: "Hello")
        let paragraph = AST.ParagraphNode(children: [textNode], sourceLocation: sourceLocation)
        let html = try await customRenderer.render(node: paragraph)

        #expect(html.contains("data-source-line=\"5\""))
        #expect(html.contains("data-source-column=\"10\""))
    }

    @Test func renderWithCustomAttributes() async throws {
        let context = RenderContext(
            styleConfiguration: StyleConfiguration(
                customAttributes: [
                    .paragraph: ["data-test": "value", "id": "test-paragraph"]
                ]
            )
        )
        let customRenderer = HTMLRenderer(context: context)

        let textNode = AST.TextNode(content: "Hello")
        let paragraph = AST.ParagraphNode(children: [textNode])
        let html = try await customRenderer.render(node: paragraph)

        #expect(html.contains("data-test=\"value\""))
        #expect(html.contains("id=\"test-paragraph\""))
    }

    @Test func renderWithSyntaxHighlightingDisabled() async throws {
        let context = RenderContext(
            styleConfiguration: StyleConfiguration(
                syntaxHighlighting: SyntaxHighlightingConfig(enabled: false)
            )
        )
        let customRenderer = HTMLRenderer(context: context)

        let codeBlock = AST.CodeBlockNode(content: "let x = 42", language: "swift")
        let html = try await customRenderer.render(node: codeBlock)

        #expect(html == "<pre><code class=\"language-swift\">let x = 42</code></pre>\n")
        #expect(!html.contains("hljs-"))  // Should not contain syntax highlighting classes
    }

    @Test func renderWithCustomSyntaxHighlightingPrefix() async throws {
        let context = RenderContext(
            styleConfiguration: StyleConfiguration(
                syntaxHighlighting: SyntaxHighlightingConfig(
                    enabled: true,
                    cssPrefix: "hljs-"
                )
            )
        )
        let customRenderer = HTMLRenderer(context: context)

        let codeBlock = AST.CodeBlockNode(content: "let x = 42", language: "swift")
        let html = try await customRenderer.render(node: codeBlock)

        #expect(html.contains("hljs-keyword"))  // Should contain syntax highlighting with custom prefix
        #expect(html.contains("language-swift"))  // Should still have language class on code element
    }

    // MARK: - URL Normalization Tests

    @Test func renderWithBaseURL() async throws {
        let baseURL = URL(string: "https://example.com/docs/")!
        let context = RenderContext(baseURL: baseURL)
        let customRenderer = HTMLRenderer(context: context)

        let textNode = AST.TextNode(content: "Link")
        let link = AST.LinkNode(url: "page.html", title: nil, children: [textNode])
        let html = try await customRenderer.render(node: link)

        #expect(html == "<a href=\"https://example.com/docs/page.html\">Link</a>")
    }

    @Test func renderWithBaseURL_absoluteURLUnchanged() async throws {
        let baseURL = URL(string: "https://example.com/docs/")!
        let context = RenderContext(baseURL: baseURL)
        let customRenderer = HTMLRenderer(context: context)

        let textNode = AST.TextNode(content: "Link")
        let link = AST.LinkNode(url: "https://other.com/page.html", title: nil, children: [textNode])
        let html = try await customRenderer.render(node: link)

        #expect(html == "<a href=\"https://other.com/page.html\">Link</a>")
    }

    // MARK: - Document Rendering Tests

    @Test func renderDocument_multipleElements() async throws {
        let heading = AST.HeadingNode(level: 1, children: [AST.TextNode(content: "Title")])
        let paragraph = AST.ParagraphNode(children: [AST.TextNode(content: "Content")])
        let document = AST.DocumentNode(children: [heading, paragraph])

        let html = try await renderer.render(document: document)
        let expected = "<h1>Title</h1>\n<p>Content</p>\n"
        #expect(html == expected)
    }

    @Test func renderDocument_emptyDocument() async throws {
        let document = AST.DocumentNode(children: [])
        let html = try await renderer.render(document: document)
        #expect(html == "")
    }

    // MARK: - Error Handling Tests

    @Test func renderUnsupportedNodeType() async throws {
        let unsupportedNode = UnsupportedTestNode()

        await #expect(throws: RendererError.self) {
            _ = try await renderer.render(node: unsupportedNode)
        }
    }

    // MARK: - Integration Tests

    @Test func parseAndRenderComplexDocument() async throws {
        let markdown = """
        # Main Title

        This is a paragraph with **bold** and *italic* text.

        ## Code Example

        ```swift
        let greeting = "Hello, World!"
        print(greeting)
        ```

        ### List Example

        - Item 1
        - Item 2 with `inline code`
        - Item 3

        > This is a blockquote with a [link](https://example.com).

        ---

        | Feature | Status |
        |---------|--------|
        | Tables  | ✅     |
        | Links   | ✅     |
        """

        let document = try await parser.parseToAST(markdown)
        let html = try await renderer.render(document: document)

        // Verify key elements are present
        #expect(html.contains("<h1>Main Title</h1>"))
        #expect(html.contains("<strong>bold</strong>"))
        #expect(html.contains("<em>italic</em>"))
        #expect(html.contains("<code class=\"language-swift\">"))
        #expect(html.contains("<ul>"))
        #expect(html.contains("<code>inline code</code>"))
        #expect(html.contains("<blockquote>"))
        #expect(html.contains("<a href=\"https://example.com\">"))
        #expect(html.contains("<hr />"))
        #expect(html.contains("<table>"))
        #expect(html.contains("<th scope=\"col\">Feature</th>"))
        #expect(html.contains("<td>✅</td>"))
    }

    // MARK: - Performance Tests

    @Test func renderLargeDocument() async throws {
        // Create a large document with many elements
        var children: [ASTNode] = []

        for i in 1...1000 {
            let heading = AST.HeadingNode(level: 2, children: [AST.TextNode(content: "Section \(i)")])
            let paragraph = AST.ParagraphNode(children: [AST.TextNode(content: "Content for section \(i)")])
            children.append(heading)
            children.append(paragraph)
        }

        let document = AST.DocumentNode(children: children)

        let startTime = Date()
        let html = try await renderer.render(document: document)
        let endTime = Date()

        let renderTime = endTime.timeIntervalSince(startTime)
        print("Rendered 1000 sections in \(renderTime) seconds")

        // Verify the output contains expected elements
        #expect(html.contains("<h2>Section 1</h2>"))
        #expect(html.contains("<h2>Section 1000</h2>"))
        #expect(renderTime < 1.0) // Should render quickly
    }
}
