import Testing
@testable import SwiftMarkdownParser

/// Paragraph continuation at the Source → Document seam: the examples of
/// CommonMark 0.30 section 4.8, inline constructs that cross a line inside a
/// paragraph, lazy continuation lines, and the blocks that interrupt a
/// paragraph.
///
/// Cases use the signature notation of `LinkReferenceDefinitionTests`.
/// Example numbers follow the official CommonMark 0.30 numbering.
@Suite struct ParagraphContinuationTests {
    typealias Case = LinkReferenceDefinitionTests.Case

    static let specExamples: [Case] = [
        Case(name: "Example 219", markdown: "aaa\n\nbbb\n", expected: "p{aaa} p{bbb}"),
        Case(
            name: "Example 220",
            markdown: "aaa\nbbb\n\nccc\nddd\n",
            expected: "p{aaa\nbbb} p{ccc\nddd}"
        ),
        Case(name: "Example 221", markdown: "aaa\n\n\nbbb\n", expected: "p{aaa} p{bbb}"),
        Case(
            name: "Example 222",
            markdown: "  aaa\n bbb\n",
            expected: "p{aaa\nbbb}"
        ),
        Case(
            name: "Example 223",
            markdown: "aaa\n             bbb\n                                       ccc\n",
            expected: "p{aaa\nbbb\nccc}"
        ),
        Case(
            name: "Example 224",
            markdown: "   aaa\nbbb\n",
            expected: "p{aaa\nbbb}"
        ),
        Case(name: "Example 225", markdown: "    aaa\nbbb\n", expected: "code{aaa} p{bbb}"),
        Case(
            name: "Example 226",
            markdown: "aaa     \nbbb     \n",
            expected: "p{aaa\nbbb}"
        ),
    ]

    /// Inline constructs that cross a line inside one paragraph.
    static let crossLineInlines: [Case] = [
        Case(
            name: "Code span across a line",
            markdown: "`foo\nbar`\n",
            expected: "p{`foo bar`}"
        ),
        Case(
            name: "Code span across a line inside text",
            markdown: "para `foo\nbar` end\n",
            expected: "p{para `foo bar` end}"
        ),
        Case(
            name: "Strikethrough across a line",
            markdown: "~~foo\nbar~~\n",
            expected: "p{~~foo\nbar~~}"
        ),
        Case(
            name: "Code span across a line inside a list item",
            markdown: "- `foo\n  bar`\n",
            expected: "list{item{p{`foo bar`}}}"
        ),
        Case(
            name: "Example 335",
            markdown: "``\nfoo\nbar  \nbaz\n``\n",
            expected: "p{`foo bar   baz`}"
        ),
        Case(
            name: "Example 336",
            markdown: "``\nfoo \n``\n",
            expected: "p{`foo `}"
        ),
        Case(
            name: "Example 337",
            markdown: "`foo   bar \nbaz`\n",
            expected: "p{`foo   bar  baz`}"
        ),
        Case(
            name: "Example 640",
            markdown: "`code  \nspan`\n",
            expected: "p{`code   span`}"
        ),
        Case(
            name: "Example 42",
            markdown: "- `one\n- two`\n",
            expected: "list{item{p{`one}} item{p{two`}}}"
        ),
    ]

