import XCTest
@testable import SwiftMarkdownParser

/// Tests for Mermaid diagram parsing functionality
final class MermaidParserTests: XCTestCase {
    
    private var parser: SwiftMarkdownParser!
    
    override func setUp() {
        super.setUp()
        parser = SwiftMarkdownParser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - Basic Mermaid Parsing Tests
    
    func testParseMermaidFlowchart() async throws {
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
        
        XCTAssertEqual(ast.children.count, 1)
        
        guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        XCTAssertEqual(mermaidNode.nodeType, .mermaidDiagram)
        XCTAssertTrue(mermaidNode.content.contains("graph TD"))
        XCTAssertTrue(mermaidNode.content.contains("A[Christmas]"))
        XCTAssertEqual(mermaidNode.diagramType, "flowchart")
    }
    
    func testParseMermaidSequenceDiagram() async throws {
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
        
        XCTAssertEqual(ast.children.count, 1)
        
        guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        XCTAssertEqual(mermaidNode.diagramType, "sequence")
        XCTAssertTrue(mermaidNode.content.contains("sequenceDiagram"))
        XCTAssertTrue(mermaidNode.content.contains("participant A as Alice"))
    }
    
    func testParseMermaidGanttChart() async throws {
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
        
        guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        XCTAssertEqual(mermaidNode.diagramType, "gantt")
        XCTAssertTrue(mermaidNode.content.contains("gantt"))
        XCTAssertTrue(mermaidNode.content.contains("title A Gantt Diagram"))
    }
    
    // MARK: - Mixed Content Tests
    
    func testMermaidWithRegularMarkdown() async throws {
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
        
        XCTAssertEqual(ast.children.count, 5) // heading, paragraph, mermaid, paragraph, code block
        
        // Check heading
        guard let heading = ast.children[0] as? AST.HeadingNode else {
            XCTFail("Expected HeadingNode")
            return
        }
        XCTAssertEqual(heading.level, 1)
        
        // Check first paragraph
        XCTAssertTrue(ast.children[1] is AST.ParagraphNode)
        
        // Check Mermaid diagram
        guard let mermaidNode = ast.children[2] as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        XCTAssertEqual(mermaidNode.diagramType, "flowchart")
        
        // Check second paragraph
        XCTAssertTrue(ast.children[3] is AST.ParagraphNode)
        
        // Check regular code block
        guard let codeBlock = ast.children[4] as? AST.CodeBlockNode else {
            XCTFail("Expected CodeBlockNode")
            return
        }
        XCTAssertEqual(codeBlock.language, "swift")
    }
    
    func testMultipleMermaidDiagrams() async throws {
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
        
        XCTAssertEqual(ast.children.count, 3) // mermaid, paragraph, mermaid
        
        // First Mermaid diagram
        guard let firstMermaid = ast.children[0] as? AST.MermaidDiagramNode else {
            XCTFail("Expected first MermaidDiagramNode")
            return
        }
        XCTAssertEqual(firstMermaid.diagramType, "flowchart")
        
        // Paragraph
        XCTAssertTrue(ast.children[1] is AST.ParagraphNode)
        
        // Second Mermaid diagram
        guard let secondMermaid = ast.children[2] as? AST.MermaidDiagramNode else {
            XCTFail("Expected second MermaidDiagramNode")
            return
        }
        XCTAssertEqual(secondMermaid.diagramType, "sequence")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyMermaidBlock() async throws {
        let markdown = """
        ```mermaid
        ```
        """
        
        let ast = try await parser.parseToAST(markdown)
        
        guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        XCTAssertTrue(mermaidNode.content.isEmpty)
        XCTAssertNil(mermaidNode.diagramType) // Can't detect type from empty content
    }
    
    func testMermaidWithWhitespace() async throws {
        let markdown = """
        ```mermaid
        
        graph TD
            A --> B
        
        ```
        """
        
        let ast = try await parser.parseToAST(markdown)
        
        guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        XCTAssertTrue(mermaidNode.content.contains("graph TD"))
        XCTAssertEqual(mermaidNode.diagramType, "flowchart")
    }
    
    func testMermaidCaseInsensitive() async throws {
        let markdown = """
        ```MERMAID
        graph LR
            A --> B
        ```
        """
        
        let ast = try await parser.parseToAST(markdown)
        
        guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        XCTAssertEqual(mermaidNode.diagramType, "flowchart")
    }
    
    func testRegularCodeBlockNotMermaid() async throws {
        let markdown = """
        ```python
        print("This is not mermaid")
        ```
        """
        
        let ast = try await parser.parseToAST(markdown)
        
        // Should be a regular code block, not a Mermaid diagram
        guard let codeBlock = ast.children.first as? AST.CodeBlockNode else {
            XCTFail("Expected CodeBlockNode")
            return
        }
        
        XCTAssertEqual(codeBlock.language, "python")
        XCTAssertTrue(codeBlock.content.contains("print"))
    }
    
    // MARK: - Diagram Type Detection Tests
    
    func testDetectClassDiagram() async throws {
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
        
        guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        XCTAssertEqual(mermaidNode.diagramType, "class")
    }
    
    func testDetectStateDiagram() async throws {
        let markdown = """
        ```mermaid
        stateDiagram
            [*] --> State1
            State1 --> [*]
        ```
        """
        
        let ast = try await parser.parseToAST(markdown)
        
        guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        XCTAssertEqual(mermaidNode.diagramType, "state")
    }
    
    func testDetectPieChart() async throws {
        let markdown = """
        ```mermaid
        pie title Pets adopted by volunteers
            "Dogs" : 386
            "Cats" : 85
            "Rats" : 15
        ```
        """
        
        let ast = try await parser.parseToAST(markdown)
        
        guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        XCTAssertEqual(mermaidNode.diagramType, "pie")
    }
    
    func testUnknownDiagramType() async throws {
        let markdown = """
        ```mermaid
        someUnknownDiagram
            A --> B
        ```
        """
        
        let ast = try await parser.parseToAST(markdown)
        
        guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        // Should still create a MermaidDiagramNode, but with unknown type
        XCTAssertNil(mermaidNode.diagramType)
        XCTAssertTrue(mermaidNode.content.contains("someUnknownDiagram"))
    }
    
    // MARK: - Source Location Tests
    
    func testMermaidSourceLocation() async throws {
        let markdown = """
        # Heading
        
        ```mermaid
        graph TD
            A --> B
        ```
        """
        
        let ast = try await parser.parseToAST(markdown)
        
        guard let mermaidNode = ast.children[1] as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        XCTAssertNotNil(mermaidNode.sourceLocation)
        XCTAssertEqual(mermaidNode.sourceLocation?.line, 3) // Third line
    }
    
    // MARK: - Performance Tests
    
    func testLargeMermaidDiagram() async throws {
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
        XCTAssertLessThan(endTime.timeIntervalSince(startTime), 1.0)
        
        guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
            XCTFail("Expected MermaidDiagramNode")
            return
        }
        
        XCTAssertEqual(mermaidNode.diagramType, "flowchart")
        XCTAssertTrue(mermaidNode.content.contains("A1 --> A2"))
        XCTAssertTrue(mermaidNode.content.contains("A100 --> A101"))
    }
}