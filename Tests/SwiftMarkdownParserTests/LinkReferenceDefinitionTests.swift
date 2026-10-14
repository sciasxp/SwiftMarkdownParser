import Testing
@testable import SwiftMarkdownParser

/// Link Reference Definitions at the Source → Document seam: the examples of
/// CommonMark 0.30 section 4.7 plus the block contexts this parser supports.
///
/// Each case compares a compact semantic signature of the document instead of
/// HTML, so renderer policy (escaping, percent-encoding, raw HTML) stays out of
/// the comparison. Signature notation:
///
/// - `p{…}`, `h1{…}`, `quote{…}`, `list{item{…}}`, `code{…}`, `html{…}`,
///   `math{…}`; sibling blocks are separated by a single space.
/// - `[text](url "title")` for links, `![alt](url)` for images, `<url>` for
///   autolinks; a soft or hard line break is `\n`. Code content drops its
///   trailing line endings.
///
/// Every 4.7 example is ported; none is out of scope. A case that still fails
/// lists its causes in `knownIssues`; the cause names what the case is waiting
/// for (ADR 0016).
@Suite struct LinkReferenceDefinitionTests {
    struct Case: CustomTestStringConvertible, Sendable {
        let name: String
        let markdown: String
        let expected: String
        var knownIssues: [KnownIssue] = []

        var testDescription: String { name }
    }

    /// Why a case still fails; a case lists every cause it depends on.
    enum KnownIssue: String, Sendable {
        case rawLabel = "a shortcut reference is matched on its decoded link text, not on its raw label"
    }

    static let specExamples: [Case] = [
        Case(
            name: "Example 192",
            markdown: "[foo]: /url \"title\"\n\n[foo]\n",
            expected: #"p{[foo](/url "title")}"#
        ),
        Case(
            name: "Example 193",
            markdown: "   [foo]: \n      /url  \n           'the title'  \n\n[foo]\n",
            expected: #"p{[foo](/url "the title")}"#
        ),
        Case(
            name: "Example 194",
            markdown: "[Foo*bar\\]]:my_(url) 'title (with parens)'\n\n[Foo*bar\\]]\n",
            expected: #"p{[Foo*bar]](my_(url) "title (with parens)")}"#,
            knownIssues: [.rawLabel]
        ),
        Case(
            name: "Example 195",
            markdown: "[Foo bar]:\n<my url>\n'title'\n\n[Foo bar]\n",
            expected: #"p{[Foo bar](my url "title")}"#
        ),
        Case(
            name: "Example 196",
            markdown: "[foo]: /url '\ntitle\nline1\nline2\n'\n\n[foo]\n",
            expected: "p{[foo](/url \"\ntitle\nline1\nline2\n\")}"
        ),
        Case(
            name: "Example 197",
            markdown: "[foo]: /url 'title\n\nwith blank line'\n\n[foo]\n",
            expected: "p{[foo]: /url 'title} p{with blank line'} p{[foo]}"
        ),
        Case(
            name: "Example 198",
            markdown: "[foo]:\n/url\n\n[foo]\n",
            expected: "p{[foo](/url)}"
        ),
        Case(
            name: "Example 199",
            markdown: "[foo]:\n\n[foo]\n",
            expected: "p{[foo]:} p{[foo]}"
        ),
        Case(
            name: "Example 200",
            markdown: "[foo]: <>\n\n[foo]\n",
            expected: "p{[foo]()}"
        ),
        Case(
            name: "Example 201",
            markdown: "[foo]: <bar>(baz)\n\n[foo]\n",
            expected: "p{[foo]: <bar>(baz)} p{[foo]}"
        ),
        Case(
            name: "Example 202",
            markdown: "[foo]: /url\\bar\\*baz \"foo\\\"bar\\baz\"\n\n[foo]\n",
            expected: #"p{[foo](/url\bar*baz "foo"bar\baz")}"#
        ),
        Case(
            name: "Example 203",
            markdown: "[foo]\n\n[foo]: url\n",
            expected: "p{[foo](url)}"
        ),
        Case(
            name: "Example 204",
            markdown: "[foo]\n\n[foo]: first\n[foo]: second\n",
            expected: "p{[foo](first)}"
        ),
        Case(
            name: "Example 205",
            markdown: "[FOO]: /url\n\n[Foo]\n",
            expected: "p{[Foo](/url)}"
        ),
        Case(
            name: "Example 206",
            markdown: "[ΑΓΩ]: /φου\n\n[αγω]\n",
            expected: "p{[αγω](/φου)}"
        ),
        Case(
            name: "Example 207",
            markdown: "[foo]: /url\n",
            expected: ""
        ),
        Case(
            name: "Example 208",
            markdown: "[\nfoo\n]: /url\nbar\n",
            expected: "p{bar}"
        ),
        Case(
            name: "Example 209",
            markdown: "[foo]: /url \"title\" ok\n",
            expected: #"p{[foo]: /url "title" ok}"#
        ),
        Case(
            name: "Example 210",
            markdown: "[foo]: /url\n\"title\" ok\n",
            expected: #"p{"title" ok}"#
        ),
        Case(
            name: "Example 211",
            markdown: "    [foo]: /url \"title\"\n\n[foo]\n",
            expected: #"code{[foo]: /url "title"} p{[foo]}"#
        ),
        Case(
            name: "Example 212",
            markdown: "```\n[foo]: /url\n```\n\n[foo]\n",
            expected: "code{[foo]: /url} p{[foo]}"
        ),
        Case(
            name: "Example 213",
            markdown: "Foo\n[bar]: /baz\n\n[bar]\n",
            expected: "p{Foo\n[bar]: /baz} p{[bar]}"
        ),
        Case(
            name: "Example 214",
            markdown: "# [Foo]\n[foo]: /url\n> bar\n",
            expected: "h1{[Foo](/url)} quote{p{bar}}"
        ),
        Case(
            name: "Example 215",
            markdown: "[foo]: /url\nbar\n===\n[foo]\n",
            expected: "h1{bar} p{[foo](/url)}"
        ),
        Case(
            name: "Example 216",
            markdown: "[foo]: /url\n===\n[foo]\n",
            expected: "p{===\n[foo](/url)}"
        ),
        Case(
            name: "Example 217",
            markdown: """
            [foo]: /foo-url "foo"
            [bar]: /bar-url
              "bar"
            [baz]: /baz-url

            [foo],
            [bar],
            [baz]

            """,
            expected: #"p{[foo](/foo-url "foo"),\#n[bar](/bar-url "bar"),\#n[baz](/baz-url)}"#
        ),
        Case(
            name: "Example 218",
            markdown: "[foo]\n\n> [foo]: /url\n",
            expected: "p{[foo](/url)} quote{}"
        ),
    ]

