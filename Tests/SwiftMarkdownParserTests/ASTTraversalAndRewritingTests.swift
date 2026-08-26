import Testing
@testable import SwiftMarkdownParser

@Suite struct ASTTraversalAndRewritingTests {
    @Test func depthFirstTraversalIncludesRootAndStableContext() throws {
        let document = try SwiftMarkdownParser().parse("# Title\n\nBody **strong**")
        let visits = Array(document.depthFirst())

        #expect(visits.map(\.node.nodeType) == [
            .document,
            .heading,
            .text,
            .paragraph,
            .text,
            .text,
            .strongEmphasis,
            .text,
        ])

        let strongText = try #require(visits.last)
        #expect(strongText.path == [1, 2, 0])
        #expect(strongText.depth == 3)
        #expect(strongText.parent?.nodeType == .strongEmphasis)
        #expect(strongText.ancestors.map(\.nodeType) == [.document, .paragraph, .strongEmphasis])
    }

    @Test func traversalSupportsLazyTypedQueries() throws {
        let document = try SwiftMarkdownParser().parse("[one](https://one.example) and [two](https://two.example)")

        let firstLink = document.depthFirst().lazy.compactMap { $0.node as? AST.LinkNode }.first

        #expect(firstLink?.url == "https://one.example")
    }

    @Test func rewritingIsBottomUpAndDoesNotRevisitReplacements() throws {
        let document = try SwiftMarkdownParser().parse("**old**")
        var visitedText: [String] = []

        let rewritten = try document.rewriting { visit in
            if let text = visit.node as? AST.TextNode {
                visitedText.append(text.content)
                if text.content == "old" {
                    return .replace(AST.TextNode(content: "new", sourceLocation: text.sourceLocation))
                }
            }

            if let strong = visit.node as? AST.StrongEmphasisNode {
                let child = strong.children.first as? AST.TextNode
                #expect(child?.content == "new")
            }
            return .keep
        }

        let text = rewritten.depthFirst().compactMap { $0.node as? AST.TextNode }.first
        #expect(text?.content == "new")
        #expect(visitedText == ["old"])
    }

    @Test func rewritingCanRemoveAndExpandSiblingsInDocumentOrder() throws {
        let document = try SwiftMarkdownParser().parse("First\n\nRemove\n\nLast")

        let rewritten = try document.rewriting { visit in
            guard let paragraph = visit.node as? AST.ParagraphNode,
                  let text = paragraph.children.first as? AST.TextNode else {
                return .keep
            }

            switch text.content {
            case "First":
                return .replaceMany([
                    AST.ParagraphNode(children: [AST.TextNode(content: "One")]),
                    AST.ParagraphNode(children: [AST.TextNode(content: "Two")]),
                ])
            case "Remove":
                return .remove
            default:
                return .keep
            }
        }

        let paragraphs = rewritten.children.compactMap { $0 as? AST.ParagraphNode }
        let values = paragraphs.compactMap { ($0.children.first as? AST.TextNode)?.content }
        #expect(values == ["One", "Two", "Last"])
    }

    @Test func rebuildingBuiltInNodesPreservesMetadataAndRanges() throws {
        let document = try SwiftMarkdownParser().parse("## Before")
        let original = try #require(document.children.first as? AST.HeadingNode)

        let rewritten = try document.rewriting { visit in
            guard let text = visit.node as? AST.TextNode else { return .keep }
            return .replace(AST.TextNode(content: "After", sourceLocation: text.sourceLocation))
        }

        let heading = try #require(rewritten.children.first as? AST.HeadingNode)
        #expect(heading.level == 2)
        #expect(heading.sourceLocation == original.sourceLocation)
        #expect((heading.children.first as? AST.TextNode)?.content == "After")
        #expect((original.children.first as? AST.TextNode)?.content == "Before")
    }

    @Test func rewritingRebuildsParsedContainersThroughOneInterface() throws {
        let source = """
        > Quote with *emphasis* and [link](https://example.com)

        - [x] **strong** and ~~strike~~

        | Header |
        |--------|
        | value  |
        """
        let document = try SwiftMarkdownParser().parse(source)

        let rewritten = try document.rewriting { visit in
            guard let text = visit.node as? AST.TextNode else { return .keep }
            return .replace(AST.TextNode(
                content: text.content.uppercased(),
                sourceLocation: text.sourceLocation
            ))
        }

        let originalText = document.depthFirst().compactMap { ($0.node as? AST.TextNode)?.content }.joined()
        let rewrittenText = rewritten.depthFirst().compactMap { ($0.node as? AST.TextNode)?.content }.joined()
        #expect(originalText.contains("emphasis"))
        #expect(rewrittenText.contains("EMPHASIS"))
        #expect(rewrittenText.contains("STRONG"))
        #expect(rewrittenText.contains("STRIKE"))
        #expect(rewrittenText.contains("VALUE"))
    }

    @Test func rewritingRejectsInvalidTypedTableChildren() throws {
        let document = try SwiftMarkdownParser().parse("| A |\n|---|\n| B |")

        #expect(throws: ASTRewriteError.invalidChildType(
            parent: .tableRow,
            expected: .tableCell,
            actual: .text
        )) {
            try document.rewriting { visit in
                guard visit.node is AST.GFMTableCellNode else { return .keep }
                return .replace(AST.TextNode(content: "not a cell"))
            }
        }
    }

    @Test func customContainersOptIntoDescendantRewriting() throws {
        let root = AST.DocumentNode(children: [
            RewritableTestContainer(children: [AST.TextNode(content: "before")]),
        ])

        let rewritten = try root.rewriting { visit in
            guard let text = visit.node as? AST.TextNode else { return .keep }
            return .replace(AST.TextNode(content: "after", sourceLocation: text.sourceLocation))
        }

        let text = rewritten.depthFirst().compactMap { $0.node as? AST.TextNode }.first
        #expect(text?.content == "after")
    }

    @Test func nonRewritableCustomContainersFailOnlyWhenDescendantsChange() throws {
        let root = AST.DocumentNode(children: [
            ReadOnlyTestContainer(children: [AST.TextNode(content: "before")]),
        ])

        let unchanged = try root.rewriting { _ in .keep }
        #expect(unchanged.children.first is ReadOnlyTestContainer)

        #expect(throws: ASTRewriteError.nonRewritableContainer(
            ASTNodeType(rawValue: "readOnlyTestContainer")
        )) {
            try root.rewriting { visit in
                guard visit.node is AST.TextNode else { return .keep }
                return .remove
            }
        }
    }

    @Test func documentRootMustRemainExactlyOneDocument() {
        let document = AST.DocumentNode(children: [])

        #expect(throws: ASTRewriteError.invalidDocumentRoot(actual: [])) {
            try document.rewriting { visit in
                visit.node is AST.DocumentNode ? .remove : .keep
            }
        }
        #expect(throws: ASTRewriteError.invalidDocumentRoot(actual: [.document, .document])) {
            try document.rewriting { visit in
                visit.node is AST.DocumentNode
                    ? .replaceMany([AST.DocumentNode(children: []), AST.DocumentNode(children: [])])
                    : .keep
            }
        }
    }

    @Test func rewritingPropagatesRuleErrors() {
        let document = AST.DocumentNode(children: [])

        #expect(throws: TestRewriteRuleError.stop) {
            try document.rewriting { _ in throw TestRewriteRuleError.stop }
        }
    }

    @Test func rewrittenDocumentRendersThroughExistingRenderer() async throws {
        let document = try SwiftMarkdownParser().parse("Visit [old](https://old.example)")
        let rewritten = try document.rewriting { visit in
            guard let link = visit.node as? AST.LinkNode else { return .keep }
            return .replace(AST.LinkNode(
                url: "https://new.example",
                title: link.title,
                children: link.children,
                sourceLocation: link.sourceLocation
            ))
        }

        let html = try await HTMLRenderer().renderFragment(rewritten)
        #expect(html.contains("href=\"https://new.example\""))
        #expect(!html.contains("https://old.example"))
    }

    @Test func immutableDocumentCanBeRewrittenConcurrently() async throws {
        let document = try SwiftMarkdownParser().parse("# Shared")

        try await withThrowingTaskGroup(of: String.self) { group in
            for index in 0..<16 {
                group.addTask {
                    let rewritten = try document.rewriting { visit in
                        guard visit.node is AST.TextNode else { return .keep }
                        return .replace(AST.TextNode(content: "Value \(index)"))
                    }
                    return rewritten.depthFirst()
                        .compactMap { ($0.node as? AST.TextNode)?.content }
                        .first ?? ""
                }
            }

            var values: Set<String> = []
            for try await value in group {
                values.insert(value)
            }
            #expect(values.count == 16)
        }
    }
}

private enum TestRewriteRuleError: Error, Equatable {
    case stop
}