    /// Lazy continuation lines and the lines that end a paragraph.
    static let continuation: [Case] = [
        Case(
            name: "Lazy line continues a block quote paragraph",
            markdown: "> aaa\nbbb\n",
            expected: "quote{p{aaa\nbbb}}"
        ),
        Case(
            name: "Marked line continues a block quote paragraph",
            markdown: "> aaa\n> bbb\n",
            expected: "quote{p{aaa\nbbb}}"
        ),
        Case(
            name: "Lazy line continues a nested block quote paragraph",
            markdown: "> > aaa\n> bbb\nccc\n",
            expected: "quote{quote{p{aaa\nbbb\nccc}}}"
        ),
        Case(
            name: "Lazy line continues a list item paragraph",
            markdown: "- aaa\nbbb\n",
            expected: "list{item{p{aaa\nbbb}}}"
        ),
        Case(
            name: "Indented line continues a list item paragraph",
            markdown: "1. aaa\n   bbb\n2. ccc\n",
            expected: "list{item{p{aaa\nbbb}} item{p{ccc}}}"
        ),
        Case(
            name: "Indented code cannot interrupt a paragraph",
            markdown: "aaa\n    bbb\n",
            expected: "p{aaa\nbbb}"
        ),
        Case(
            name: "An ordered list not starting at 1 cannot interrupt a paragraph",
            markdown: "aaa\n2. bbb\n",
            expected: "p{aaa\n2. bbb}"
        ),
        Case(name: "ATX heading interrupts", markdown: "aaa\n# bbb\n", expected: "p{aaa} h1{bbb}"),
        Case(
            name: "ATX heading with an open code span ends at its line",
            markdown: "# `foo\nbar`\n",
            expected: "h1{`foo} p{bar`}"
        ),
        Case(name: "Thematic break interrupts", markdown: "aaa\n***\n", expected: "p{aaa} thematicBreak{}"),
        Case(name: "Block quote interrupts", markdown: "aaa\n> bbb\n", expected: "p{aaa} quote{p{bbb}}"),
        Case(name: "Bullet list interrupts", markdown: "aaa\n- bbb\n", expected: "p{aaa} list{item{p{bbb}}}"),
        Case(name: "Fence interrupts", markdown: "aaa\n```\nbbb\n```\n", expected: "p{aaa} code{bbb}"),
        Case(
            name: "Setext heading spans lines",
            markdown: "aaa\nbbb\n===\n",
            expected: "h1{aaa\nbbb}"
        ),
        Case(
            name: "Setext underline after a lazy block quote line is a break",
            markdown: "> aaa\n---\n",
            expected: "quote{p{aaa}} thematicBreak{}"
        ),
    ]

    /// The rest of a list item's marker line starts the item's first block.
    static let listItemFirstLine: [Case] = [
        Case(name: "Example 61", markdown: "- Foo\n- * * *\n", expected: "list{item{p{Foo}} item{thematicBreak{}}}"),
        Case(name: "Example 11", markdown: "*\t*\t*\t\n", expected: "thematicBreak{}"),
        Case(name: "Example 175", markdown: "- <div>\n- foo\n", expected: "list{item{html{<div>}} item{p{foo}}}"),
        Case(name: "Example 280", markdown: "-\n\n  foo\n", expected: "list{item{}} p{foo}"),
        Case(name: "Heading in a list item", markdown: "- # foo\nbar\n", expected: "list{item{h1{foo}}} p{bar}"),
        Case(name: "Example 646", markdown: "### foo\\\n", expected: "h3{foo\\}"),
    ]

    /// Continuation lines of a container block: a fence ends with the
    /// container that holds it, container markers never become code, and a
    /// thematic break on a list item's continuation line belongs to the item.
    static let containerContinuation: [Case] = [
        Case(
            name: "Unclosed fence in a list item ends before an unindented paragraph",
            markdown: "- ```\n  code\npara\n",
            expected: "list{item{code{code}}} p{para}"
        ),
        Case(
            name: "Unclosed fence in a list item ends before the next item",
            markdown: "- ~~~\n  code\n- next\n",
            expected: "list{item{code{code}} item{p{next}}}"
        ),
        Case(
            name: "Unclosed fence in a list item keeps a blank line and ends before the next item",
            markdown: "- ~~~\n  a\n\n- b\n",
            expected: "list{item{code{a}} item{p{b}}}"
        ),
        Case(
            name: "Fence in a list inside a block quote closes inside the quote",
            markdown: "> - ```\n>   x\n>   ```\n> - y\n",
            expected: "quote{list{item{code{x}} item{p{y}}}}"
        ),
        Case(
            name: "Unclosed fence in a block quote ends before a line without a marker",
            markdown: "> ```\n> a\nb\n",
            expected: "quote{code{a}} p{b}"
        ),
        Case(
            name: "Thematic break on a continuation line of a list item",
            markdown: "* a\n  * * *\n",
            expected: "list{item{p{a} thematicBreak{}}}"
        ),
        Case(
            name: "Thematic break of dashes on a continuation line of a list item",
            markdown: "- a\n  - - -\n",
            expected: "list{item{p{a} thematicBreak{}}}"
        ),
        Case(
            name: "Thematic break of list marker characters after a list item ends the list",
            markdown: "* a\n* * *\n",
            expected: "list{item{p{a}}} thematicBreak{}"
        ),
    ]

