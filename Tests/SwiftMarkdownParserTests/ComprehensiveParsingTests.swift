import Foundation
import Testing
@testable import SwiftMarkdownParser

@Suite("Complex Markdown documents")
struct ComprehensiveParsingTests {
    private let parser = SwiftMarkdownParser()

    @Test("Builds one semantic tree across interacting Markdown features")
    func buildsSemanticDocument() throws {
        let document = try parser.parse(Self.releaseRunbook)

        #expect(document.children.map(\.nodeType) == [
            .heading,
            .blockQuote,
            .heading,
            .list,
            .heading,
            .table,
            .heading,
            .codeBlock,
            .mermaidDiagram,
            .mathBlock
        ])
        #expect(nodes(of: AST.FragmentNode.self, in: document).isEmpty)

        let headings = nodes(of: AST.HeadingNode.self, in: document)
        #expect(headings.map(\.level) == [1, 2, 2, 2])
        #expect(headings.map { plainText(in: $0) } == [
            "Release 2.4",
            "Checklist",
            "Components",
            "Automation"
        ])

        let code = try #require(document.children[7] as? AST.CodeBlockNode)
        #expect(code.language == "swift")
        #expect(code.content == "let payload = \"<release>&\"\ndeploy(payload)\n")

        let diagram = try #require(document.children[8] as? AST.MermaidDiagramNode)
        #expect(diagram.diagramType == "flowchart")
        #expect(diagram.content.contains("Parse --> Render"))

        let math = try #require(document.children[9] as? AST.MathBlockNode)
        #expect(math.content.contains(#"\sum_{i=1}^{n} x_i"#))
    }

    @Test("Resolves references and inline semantics inside nested containers")
    func resolvesNestedSemantics() throws {
        let document = try parser.parse(Self.releaseRunbook)

        let quote = try #require(document.children[1] as? AST.BlockQuoteNode)
        let operationsLink = try #require(nodes(of: AST.LinkNode.self, in: quote).first)
        #expect(operationsLink.url == "https://example.com/operations")
        #expect(operationsLink.title == "Operations")
        #expect(nodes(of: AST.InlineMathNode.self, in: quote).map(\.content) == ["0.05"])

        let list = try #require(document.children[3] as? AST.ListNode)
        let tasks = list.items.compactMap { $0 as? AST.GFMTaskListItemNode }
        #expect(tasks.map(\.isChecked) == [true, false, false])
        #expect(nodes(of: AST.CodeSpanNode.self, in: list).map(\.content) == ["schema.sql"])
        #expect(nodes(of: AST.StrongEmphasisNode.self, in: list).count == 1)
        #expect(nodes(of: AST.StrikethroughNode.self, in: list).count == 1)

        let table = try #require(document.children[5] as? AST.GFMTableNode)
        #expect(table.alignments == [.left, .center, .right])
        #expect(table.rows.map { $0.cells.map(\.content) } == [
            ["Component", "Owner", "State"],
            ["Parser", "Core", "ready"],
            ["Renderer", "Web", "blocked"]
        ])
        let tableLink = try #require(nodes(of: AST.LinkNode.self, in: table).first)
        #expect(tableLink.url == "https://example.com/core")
        #expect(tableLink.title == nil)
    }

    @Test("Renders a complex document with semantic HTML and only required runtimes")
    func rendersSemanticHTML() async throws {
        let document = try parser.parse(Self.releaseRunbook)

        let html = try await HTMLRenderer().renderDocument(
            document,
            metadata: HTMLDocumentMetadata(title: "Release <2.4>", language: "pt-BR")
        )

        #expect(html.contains("<html lang=\"pt-BR\">"))
        #expect(html.contains("<title>Release &lt;2.4&gt;</title>"))
        #expect(html.contains("<h1>Release 2.4</h1>"))
        #expect(html.contains("<blockquote>"))
        #expect(html.contains("href=\"https://example.com/operations\""))
        #expect(html.contains("title=\"Operations\""))

        #expect(html.occurrences(of: "type=\"checkbox\"") == 3)
        #expect(html.occurrences(of: "aria-checked=\"true\"") == 1)
        #expect(html.occurrences(of: "aria-checked=\"false\"") == 2)
        #expect(html.contains("<strong>API</strong>"))
        #expect(html.contains("<del>legacy</del>"))

        #expect(html.contains("<table>"))
        #expect(html.contains("href=\"https://example.com/core\""))
        #expect(html.contains("<code>ready</code>"))
        #expect(html.contains("<del>blocked</del>"))

        #expect(html.contains("class=\"language-swift\""))
        #expect(html.contains("&lt;release&gt;&amp;"))
        #expect(!html.contains("<release>"))
        #expect(html.contains("<pre class=\"mermaid\""))
        #expect(html.contains("<span class=\"math math-inline\">0.05</span>"))
        #expect(html.contains("<div class=\"math math-display\">"))

        #expect(html.occurrences(of: "mermaid@10.9.1/dist/mermaid.min.js") == 1)
        #expect(html.occurrences(of: "katex@0.16.21/dist/katex.min.js") == 1)
        #expect(html.contains("const requiredFeatures = [\"katex\",\"mermaid\",\"taskLists\"]"))
    }

    @Test("Rewrites nested prose while retaining typed containers and literal payloads")
    func rewritesNestedProse() throws {
        let original = try parser.parse(Self.releaseRunbook)

        let rewritten = try original.rewriting { visit in
            guard let text = visit.node as? AST.TextNode else { return .keep }

            switch text.content {
            case "approval":
                return .replace(AST.TextNode(
                    content: "authorization",
                    sourceLocation: text.sourceLocation
                ))
            case "blocked":
                return .replace(AST.TextNode(
                    content: "deferred",
                    sourceLocation: text.sourceLocation
                ))
            default:
                return .keep
            }
        }

        #expect(plainText(in: original).contains("approval"))
        #expect(plainText(in: original).contains("blocked"))
        #expect(plainText(in: rewritten).contains("authorization"))
        #expect(plainText(in: rewritten).contains("deferred"))

        let originalTable = try #require(nodes(of: AST.GFMTableNode.self, in: original).first)
        let rewrittenTable = try #require(nodes(of: AST.GFMTableNode.self, in: rewritten).first)
        #expect(rewrittenTable.rows.map { $0.cells.map(\.content) } == [
            ["Component", "Owner", "State"],
            ["Parser", "Core", "ready"],
            ["Renderer", "Web", "deferred"]
        ])
        #expect(rewrittenTable.alignments == originalTable.alignments)
        #expect(nodes(of: AST.LinkNode.self, in: rewrittenTable).map(\.url) == [
            "https://example.com/core"
        ])

        #expect(
            nodes(of: AST.CodeBlockNode.self, in: rewritten).map(\.content)
                == nodes(of: AST.CodeBlockNode.self, in: original).map(\.content)
        )
        #expect(
            nodes(of: AST.MermaidDiagramNode.self, in: rewritten).map(\.content)
                == nodes(of: AST.MermaidDiagramNode.self, in: original).map(\.content)
        )
        #expect(
            nodes(of: AST.MathBlockNode.self, in: rewritten).map(\.content)
                == nodes(of: AST.MathBlockNode.self, in: original).map(\.content)
        )
    }

    @Test("Recovers after malformed inline syntax without swallowing later blocks")
    func recoversAfterMalformedInlineSyntax() throws {
        let markdown = """
        # Valid start

        Broken **strong and [link](destination

        ## Recovery

        - [x] parsed after malformed inline

        ```swift
        let answer = 42
        ```
        """

        let document = try parser.parse(markdown)

        let headings = nodes(of: AST.HeadingNode.self, in: document)
        #expect(headings.map(\.level) == [1, 2])
        #expect(headings.map { plainText(in: $0) } == ["Valid start", "Recovery"])

        let malformedParagraph = try #require(
            nodes(of: AST.ParagraphNode.self, in: document).first
        )
        #expect(plainText(in: malformedParagraph) == "Broken **strong and [link](destination")
        #expect(nodes(of: AST.StrongEmphasisNode.self, in: malformedParagraph).isEmpty)
        #expect(nodes(of: AST.LinkNode.self, in: malformedParagraph).isEmpty)

        let task = try #require(nodes(of: AST.GFMTaskListItemNode.self, in: document).first)
        #expect(task.isChecked)
        #expect(plainText(in: task).contains("parsed after malformed inline"))

        let code = try #require(nodes(of: AST.CodeBlockNode.self, in: document).first)
        #expect(code.language == "swift")
        #expect(code.content == "let answer = 42\n")
    }

    private func nodes<Node: ASTNode>(of type: Node.Type, in root: any ASTNode) -> [Node] {
        root.depthFirst().compactMap { $0.node as? Node }
    }

    private func plainText(in root: any ASTNode) -> String {
        root.depthFirst().compactMap { visit in
            switch visit.node {
            case let text as AST.TextNode:
                return text.content
            case let code as AST.CodeSpanNode:
                return code.content
            default:
                return nil
            }
        }.joined()
    }

    private static let releaseRunbook = #"""
    # Release 2.4

    > Deploy only after **approval** from [operations][ops].
    >
    > Rollback if error rate exceeds $0.05$.

    ## Checklist

    - [x] Apply `schema.sql`
    - [ ] Roll out **API**
    - [ ] Verify ~~legacy~~ dashboards

    ## Components

    | Component | Owner | State |
    |:----------|:-----:|------:|
    | Parser | [Core][core] | `ready` |
    | Renderer | **Web** | ~~blocked~~ |

    ## Automation

    ```swift
    let payload = "<release>&"
    deploy(payload)
    ```

    ```mermaid
    flowchart LR
      Parse --> Render
    ```

    $$
    S = \sum_{i=1}^{n} x_i
    $$

    [ops]: https://example.com/operations "Operations"
    [core]: https://example.com/core
    """#
}

private extension String {
    func occurrences(of value: String) -> Int {
        components(separatedBy: value).count - 1
    }
}