    static let blockContexts: [Case] = [
        Case(
            name: "Definition inside a $$ math block stays math",
            markdown: "$$\n[a]: https://example.com\n$$\n\n[a]\n",
            expected: "math{[a]: https://example.com} p{[a]}"
        ),
        Case(
            name: "Definition inside an HTML block stays HTML",
            markdown: "<div>\n[a]: https://example.com\n</div>\n\n[a]\n",
            expected: "html{<div>\n[a]: https://example.com\n</div>} p{[a]}"
        ),
        Case(
            name: "Definition cannot interrupt a paragraph",
            markdown: "para line\n[a]: https://example.com\n\n[a]\n",
            expected: "p{para line\n[a]: <https://example.com>} p{[a]}"
        ),
        Case(
            name: "Definition inside a block quote applies to the document",
            markdown: "> [a]: https://example.com\n\n[a]\n",
            expected: "quote{} p{[a](https://example.com)}"
        ),
        Case(
            name: "Definition inside a list item applies to the document",
            markdown: "- [a]: https://example.com\n\n[a]\n",
            expected: "list{item{}} p{[a](https://example.com)}"
        ),
        Case(
            name: "Title on the following line",
            markdown: "[a]: https://example.com\n\"Title\"\n\n[a]\n",
            expected: #"p{[a](https://example.com "Title")}"#
        ),
        Case(
            name: "Destination on the following line",
            markdown: "[a]:\nhttps://example.com\n\n[a]\n",
            expected: "p{[a](https://example.com)}"
        ),
        Case(
            name: "Definition inside a tilde fence stays code",
            markdown: "~~~\n[a]: https://example.com\n~~~\n\n[a]\n",
            expected: "code{[a]: https://example.com} p{[a]}"
        ),
        Case(
            name: "Indented definition is code",
            markdown: "    [a]: https://example.com\n\n[a]\n",
            expected: "code{[a]: https://example.com} p{[a]}"
        ),
        Case(
            name: "Definition on a continuation line of a list item applies to the document",
            markdown: "- a\n\n  [x]: /u\n\n  b\n\n[x]\n",
            expected: "list{item{p{a} p{b}}} p{[x](/u)}"
        ),
        Case(
            name: "List item that starts with a definition keeps its following blocks",
            markdown: "- [a]: /u\n\n  foo\n\n[a]\n",
            expected: "list{item{p{foo}}} p{[a](/u)}"
        ),
        Case(
            name: "Title on the following marked line of a block quote",
            markdown: "> [a]: /u\n> \"t\"\n\n[a]\n",
            expected: #"quote{} p{[a](/u "t")}"#
        ),
        Case(
            name: "Dashes after a paragraph of only definitions are a thematic break",
            markdown: "[foo]: /url\n---\n[foo]\n",
            expected: "thematicBreak{} p{[foo](/url)}"
        ),
        Case(
            name: "Footnote-shaped line is paragraph text",
            markdown: "[^1]: The note.\n",
            expected: "p{[^1]: The note.}"
        ),
        Case(
            name: "Definition after an unclosed fence stays code",
            markdown: "```\ncode\n[a]: https://example.com\n\n[a]\n",
            expected: "code{code\n[a]: https://example.com\n\n[a]}"
        ),
        Case(
            name: "Raw destination keeps a non-ASCII space",
            markdown: "[a]: /u\u{A0}x\n\n[a]\n",
            expected: "p{[a](/u\u{A0}x)}"
        ),
    ]

