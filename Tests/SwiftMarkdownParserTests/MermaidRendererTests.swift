import Testing
import Foundation
@testable import SwiftMarkdownParser

/// Tests for Mermaid diagram rendering functionality
@Suite struct MermaidRendererTests {

    private let parser: SwiftMarkdownParser

    init() {
        parser = SwiftMarkdownParser()
    }

    // MARK: - HTML Rendering Tests

    @Test func renderMermaidToHTML() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A[Start] --> B[End]
        ```
        """

        let html = try await parser.parseToHTML(markdown)

        // Should contain Mermaid container
        #expect(html.contains("mermaid-container"))
        #expect(html.contains("class=\"mermaid\""))
        #expect(html.contains("graph TD"))
        #expect(html.contains("A[Start] --> B[End]"))

        // Should include Mermaid initialization
        #expect(html.contains("mermaid.init"))
        #expect(html.contains("DOMContentLoaded"))
    }

    @Test func renderMermaidWithConfiguration() async throws {
        let markdown = """
        ```mermaid
        sequenceDiagram
            Alice->>Bob: Hello
        ```
        """

        // For now, just test with default configuration
        let context = RenderContext()
        let html = try await parser.parseToHTML(markdown, context: context)

        // Should contain the sequence diagram
        #expect(html.contains("sequenceDiagram"))
        #expect(html.contains("Alice->>Bob: Hello"))
        #expect(html.contains("mermaid-container"))
    }

    @Test func renderDisabledMermaid() async throws {
        let _ = """
        ```mermaid
        graph TD
            A --> B
        ```
        """

        // Test with direct renderer that has disabled configuration
        let config = MermaidConfiguration(enabled: false)
        let renderer = MermaidRenderer(configuration: config)
        let node = AST.MermaidDiagramNode(content: "graph TD\n    A --> B")
        let html = renderer.renderMermaidDiagram(node)

        // Should render as regular code block when disabled
        #expect(html.contains("<code class=\"language-mermaid\">"))
        #expect(html.contains("graph TD"))

        // Should not include Mermaid container
        #expect(!html.contains("mermaid-container"))
    }

    @Test func renderMultipleMermaidDiagrams() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A --> B
        ```

        Some text.