    @Test(arguments: specExamples)
    func commonMarkSection4_8(_ testCase: Case) throws {
        try check(testCase)
    }

    @Test(arguments: crossLineInlines)
    func inlineAcrossLines(_ testCase: Case) throws {
        try check(testCase)
    }

    @Test(arguments: continuation)
    func continuationLines(_ testCase: Case) throws {
        try check(testCase)
    }

    @Test(arguments: listItemFirstLine)
    func firstLineOfListItem(_ testCase: Case) throws {
        try check(testCase)
    }

    @Test(arguments: containerContinuation)
    func continuationOfContainer(_ testCase: Case) throws {
        try check(testCase)
    }

    @Test func lineEnding_insideParagraph_isSoftBreak() throws {
        let paragraph = try #require(
            try SwiftMarkdownParser().parse("aaa\nbbb\n").children.first as? AST.ParagraphNode
        )
        let shape = paragraph.children.map { $0.nodeType.rawValue }
        #expect(shape == ["text", "lineBreak", "text"])
        #expect(paragraph.children.dropFirst().first is AST.SoftBreakNode)
    }

    @Test(arguments: ["aaa  \nbbb\n", "aaa\\\nbbb\n"])
    func trailingSpacesOrBackslash_beforeLineEnding_isHardBreak(_ markdown: String) throws {
        let paragraph = try #require(
            try SwiftMarkdownParser().parse(markdown).children.first as? AST.ParagraphNode
        )
        let texts = paragraph.children.compactMap { ($0 as? AST.TextNode)?.content }
        #expect(texts == ["aaa", "bbb"])
        #expect((paragraph.children.dropFirst().first as? AST.LineBreakNode)?.isHard == true)
    }

    /// CommonMark 0.30 example 318: a fence opened on the first line of a list
    /// item keeps the following items.
    @Test func example318_fenceOnListItemFirstLine_keepsFollowingItems() throws {
        let document = try SwiftMarkdownParser().parse("- a\n- ```\n  b\n\n\n  ```\n- c\n")
        #expect(LinkReferenceDefinitionTests.signature(of: document) == "list{item{p{a}} item{code{b}} item{p{c}}}")
        let list = document.children.first as? AST.ListNode
        let code = list?.items.dropFirst().first?.children.first as? AST.CodeBlockNode
        #expect(code?.content == "b\n\n\n")
    }

    /// CommonMark 0.30 example 324: a fence opened on the first line of an
    /// ordered item, then a paragraph of the same item.
    @Test func example324_fenceOnOrderedItemFirstLine_keepsItemParagraph() throws {
        let document = try SwiftMarkdownParser().parse("1. ```\n   foo\n   ```\n\n   bar\n")
        #expect(LinkReferenceDefinitionTests.signature(of: document) == "list{item{code{foo} p{bar}}}")
        let list = document.children.first as? AST.ListNode
        let code = list?.items.first?.children.first as? AST.CodeBlockNode
        #expect(code?.content == "foo\n")
    }

    private func check(_ testCase: Case) throws {
        let document = try SwiftMarkdownParser().parse(testCase.markdown)
        let signature = LinkReferenceDefinitionTests.signature(of: document)
        if !testCase.knownIssues.isEmpty {
            let causes = testCase.knownIssues.map(\.rawValue).joined(separator: "; ")
            withKnownIssue(Comment(rawValue: causes)) {
                #expect(signature == testCase.expected)
            }
        } else {
            #expect(signature == testCase.expected)
        }
    }
}