    @Test(arguments: specExamples)
    func commonMarkSection4_7(_ testCase: Case) throws {
        try check(testCase)
    }

    @Test(arguments: blockContexts)
    func blockContext(_ testCase: Case) throws {
        try check(testCase)
    }

    private func check(_ testCase: Case) throws {
        let document = try SwiftMarkdownParser().parse(testCase.markdown)
        let signature = Self.signature(of: document)
        if !testCase.knownIssues.isEmpty {
            let causes = testCase.knownIssues.map(\.rawValue).joined(separator: "; ")
            withKnownIssue(Comment(rawValue: causes)) {
                #expect(signature == testCase.expected)
            }
        } else {
            #expect(signature == testCase.expected)
        }
    }

    // MARK: - Signature

    static func signature(of document: AST.DocumentNode) -> String {
        blocks(document.children)
    }

    private static func blocks(_ nodes: [any ASTNode]) -> String {
        nodes.map(block).joined(separator: " ")
    }

    private static func block(_ node: any ASTNode) -> String {
        switch node {
        case let paragraph as AST.ParagraphNode:
            return "p{\(inlines(paragraph.children))}"
        case let heading as AST.HeadingNode:
            return "h\(heading.level){\(inlines(heading.children))}"
        case let quote as AST.BlockQuoteNode:
            return "quote{\(blocks(quote.children))}"
        case let list as AST.ListNode:
            return "list{\(blocks(list.items))}"
        case let item as AST.ListItemNode:
            return "item{\(blocks(item.children))}"
        case let code as AST.CodeBlockNode:
            return "code{\(trimmingTrailingLineEndings(code.content))}"
        case let html as AST.HTMLBlockNode:
            return "html{\(html.content)}"
        case let math as AST.MathBlockNode:
            return "math{\(trimmingTrailingLineEndings(math.content))}"
        default:
            return "\(node.nodeType.rawValue){\(blocks(node.children))}"
        }
    }

    private static func inlines(_ nodes: [any ASTNode]) -> String {
        nodes.map(inline).joined()
    }

    private static func inline(_ node: any ASTNode) -> String {
        switch node {
        case let text as AST.TextNode:
            return text.content
        case is AST.SoftBreakNode, is AST.LineBreakNode:
            return "\n"
        case let code as AST.CodeSpanNode:
            return "`\(code.content)`"
        case let strikethrough as AST.StrikethroughNode:
            return "~~\(inlines(strikethrough.children))~~"
        case let link as AST.LinkNode:
            return "[\(inlines(link.children))](\(destination(link.url, link.title)))"
        case let image as AST.ImageNode:
            return "![\(image.altText)](\(destination(image.url, image.title)))"
        case let autolink as AST.AutolinkNode:
            return "<\(autolink.url)>"
        default:
            return inlines(node.children)
        }
    }

    private static func destination(_ url: String, _ title: String?) -> String {
        guard let title else { return url }
        return "\(url) \"\(title)\""
    }

    private static func trimmingTrailingLineEndings(_ content: String) -> String {
        var content = Substring(content)
        while content.last.map(MarkdownSourceText.isLineEnding) == true {
            content = content.dropLast()
        }
        return String(content)
    }
}