        ```mermaid
        sequenceDiagram
            Alice->>Bob: Hello
        ```
        """

        let html = try await parser.parseToHTML(markdown)

        // Should contain both diagrams
        #expect(html.contains("graph TD"))
        #expect(html.contains("sequenceDiagram"))

        // Should have two mermaid containers
        let containerMatches = html.components(separatedBy: "mermaid-container").count - 1
        #expect(containerMatches == 2)

        // Should only initialize once (but we have both mermaid.initialize and mermaid.init)
        let initializeMatches = html.components(separatedBy: "mermaid.initialize").count - 1
        let initMatches = html.components(separatedBy: "mermaid.init()").count - 1
        #expect(initializeMatches == 1, "Should have one mermaid.initialize call")
        #expect(initMatches == 1, "Should have one mermaid.init() call")
    }

    // MARK: - MermaidRenderer Direct Tests

    @Test func mermaidRendererBasicHTML() async throws {
        let node = AST.MermaidDiagramNode(
            content: "graph LR\n    A --> B",
            diagramType: "flowchart"
        )

        let renderer = MermaidRenderer()
        let html = renderer.renderMermaidDiagram(node)

        #expect(html.contains("mermaid-container"))
        #expect(html.contains("class=\"mermaid\""))
        #expect(html.contains("graph LR"))
        #expect(html.contains("A --> B"))
    }

    @Test func mermaidRendererWithCustomId() async throws {
        let node = AST.MermaidDiagramNode(
            content: "pie title Test\n    \"A\" : 50\n    \"B\" : 50",
            diagramType: "pie"
        )

        let renderer = MermaidRenderer()
        let html = renderer.renderMermaidDiagram(node, id: "custom-diagram")

        #expect(html.contains("id=\"custom-diagram\""))
        #expect(html.contains("id=\"custom-diagram-container\""))
    }

    @Test func mermaidRendererDisabled() async throws {
        let node = AST.MermaidDiagramNode(
            content: "graph TD\n    A --> B",
            diagramType: "flowchart"
        )

        let config = MermaidConfiguration(enabled: false)
        let renderer = MermaidRenderer(configuration: config)
        let html = renderer.renderMermaidDiagram(node)

        // Should render as code block when disabled
        #expect(html.contains("<code class=\"language-mermaid\">"))
        #expect(!html.contains("class=\"mermaid\""))
        #expect(!html.contains("mermaid-container"))
    }

    @Test func standaloneHTMLGeneration() async throws {
        let renderer = MermaidRenderer()
        let content = "<div>Test Content</div>"
        let html = renderer.generateStandaloneHTML(content: content, title: "Test Document")

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("<title>Test Document</title>"))
        #expect(html.contains("<div>Test Content</div>"))
        #expect(html.contains("DOMContentLoaded"))
    }

    // MARK: - Configuration Tests

    @Test func mermaidConfigurationDefault() async throws {
        let config = MermaidConfiguration.default

        #expect(config.enabled)
        #expect(config.theme == .default)
        #expect(config.securityLevel == .strict)
        #expect(config.startOnLoad)
    }

    @Test func mermaidConfigurationDark() async throws {
        let config = MermaidConfiguration.dark

        #expect(config.theme == .dark)
        #expect(config.enabled)
    }

    @Test func mermaidConfigurationCustom() async throws {
        let config = MermaidConfiguration(
            enabled: true,
            theme: .forest,
            renderMode: .custom(url: "https://example.com/mermaid.js"),
            securityLevel: .loose,
            fontSize: 18,
            htmlIdPrefix: "custom-"
        )

        #expect(config.theme == .forest)
        #expect(config.securityLevel == .loose)
        #expect(config.fontSize == 18)
        #expect(config.htmlIdPrefix == "custom-")

        if case .custom(let url) = config.renderMode {
            #expect(url == "https://example.com/mermaid.js")
        } else {
            Issue.record("Expected custom render mode")
        }
    }

    @Test func mermaidConfigurationInitScript() async throws {
        let config = MermaidConfiguration(
            theme: .neutral,
            fontSize: 20,
            flowchart: FlowchartConfig(curve: .linear, padding: 12),
            sequence: SequenceConfig(showNumbers: true, actorMargin: 60)
        )

        let script = config.generateInitScript()

        #expect(script.contains("theme: 'neutral'"))
        #expect(script.contains("fontSize: 20"))
        #expect(script.contains("curve: 'linear'"))
        #expect(script.contains("padding: 12"))
        #expect(script.contains("showSequenceNumbers: true"))
        #expect(script.contains("actorMargin: 60"))
        #expect(script.contains("mermaid.initialize"))
    }

    // MARK: - Utility Tests

    @Test func mermaidUtilsValidation() async throws {
        #expect(MermaidUtils.isValidMermaidSyntax("graph TD\n    A --> B"))
        #expect(MermaidUtils.isValidMermaidSyntax("sequenceDiagram\n    Alice->>Bob: Hello"))
        #expect(MermaidUtils.isValidMermaidSyntax("gantt\n    title Test"))

        #expect(!MermaidUtils.isValidMermaidSyntax("console.log('not mermaid')"))
        #expect(!MermaidUtils.isValidMermaidSyntax(""))
        #expect(!MermaidUtils.isValidMermaidSyntax("   \n  \n  "))
    }

    @Test func mermaidUtilsTypeExtraction() async throws {
        #expect(MermaidUtils.extractDiagramType(from: "graph TD\n    A --> B") == "flowchart")
        #expect(MermaidUtils.extractDiagramType(from: "flowchart LR\n    A --> B") == "flowchart")
        #expect(MermaidUtils.extractDiagramType(from: "sequenceDiagram\n    A->>B: Hi") == "sequence")
        #expect(MermaidUtils.extractDiagramType(from: "classDiagram\n    class A") == "class")
        #expect(MermaidUtils.extractDiagramType(from: "pie title Test\n    \"A\" : 50") == "pie")

        #expect(MermaidUtils.extractDiagramType(from: "unknown diagram type") == nil)
    }

    @Test func mermaidUtilsSafeIdGeneration() async throws {
        let id1 = MermaidUtils.generateSafeId(from: "graph TD\n    A --> B")
        let id2 = MermaidUtils.generateSafeId(from: "graph TD\n    A --> B")
        let id3 = MermaidUtils.generateSafeId(from: "sequenceDiagram\n    A->>B: Hi")

        // Same content should generate same ID
        #expect(id1 == id2)

        // Different content should generate different IDs
        #expect(id1 != id3)

        // Should start with default prefix
        #expect(id1.hasPrefix("mermaid-"))

        // Test custom prefix
        let customId = MermaidUtils.generateSafeId(from: "graph TD", prefix: "custom-")
        #expect(customId.hasPrefix("custom-"))
    }

    // MARK: - Integration Tests

    @Test func fullDocumentWithMermaidAndOtherContent() async throws {
        let markdown = """
        # My Document

