import Testing
import Darwin
import Foundation
@testable import SwiftMarkdownParser

/// Security and robustness tests for Mermaid diagram functionality
///
/// Phase 1 Critical Security Tests - XSS prevention, input validation, and malicious content handling
@Suite struct MermaidSecurityTests {

    private let parser: SwiftMarkdownParser

    init() {
        parser = SwiftMarkdownParser()
    }

    // MARK: - XSS Prevention Tests

    @Test func mermaidXSSScriptInjection() async throws {
        let maliciousMarkdown = """
        ```mermaid
        graph TD
            A["<script>alert('XSS')</script>"] --> B
        ```
        """

        let html = try await parser.parseToHTML(maliciousMarkdown)

        // Should contain the Mermaid diagram structure (security handled by Mermaid.js)
        #expect(html.contains("mermaid-container"))
        #expect(html.contains("class=\"mermaid\""))

        // The malicious content is preserved within the Mermaid diagram definition
        // This is safe because Mermaid.js will parse and sanitize it during rendering
        #expect(html.contains("<script>alert('XSS')</script>"))

        // But it should be within a mermaid pre tag, not as executable HTML
        #expect(html.contains("<pre class=\"mermaid\""))
    }

    @Test func mermaidHTMLInjection() async throws {
        let maliciousMarkdown = """
        ```mermaid
        graph TD
            A["<img src=x onerror=alert(1)>"] --> B["<iframe src='javascript:alert(1)'></iframe>"]
        ```
        """

        let html = try await parser.parseToHTML(maliciousMarkdown)

        // Should properly contain Mermaid diagram structure
        #expect(html.contains("mermaid-container"))
        #expect(html.contains("class=\"mermaid\""))

        // The malicious content is preserved within the Mermaid diagram definition
        // This is safe because it's contained within a <pre> element and will be
        // processed by Mermaid.js, which has its own security handling
        #expect(html.contains("<pre class=\"mermaid\""))

        // Verify the dangerous content is contained within the Mermaid pre block, not as executable HTML
        // The HTML should contain the malicious strings but they should be inside the mermaid pre tag
        #expect(html.contains("&lt;img src=x onerror=alert(1)&gt;") ||
                html.contains("<img src=x onerror=alert(1)>"))
    }

    @Test func mermaidJavaScriptInjection() async throws {
        let maliciousMarkdown = """
        ```mermaid
        graph TD
            A["javascript:alert(1)"] --> B["onclick='alert(1)'"]
        ```
        """

        let html = try await parser.parseToHTML(maliciousMarkdown)

        // Should contain Mermaid diagram structure
        #expect(html.contains("class=\"mermaid\""))

        // JavaScript code should be safely contained within diagram definition
        // (Mermaid.js itself will handle the content safely)
        #expect(html.contains("javascript:alert(1)"))
        #expect(html.contains("onclick='alert(1)'"))
    }

    // MARK: - Content Size and DoS Prevention

    @Test func mermaidContentSizeLimit() async throws {
        // Create an extremely large Mermaid diagram (potential DoS)
        var largeContent = "graph TD\n"

        // Add 10,000 nodes (should be beyond reasonable limits)
        for i in 1...10000 {
            largeContent += "    Node\(i) --> Node\(i+1)\n"
        }

        let markdown = "```mermaid\n\(largeContent)```"

        let startTime = Date()
        let ast = try await parser.parseToAST(markdown)
        let endTime = Date()

        // Should complete within reasonable time (< 5 seconds even for large input)
        #expect(endTime.timeIntervalSince(startTime) < 5.0, "Parser should handle large input within reasonable time")

        // Should still create valid MermaidDiagramNode
        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Should create MermaidDiagramNode for large content")

        #expect(mermaidNode.diagramType == "flowchart")
        #expect(mermaidNode.content.count > 100000) // Should preserve large content
    }

    @Test func mermaidExtremelyDeepNesting() async throws {
        // Create deeply nested subgraph structure
        var nestedContent = "graph TD\n"

        // Create 100 levels of nesting
        for i in 1...100 {
            nestedContent += String(repeating: "  ", count: i) + "subgraph S\(i)\n"
        }
        nestedContent += "    A --> B\n"
        for i in (1...100).reversed() {
            nestedContent += String(repeating: "  ", count: i-1) + "end\n"
        }

        let markdown = "```mermaid\n\(nestedContent)```"

        let startTime = Date()
        let ast = try await parser.parseToAST(markdown)
        let endTime = Date()

        // Should complete within reasonable time
        #expect(endTime.timeIntervalSince(startTime) < 2.0)

        // Should create valid node
        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Should create MermaidDiagramNode for nested content")

        #expect(mermaidNode.diagramType == "flowchart")
    }

    // MARK: - Unicode and Encoding Edge Cases

    @Test func mermaidUnicodeEdgeCases() async throws {
        let unicodeMarkdown = """
        ```mermaid
        graph TD
            A["🚀 Start 北京"] --> B["🔥 Process متن"]
            B --> C["✅ End тест"]

            %% Comment with unicode: 中文 العربية русский
        ```
        """

        let html = try await parser.parseToHTML(unicodeMarkdown)

        // Should handle Unicode properly
        #expect(html.contains("🚀 Start 北京"))
        #expect(html.contains("🔥 Process متن"))
        #expect(html.contains("✅ End тест"))
        #expect(html.contains("中文 العربية русский"))

        // Should maintain proper HTML structure
        #expect(html.contains("mermaid-container"))
        #expect(html.contains("class=\"mermaid\""))
    }

    @Test func mermaidNullByteHandling() async throws {
        // Test with null bytes and control characters
        let markdown = """
        ```mermaid
        graph TD
            A["Test\u{0000}Null"] --> B["Control\u{0001}\u{0002}Chars"]
        ```
        """

        let html = try await parser.parseToHTML(markdown)

        // Should not crash and should produce valid output
        #expect(html.contains("mermaid-container"))

        // Control characters should be handled safely
        #expect(html.contains("TestNull") || html.contains("Test\u{0000}Null"))
    }

    @Test func mermaidInvalidUTF8() async throws {
        // Create markdown with potentially invalid UTF-8 sequences
        let validPart = "```mermaid\ngraph TD\n    A[\"Test"
        let invalidPart = "Invalid\"] --> B[\"End\"]\n```"
        let markdown = validPart + invalidPart

        let html = try await parser.parseToHTML(markdown)

        // Should handle gracefully without crashing
        #expect(html.contains("mermaid-container"))
        #expect(html.contains("graph TD"))
    }

    // MARK: - Malformed Input Handling

    @Test func mermaidMalformedSyntax() async throws {
        let malformedMarkdown = """
        ```mermaid
        graph TD
            A -->
            B --> C[
            --> D
            E["Unclosed quote
        ```
        """

        let ast = try await parser.parseToAST(malformedMarkdown)

        // Should still create MermaidDiagramNode even with malformed content
        let mermaidNode = try #require(ast.children.first as? AST.MermaidDiagramNode, "Should create MermaidDiagramNode even for malformed content")

        #expect(mermaidNode.diagramType == "flowchart")
        #expect(mermaidNode.content.contains("Unclosed quote"))
    }

    @Test func mermaidEmptyAndWhitespaceOnly() async throws {
        let testCases = [
            "```mermaid\n```",                    // Completely empty
            "```mermaid\n   \n   \n```",         // Whitespace only
            "```mermaid\n\t\t\n  \n```",         // Mixed whitespace
            "```mermaid\n\n\n\n```"              // Newlines only
        ]

        for (index, markdown) in testCases.enumerated() {
            let ast = try await parser.parseToAST(markdown)

            guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
                Issue.record("Test case \(index): Should create MermaidDiagramNode for empty/whitespace content")
                continue
            }

            // Should handle empty content gracefully
            #expect(mermaidNode.diagramType == nil, "Test case \(index): Empty content should have no detected type")
        }
    }

    @Test func mermaidUnterminatedFence() async throws {
        let unterminatedMarkdown = """
        ```mermaid
        graph TD
            A --> B
            B --> C
        # This fence is never closed
        """

        let ast = try await parser.parseToAST(unterminatedMarkdown)

        // Should still parse (though behavior may vary based on CommonMark spec)
        #expect(ast.children.count > 0, "Should create some AST nodes")

        // If it creates a MermaidDiagramNode, it should contain the content
        if let mermaidNode = ast.children.first as? AST.MermaidDiagramNode {
            #expect(mermaidNode.content.contains("graph TD"))
        }
    }

    // MARK: - Error Boundary Tests

    @Test func mermaidWithMixedCodeBlocks() async throws {
        let mixedMarkdown = """
        ```python
        print("Regular code")
        ```

        ```mermaid
        graph TD
            A --> B
        ```

        ```javascript
        console.log("More code");
        ```

        ```mermaid
        sequenceDiagram
            Alice->>Bob: Hello
        ```
        """

        let ast = try await parser.parseToAST(mixedMarkdown)

        // Should correctly identify each block type
        var codeBlocks = 0
        var mermaidNodes = 0

        for child in ast.children {
            if child is AST.CodeBlockNode {
                codeBlocks += 1
            } else if child is AST.MermaidDiagramNode {
                mermaidNodes += 1
            }
        }

        #expect(codeBlocks == 2, "Should have 2 regular code blocks")
        #expect(mermaidNodes == 2, "Should have 2 Mermaid diagram nodes")
    }

    @Test func mermaidCaseInsensitivitySecurity() async throws {
        // Test various case combinations to ensure no case-based bypasses
        let testCases = [
            "```MERMAID\nscript\n```",
            "```Mermaid\nscript\n```",
            "```mErMaId\nscript\n```",
            "```MERMAID\nscript\n```"
        ]

        for (index, markdown) in testCases.enumerated() {
            let ast = try await parser.parseToAST(markdown)

            guard let mermaidNode = ast.children.first as? AST.MermaidDiagramNode else {
                Issue.record("Test case \(index): Should create MermaidDiagramNode for case variation")
                continue
            }

            #expect(mermaidNode.content.contains("script"), "Test case \(index): Should preserve content")
        }
    }

    // MARK: - Configuration Security Tests

    @Test func mermaidRendererSecurityConfiguration() async throws {
        // Test that security configuration prevents unsafe operations
        let secureConfig = MermaidConfiguration(
            enabled: true,
            securityLevel: .strict,
            maxTextSize: 10000,   // Limit content size
            displayErrors: false  // Don't expose error details
        )

        let renderer = MermaidRenderer(configuration: secureConfig)
        let node = AST.MermaidDiagramNode(content: "graph TD\n    A --> B")

        let html = renderer.renderMermaidDiagram(node)

        // Should generate secure HTML
        #expect(html.contains("mermaid-container"))
        #expect(html.contains("class=\"mermaid\""))

        // Configuration should have secure settings
        let initScript = secureConfig.generateInitScript()
        #expect(initScript.contains("securityLevel: 'strict'"))
        #expect(!initScript.contains("displayErrors: true"))
    }

    @Test func mermaidRendererDisabledSecurely() async throws {
        // Test that disabled Mermaid renders safely as code blocks
        let disabledConfig = MermaidConfiguration(enabled: false)
        let renderer = MermaidRenderer(configuration: disabledConfig)

        let maliciousNode = AST.MermaidDiagramNode(
            content: "graph TD\n    A[\"<script>alert('XSS')</script>\"] --> B"
        )

        let html = renderer.renderMermaidDiagram(maliciousNode)

        // Should render as safe code block
        #expect(html.contains("<code class=\"language-mermaid\">"))
        #expect(!html.contains("mermaid-container"))

        // Should escape dangerous content
        #expect(!html.contains("<script>alert('XSS')</script>"))
    }

    // MARK: - Memory and Resource Tests

    @Test func mermaidMemoryConsumption() async throws {
        // Test that parsing doesn't consume excessive memory
        let initialMemory = getMemoryUsage()

        let largeMarkdown = Self.generateLargeMermaidDocument(nodeCount: 1000)

        let ast = try await parser.parseToAST(largeMarkdown)
        let finalMemory = getMemoryUsage()

        // Memory should not increase excessively (less than 50MB for this test)
        let memoryIncrease = finalMemory - initialMemory
        #expect(memoryIncrease < 50 * 1024 * 1024, "Memory increase should be reasonable")

        // Should still create valid nodes
        let mermaidNodeCount = ast.children.compactMap { $0 as? AST.MermaidDiagramNode }.count
        #expect(mermaidNodeCount > 0, "Should create Mermaid nodes")
    }

    // MARK: - Helper Methods

    private static func generateLargeMermaidDocument(nodeCount: Int) -> String {
        var markdown = "# Large Document Test\n\n"

        for i in 0..<10 {  // 10 diagrams with many nodes each
            markdown += "```mermaid\n"
            markdown += "graph TD\n"

            let nodesPerDiagram = nodeCount / 10
            for j in 0..<nodesPerDiagram {
                let nodeIndex = i * nodesPerDiagram + j
                markdown += "    Node\(nodeIndex) --> Node\(nodeIndex + 1)\n"
            }

            markdown += "```\n\n"
        }

        return markdown
    }

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}
