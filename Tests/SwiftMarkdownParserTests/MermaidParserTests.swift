import Testing
import Foundation
@testable import SwiftMarkdownParser

/// Tests for Mermaid diagram parsing functionality
@Suite struct MermaidParserTests {

    private let parser: SwiftMarkdownParser

    init() {
        parser = SwiftMarkdownParser()
    }

    // MARK: - Basic Mermaid Parsing Tests

    @Test func parseMermaidFlowchart() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A[Christmas] -->|Get money| B(Go shopping)
            B --> C{Let me think}
            C -->|One| D[Laptop]
            C -->|Two| E[iPhone]
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        #expect(ast.children.count == 1)

        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        #expect(mermaidNode.nodeType == .mermaidDiagram)
        #expect(mermaidNode.content.contains("graph TD"))
        #expect(mermaidNode.content.contains("A[Christmas]"))
        #expect(mermaidNode.diagramType == "flowchart")
    }

    @Test func parseMermaidSequenceDiagram() async throws {
        let markdown = """
        ```mermaid
        sequenceDiagram
            participant A as Alice
            participant B as Bob
            A->>B: Hello Bob, how are you?
            B-->>A: Great!
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        #expect(ast.children.count == 1)

        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        #expect(mermaidNode.diagramType == "sequence")
        #expect(mermaidNode.content.contains("sequenceDiagram"))
        #expect(mermaidNode.content.contains("participant A as Alice"))
    }

    @Test func parseMermaidGanttChart() async throws {
        let markdown = """
        ```mermaid
        gantt
            title A Gantt Diagram
            dateFormat  YYYY-MM-DD
            section Section
            A task           :a1, 2014-01-01, 30d
            Another task     :after a1  , 20d
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        #expect(mermaidNode.diagramType == "gantt")
        #expect(mermaidNode.content.contains("gantt"))
        #expect(mermaidNode.content.contains("title A Gantt Diagram"))
    }

    // MARK: - Mixed Content Tests

    @Test func mermaidWithRegularMarkdown() async throws {
        let markdown = """
        # My Document

        This is a paragraph with **bold** text.

        ```mermaid
        graph LR
            A --> B
            B --> C
        ```

        Another paragraph after the diagram.

        ```swift
        let hello = "world"
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        #expect(ast.children.count == 5) // heading, paragraph, mermaid, paragraph, code block

        // Check heading
        let heading = try #require(ast.children[0] as? AST.HeadingNode, "Expected HeadingNode")
        #expect(heading.level == 1)

        // Check first paragraph
        #expect(ast.children[1] is AST.ParagraphNode)

        // Check Mermaid diagram
        let mermaidNode = try #require(ast.children[2] as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")
        #expect(mermaidNode.diagramType == "flowchart")

        // Check second paragraph
        #expect(ast.children[3] is AST.ParagraphNode)

        // Check regular code block
        let codeBlock = try #require(ast.children[4] as? AST.CodeBlockNode, "Expected CodeBlockNode")
        #expect(codeBlock.language == "swift")
    }

    @Test func multipleMermaidDiagrams() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A --> B
        ```

        Some text between diagrams.

        ```mermaid
        sequenceDiagram
            Alice->>Bob: Hello
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        #expect(ast.children.count == 3) // mermaid, paragraph, mermaid

        // First Mermaid diagram
        let firstMermaid = try #require(ast.children[0] as? AST.MermaidDiagramNode, "Expected first MermaidDiagramNode")
        #expect(firstMermaid.diagramType == "flowchart")

        // Paragraph
        #expect(ast.children[1] is AST.ParagraphNode)

        // Second Mermaid diagram
        let secondMermaid = try #require(ast.children[2] as? AST.MermaidDiagramNode, "Expected second MermaidDiagramNode")
        #expect(secondMermaid.diagramType == "sequence")
    }

    // MARK: - Edge Cases

    @Test func emptyMermaidBlock() async throws {
        let markdown = """
        ```mermaid
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        #expect(mermaidNode.content.isEmpty)
        #expect(mermaidNode.diagramType == nil) // Can't detect type from empty content
    }

    @Test func mermaidWithWhitespace() async throws {
        let markdown = """
        ```mermaid

        graph TD
            A --> B

        ```
        """

        let ast = try await parser.parseToAST(markdown)

        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        #expect(mermaidNode.content.contains("graph TD"))
        #expect(mermaidNode.diagramType == "flowchart")
    }

    @Test func mermaidCaseInsensitive() async throws {
        let markdown = """
        ```MERMAID
        graph LR
            A --> B
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        #expect(mermaidNode.diagramType == "flowchart")
    }

    @Test func regularCodeBlockNotMermaid() async throws {
        let markdown = """
        ```python
        print("This is not mermaid")
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        // Should be a regular code block, not a Mermaid diagram
        let codeBlock = try #require(ast.children.first as? AST.CodeBlockNode, "Expected CodeBlockNode")

        #expect(codeBlock.language == "python")
        #expect(codeBlock.content.contains("print"))
    }

    // MARK: - Diagram Type Detection Tests

    @Test func detectClassDiagram() async throws {
        let markdown = """
        ```mermaid
        classDiagram
            class Animal {
                +String name
                +makeSound()
            }
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        #expect(mermaidNode.diagramType == "class")
    }

    @Test func detectStateDiagram() async throws {
        let markdown = """
        ```mermaid
        stateDiagram
            [*] --> State1
            State1 --> [*]
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        #expect(mermaidNode.diagramType == "state")
    }

    @Test func detectPieChart() async throws {
        let markdown = """
        ```mermaid
        pie title Pets adopted by volunteers
            "Dogs" : 386
            "Cats" : 85
            "Rats" : 15
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        #expect(mermaidNode.diagramType == "pie")
    }

    @Test func unknownDiagramType() async throws {
        let markdown = """
        ```mermaid
        someUnknownDiagram
            A --> B
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        // Should still create a MermaidDiagramNode, but with unknown type
        #expect(mermaidNode.diagramType == nil)
        #expect(mermaidNode.content.contains("someUnknownDiagram"))
    }

    // MARK: - Source Location Tests

    @Test func mermaidSourceLocation() async throws {
        let markdown = """
        # Heading

        ```mermaid
        graph TD
            A --> B
        ```
        """

        let ast = try await parser.parseToAST(markdown)

        let mermaidNode = try #require(ast.children[1] as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        #expect(mermaidNode.sourceLocation != nil)
        #expect(mermaidNode.sourceLocation?.line == 3) // Third line
    }

    // MARK: - Performance Tests

    @Test func largeMermaidDiagram() async throws {
        var mermaidContent = "graph TD\n"

        // Create a large diagram with many nodes
        for i in 1...100 {
            mermaidContent += "    A\(i) --> A\(i+1)\n"
        }

        let markdown = "```mermaid\n\(mermaidContent)```"

        let startTime = Date()
        let ast = try await parser.parseToAST(markdown)
        let endTime = Date()

        // Should complete within reasonable time (< 1 second)
        #expect(endTime.timeIntervalSince(startTime) < 1.0)

        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Expected MermaidDiagramNode")

        #expect(mermaidNode.diagramType == "flowchart")
        #expect(mermaidNode.content.contains("A1 --> A2"))
        #expect(mermaidNode.content.contains("A100 --> A101"))
    }
}