        This is a paragraph with some **bold** text.

        ```mermaid
        graph TD
            A[Start] --> B{Decision}
            B -->|Yes| C[Action 1]
            B -->|No| D[Action 2]
            C --> E[End]
            D --> E
        ```

        Here's another paragraph after the diagram.

        - List item 1
        - List item 2

        ```swift
        let code = "This is regular code"
        print(code)
        ```

        ```mermaid
        sequenceDiagram
            participant U as User
            participant S as System
            U->>S: Request
            S-->>U: Response
        ```
        """

        let html = try await parser.parseToHTML(markdown)

        // Should contain heading
        #expect(html.contains("<h1>My Document</h1>"))

        // Should contain paragraphs with formatting
        #expect(html.contains("<strong>bold</strong>"))

        // Should contain both Mermaid diagrams
        #expect(html.contains("graph TD"))
        #expect(html.contains("sequenceDiagram"))
        #expect(html.contains("A[Start] --> B{Decision}"))
        #expect(html.contains("U->>S: Request"))

        // Should contain list (list items are wrapped in paragraphs)
        #expect(html.contains("<li><p>List item 1</p>"))

        // Should contain regular code block (content is HTML escaped)
        #expect(html.contains("class=\"language-swift\""))
        #expect(html.contains("let code = &quot;This is regular code&quot;"))

        // Should have proper Mermaid initialization
        #expect(html.contains("mermaid.init"))

        // Should have two mermaid containers
        let containerMatches = html.components(separatedBy: "mermaid-container").count - 1
        #expect(containerMatches == 2)
    }

    // MARK: - Error Handling Tests

    @Test func mermaidWithSpecialCharacters() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A["Text with <> & quotes"] --> B[Normal]
            B --> C["More & special > chars"]
        ```
        """

        let html = try await parser.parseToHTML(markdown)

        // Should preserve special characters in diagram content
        #expect(html.contains("Text with <> & quotes"))
        #expect(html.contains("More & special > chars"))

        // Should be valid HTML structure
        #expect(html.contains("class=\"mermaid\""))
        #expect(html.contains("mermaid-container"))
    }

    @Test func mermaidWithUnicodeCharacters() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A["Héllo 世界 🌍"] --> B["Mérci ñoël"]
        ```
        """

        let html = try await parser.parseToHTML(markdown)

        // Should preserve Unicode characters
        #expect(html.contains("Héllo 世界 🌍"))
        #expect(html.contains("Mérci ñoël"))
    }

    // MARK: - Dark Theme Visibility Tests

    @Test func enhancedDarkThemeVisibility() async throws {
        let markdown = """
        ```mermaid
        sequenceDiagram
            participant User
            participant App
            participant FileService
            participant MermaidRenderer
            User->>App: Open Mermaid File
            App->>FileService: Read File Content
            FileService-->>App: Return Content
            App->>MermaidRenderer: Extract Charts
            MermaidRenderer-->>App: Return Processed Content
            App-->>User: Display Rendered Chart
        ```
        """

        let html = try await parser.parseToHTMLWithDarkTheme(markdown)

        // Should contain Mermaid structure
        #expect(html.contains("mermaid-container"))
        #expect(html.contains("class=\"mermaid\""))

        // Should contain the enhanced dark theme CSS
        #expect(html.contains(".mermaid .messageText"))
        #expect(html.contains("fill: #ffffff !important"))
        #expect(html.contains("font-weight: 500"))

        // Should contain custom CSS injection
        #expect(html.contains("document.createElement('style')"))

        // Should contain the diagram content
        #expect(html.contains("sequenceDiagram"))
        #expect(html.contains("participant User"))
    }

    @Test func highContrastDarkTheme() async throws {
        let markdown = """
        ```mermaid
        sequenceDiagram
            participant A as Actor A
            participant B as Actor B
            A->>B: Important Message
            Note over A,B: Critical Note
        ```
        """

        let html = try await parser.parseToHTMLWithDarkHighContrastTheme(markdown)

        // Should contain high contrast styling
        #expect(html.contains("font-weight: bold"))
        #expect(html.contains("text-shadow: 1px 1px 2px"))
        #expect(html.contains("stroke-width: 2px"))

        // Should contain proper structure
        #expect(html.contains("mermaid-container"))
        #expect(html.contains("sequenceDiagram"))
    }

    @Test func darkThemeConfigurationGeneration() async throws {
        let darkConfig = MermaidConfiguration.dark
        let script = darkConfig.generateInitScript()

        // Should contain dark theme configuration
        #expect(script.contains("theme: 'dark'"))
        #expect(script.contains("mermaid.initialize"))

        // Should contain CSS injection code
        #expect(script.contains("document.createElement('style')"))
        #expect(script.contains(".mermaid .messageText"))
    }

    @Test func highContrastConfigurationGeneration() async throws {
        let highContrastConfig = MermaidConfiguration.darkHighContrast
        let script = highContrastConfig.generateInitScript()

        // Should contain dark theme with high contrast styling
        #expect(script.contains("theme: 'dark'"))
        #expect(script.contains("font-weight: bold"))
        #expect(script.contains("text-shadow"))
        #expect(script.contains("stroke-width: 2px"))
    }

    @Test func customCSSInjection() async throws {
        let customCSS = """
        .mermaid text {
            fill: #ff0000 !important;
            font-size: 18px;
        }
        """

        let config = MermaidConfiguration(customCSS: customCSS)
        let context = RenderContext(mermaidConfiguration: config)

        let markdown = """
        ```mermaid
        graph TD
            A --> B
        ```
        """

        let html = try await parser.parseToHTML(markdown, context: context)

        // Should contain custom CSS
        #expect(html.contains("fill: #ff0000 !important"))
        #expect(html.contains("font-size: 18px"))
        #expect(html.contains("document.createElement('style')"))
    }

    // MARK: - Performance Tests

    @Test func mermaidRenderingPerformance() async throws {
        // Create a document with multiple Mermaid diagrams
        var markdown = "# Performance Test\n\n"

        for i in 1...10 {
            markdown += """
            ```mermaid
            graph TD
                A\(i)[Start \(i)] --> B\(i)[Process \(i)]
                B\(i) --> C\(i)[End \(i)]
            ```

            Paragraph \(i) with some content.

            """
        }

        let startTime = Date()
        let html = try await parser.parseToHTML(markdown)
        let endTime = Date()

        // Should complete within reasonable time (< 2 seconds)
        #expect(endTime.timeIntervalSince(startTime) < 2.0)

        // Should contain all diagrams
        for i in 1...10 {
            #expect(html.contains("Start \(i)"))
            #expect(html.contains("Process \(i)"))
            #expect(html.contains("End \(i)"))
        }

        // Should have 10 mermaid containers
        let containerMatches = html.components(separatedBy: "mermaid-container").count - 1
        #expect(containerMatches == 10)

        // Should only initialize once (but we have both mermaid.initialize and mermaid.init)
        let initializeMatches = html.components(separatedBy: "mermaid.initialize").count - 1
        let initMatches = html.components(separatedBy: "mermaid.init()").count - 1
        #expect(initializeMatches == 1, "Should have one mermaid.initialize call")
        #expect(initMatches == 1, "Should have one mermaid.init() call")
    }

    // MARK: - Theme Support Tests

    @Test func renderWithDarkTheme() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A[Start] --> B[End]
        ```
        """

        let mermaidConfig = MermaidConfiguration(theme: .dark)
        let context = RenderContext(mermaidConfiguration: mermaidConfig)
        let html = try await parser.parseToHTML(markdown, context: context)

        // Should contain dark theme setting in initialization
        #expect(html.contains("theme: 'dark'"))
        #expect(html.contains("mermaid-container"))
        #expect(html.contains("graph TD"))
    }

    @Test func renderWithForestTheme() async throws {
        let markdown = """
        ```mermaid
        sequenceDiagram
            Alice->>Bob: Hello
        ```
        """

        let mermaidConfig = MermaidConfiguration(theme: .forest)
        let context = RenderContext(mermaidConfiguration: mermaidConfig)
        let html = try await parser.parseToHTML(markdown, context: context)

        // Should contain forest theme setting
        #expect(html.contains("theme: 'forest'"))
        #expect(html.contains("sequenceDiagram"))
    }

    @Test func renderWithNeutralTheme() async throws {
        let markdown = """
        ```mermaid
        pie title Pets
            "Dogs" : 386
            "Cats" : 85
        ```
        """

        let mermaidConfig = MermaidConfiguration(theme: .neutral)
        let context = RenderContext(mermaidConfiguration: mermaidConfig)
        let html = try await parser.parseToHTML(markdown, context: context)

        // Should contain neutral theme setting
        #expect(html.contains("theme: 'neutral'"))
        #expect(html.contains("pie title Pets"))
    }

    @Test func renderWithBaseTheme() async throws {
        let markdown = """
        ```mermaid
        classDiagram
            class Animal
        ```
        """

        let mermaidConfig = MermaidConfiguration(theme: .base)
        let context = RenderContext(mermaidConfiguration: mermaidConfig)
        let html = try await parser.parseToHTML(markdown, context: context)

        // Should contain base theme setting
        #expect(html.contains("theme: 'base'"))
        #expect(html.contains("classDiagram"))
    }

    @Test func renderWithCustomThemeConfiguration() async throws {
        let markdown = """
        ```mermaid
        flowchart LR
            A --> B
        ```
        """

        let customFlowchart = FlowchartConfig(curve: .linear, padding: 16, nodeSpacing: 75)
        let customSequence = SequenceConfig(showNumbers: true, actorMargin: 65)
        let mermaidConfig = MermaidConfiguration(
            theme: .dark,
            fontFamily: "Arial, sans-serif",
            fontSize: 18,
            flowchart: customFlowchart,
            sequence: customSequence
        )
        let context = RenderContext(mermaidConfiguration: mermaidConfig)
        let html = try await parser.parseToHTML(markdown, context: context)

        // Should contain all custom settings
        #expect(html.contains("theme: 'dark'"))
        #expect(html.contains("fontSize: 18"))
        #expect(html.contains("fontFamily: 'Arial, sans-serif'"))
        #expect(html.contains("curve: 'linear'"))
        #expect(html.contains("padding: 16"))
        #expect(html.contains("nodeSpacing: 75"))
        #expect(html.contains("showSequenceNumbers: true"))
        #expect(html.contains("actorMargin: 65"))
    }

    @Test func multipleDiagramsWithDifferentThemes() async throws {
        let markdown1 = """
        ```mermaid
        graph TD
            A --> B
        ```
        """

        let markdown2 = """
        ```mermaid
        sequenceDiagram
            Alice->>Bob: Hi
        ```
        """

        // Render with dark theme
        let darkConfig = MermaidConfiguration(theme: .dark)
        let darkContext = RenderContext(mermaidConfiguration: darkConfig)
        let darkHTML = try await parser.parseToHTML(markdown1, context: darkContext)

        // Render with forest theme
        let forestConfig = MermaidConfiguration(theme: .forest)
        let forestContext = RenderContext(mermaidConfiguration: forestConfig)
        let forestHTML = try await parser.parseToHTML(markdown2, context: forestContext)

        // Verify each HTML contains the correct theme
        #expect(darkHTML.contains("theme: 'dark'"))
        #expect(!darkHTML.contains("theme: 'forest'"))

        #expect(forestHTML.contains("theme: 'forest'"))
        #expect(!forestHTML.contains("theme: 'dark'"))
    }

    @Test func themeWithDisabledMermaid() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A --> B
        ```
        """

        let mermaidConfig = MermaidConfiguration(enabled: false, theme: .dark)
        let context = RenderContext(mermaidConfiguration: mermaidConfig)
        let html = try await parser.parseToHTML(markdown, context: context)

        // Should render as code block and not contain theme settings
        #expect(html.contains("<code class=\"language-mermaid\">"))
        #expect(!html.contains("theme: 'dark'"))
        #expect(!html.contains("mermaid.initialize"))
    }

    @Test func parserConvenienceMethodsWithThemes() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A --> B
        ```
        """

        // Test dark theme convenience method
        let darkHTML = try await parser.parseToHTMLWithDarkTheme(markdown)
        #expect(darkHTML.contains("theme: 'dark'"))

        // Test forest theme convenience method
        let forestHTML = try await parser.parseToHTMLWithForestTheme(markdown)
        #expect(forestHTML.contains("theme: 'forest'"))

        // Test neutral theme convenience method
        let neutralHTML = try await parser.parseToHTMLWithNeutralTheme(markdown)
        #expect(neutralHTML.contains("theme: 'neutral'"))

        // Test base theme convenience method
        let baseHTML = try await parser.parseToHTMLWithBaseTheme(markdown)
        #expect(baseHTML.contains("theme: 'base'"))
    }

    // MARK: - HTML Output Verification Tests

    @Test func actualHTMLOutputContainsThemeSettings() async throws {
        let markdown = """
        # Theme Verification Test

        ```mermaid
        graph TD
            A[Start] --> B[Process] --> C[End]
        ```
        """

        // Test each theme generates different output
        let themes: [(theme: MermaidConfiguration.Theme, expected: String)] = [
            (.default, "theme: 'default'"),
            (.dark, "theme: 'dark'"),
            (.forest, "theme: 'forest'"),
            (.neutral, "theme: 'neutral'"),
            (.base, "theme: 'base'")
        ]

        for (theme, expectedTheme) in themes {
            let config = MermaidConfiguration(theme: theme)
            let context = RenderContext(mermaidConfiguration: config)
            let html = try await parser.parseToHTML(markdown, context: context)

            // Verify the HTML contains the expected theme
            #expect(html.contains(expectedTheme), "HTML should contain \(expectedTheme) for theme \(theme)")

            // Verify it contains Mermaid initialization
            #expect(html.contains("mermaid.initialize"), "HTML should contain Mermaid initialization")

            // Verify it contains the diagram content
            #expect(html.contains("A[Start] --> B[Process] --> C[End]"), "HTML should contain diagram content")

            // Verify it contains proper HTML structure
            #expect(html.contains("<h1>Theme Verification Test</h1>"), "HTML should contain heading")
            #expect(html.contains("class=\"mermaid\""), "HTML should contain Mermaid class")
        }
    }

    @Test func customConfigurationGeneratesCorrectHTML() async throws {
        let markdown = """
        ```mermaid
        flowchart LR
            Start --> End
        ```
        """

        let config = MermaidConfiguration(
            theme: .dark,
            renderMode: .cdn(version: "10.6.1"),
            securityLevel: .loose,
            fontFamily: "Arial, sans-serif",
            fontSize: 20,
            maxTextSize: 60000,
            useMaxWidth: false,
            displayErrors: true,
            logLevel: 3,
            flowchart: FlowchartConfig(
                curve: .linear,
                padding: 20,
                nodeSpacing: 80,
                rankSpacing: 100
            ),
            sequence: SequenceConfig(
                showNumbers: true,
                actorMargin: 80,
                noteMargin: 15,
                messageMargin: 40,
                mirrorActors: false
            )
        )

        let context = RenderContext(mermaidConfiguration: config)
        let html = try await parser.parseToHTML(markdown, context: context)

        // Verify all configuration options are present
        #expect(html.contains("theme: 'dark'"))
        #expect(html.contains("cdn.jsdelivr.net/npm/mermaid@10.6.1"))
        #expect(html.contains("securityLevel: 'loose'"))
        #expect(html.contains("fontFamily: 'Arial, sans-serif'"))
        #expect(html.contains("fontSize: 20"))
        #expect(html.contains("maxTextSize: 60000"))
        #expect(html.contains("useMaxWidth: false"))
        #expect(html.contains("logLevel: 3"))

        // Verify flowchart configuration
        #expect(html.contains("curve: 'linear'"))
        #expect(html.contains("padding: 20"))
        #expect(html.contains("nodeSpacing: 80"))
        #expect(html.contains("rankSpacing: 100"))

        // Verify sequence configuration
        #expect(html.contains("showSequenceNumbers: true"))
        #expect(html.contains("actorMargin: 80"))
        #expect(html.contains("noteMargin: 15"))
        #expect(html.contains("messageMargin: 40"))
        #expect(html.contains("mirrorActors: false"))
    }

    @Test func renderModeVariationsGenerateCorrectHTML() async throws {
        let markdown = """
        ```mermaid
        pie title Test
            "A" : 50
            "B" : 50
        ```
        """

        // Test embedded mode
        let embeddedConfig = MermaidConfiguration(renderMode: .embedded)
        let embeddedContext = RenderContext(mermaidConfiguration: embeddedConfig)
        let embeddedHTML = try await parser.parseToHTML(markdown, context: embeddedContext)

        // Should contain embedded script (which includes a CDN fallback)
        #expect(embeddedHTML.contains("Mermaid.js Embedded Loader"))
        // Note: Embedded mode includes CDN fallback, so we check for the embedded loader marker instead

        // Test CDN mode
        let cdnConfig = MermaidConfiguration(renderMode: .cdn(version: "9.4.3"))
        let cdnContext = RenderContext(mermaidConfiguration: cdnConfig)
        let cdnHTML = try await parser.parseToHTML(markdown, context: cdnContext)

        // Should contain specific CDN link and not embedded loader
        #expect(cdnHTML.contains("cdn.jsdelivr.net/npm/mermaid@9.4.3"))
        #expect(!cdnHTML.contains("Mermaid.js Embedded Loader"))

        // Test custom mode
        let customConfig = MermaidConfiguration(renderMode: .custom(url: "https://example.com/custom-mermaid.js"))
        let customContext = RenderContext(mermaidConfiguration: customConfig)
        let customHTML = try await parser.parseToHTML(markdown, context: customContext)

        // Should contain custom URL and not embedded loader or standard CDN links
        #expect(customHTML.contains("https://example.com/custom-mermaid.js"))
        #expect(!customHTML.contains("Mermaid.js Embedded Loader"))
        #expect(!customHTML.contains("cdn.jsdelivr.net/npm/mermaid@9.4.3"))  // Should not contain the specific CDN version from other test
    }

    @Test func disabledMermaidProducesCodeBlock() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A --> B
        ```
        """

        let disabledConfig = MermaidConfiguration(enabled: false)
        let context = RenderContext(mermaidConfiguration: disabledConfig)
        let html = try await parser.parseToHTML(markdown, context: context)

        // Should render as a regular code block
        #expect(html.contains("<code class=\"language-mermaid\">"))
        #expect(html.contains("graph TD"))

        // Should not contain Mermaid-specific elements
        #expect(!html.contains("mermaid-container"))
        #expect(!html.contains("class=\"mermaid\""))
        #expect(!html.contains("mermaid.initialize"))
        #expect(!html.contains("DOMContentLoaded"))
    }
}
