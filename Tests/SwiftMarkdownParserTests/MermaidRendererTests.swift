import XCTest
@testable import SwiftMarkdownParser

/// Tests for Mermaid diagram rendering functionality
final class MermaidRendererTests: XCTestCase {
    
    private var parser: SwiftMarkdownParser!
    
    override func setUp() {
        super.setUp()
        parser = SwiftMarkdownParser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - HTML Rendering Tests
    
    func testRenderMermaidToHTML() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A[Start] --> B[End]
        ```
        """
        
        let html = try await parser.parseToHTML(markdown)
        
        // Should contain Mermaid container
        XCTAssertTrue(html.contains("mermaid-container"))
        XCTAssertTrue(html.contains("class=\"mermaid\""))
        XCTAssertTrue(html.contains("graph TD"))
        XCTAssertTrue(html.contains("A[Start] --> B[End]"))
        
        // Should include Mermaid initialization
        XCTAssertTrue(html.contains("mermaid.init"))
        XCTAssertTrue(html.contains("DOMContentLoaded"))
    }
    
    func testRenderMermaidWithConfiguration() async throws {
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
        XCTAssertTrue(html.contains("sequenceDiagram"))
        XCTAssertTrue(html.contains("Alice->>Bob: Hello"))
        XCTAssertTrue(html.contains("mermaid-container"))
    }
    
    func testRenderDisabledMermaid() async throws {
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
        XCTAssertTrue(html.contains("<code class=\"language-mermaid\">"))
        XCTAssertTrue(html.contains("graph TD"))
        
        // Should not include Mermaid container
        XCTAssertFalse(html.contains("mermaid-container"))
    }
    
    func testRenderMultipleMermaidDiagrams() async throws {
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
        XCTAssertTrue(html.contains("graph TD"))
        XCTAssertTrue(html.contains("sequenceDiagram"))
        
        // Should have two mermaid containers
        let containerMatches = html.components(separatedBy: "mermaid-container").count - 1
        XCTAssertEqual(containerMatches, 2)
        
        // Should only initialize once (but we have both mermaid.initialize and mermaid.init)
        let initializeMatches = html.components(separatedBy: "mermaid.initialize").count - 1
        let initMatches = html.components(separatedBy: "mermaid.init()").count - 1
        XCTAssertEqual(initializeMatches, 1, "Should have one mermaid.initialize call")
        XCTAssertEqual(initMatches, 1, "Should have one mermaid.init() call")
    }
    
    // MARK: - MermaidRenderer Direct Tests
    
    func testMermaidRendererBasicHTML() {
        let node = AST.MermaidDiagramNode(
            content: "graph LR\n    A --> B",
            diagramType: "flowchart"
        )
        
        let renderer = MermaidRenderer()
        let html = renderer.renderMermaidDiagram(node)
        
        XCTAssertTrue(html.contains("mermaid-container"))
        XCTAssertTrue(html.contains("class=\"mermaid\""))
        XCTAssertTrue(html.contains("graph LR"))
        XCTAssertTrue(html.contains("A --> B"))
    }
    
    func testMermaidRendererWithCustomId() {
        let node = AST.MermaidDiagramNode(
            content: "pie title Test\n    \"A\" : 50\n    \"B\" : 50",
            diagramType: "pie"
        )
        
        let renderer = MermaidRenderer()
        let html = renderer.renderMermaidDiagram(node, id: "custom-diagram")
        
        XCTAssertTrue(html.contains("id=\"custom-diagram\""))
        XCTAssertTrue(html.contains("id=\"custom-diagram-container\""))
    }
    
    func testMermaidRendererDisabled() {
        let node = AST.MermaidDiagramNode(
            content: "graph TD\n    A --> B",
            diagramType: "flowchart"
        )
        
        let config = MermaidConfiguration(enabled: false)
        let renderer = MermaidRenderer(configuration: config)
        let html = renderer.renderMermaidDiagram(node)
        
        // Should render as code block when disabled
        XCTAssertTrue(html.contains("<code class=\"language-mermaid\">"))
        XCTAssertFalse(html.contains("class=\"mermaid\""))
        XCTAssertFalse(html.contains("mermaid-container"))
    }
    
    func testStandaloneHTMLGeneration() {
        let renderer = MermaidRenderer()
        let content = "<div>Test Content</div>"
        let html = renderer.generateStandaloneHTML(content: content, title: "Test Document")
        
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<title>Test Document</title>"))
        XCTAssertTrue(html.contains("<div>Test Content</div>"))
        XCTAssertTrue(html.contains("DOMContentLoaded"))
    }
    
    // MARK: - Configuration Tests
    
    func testMermaidConfigurationDefault() {
        let config = MermaidConfiguration.default
        
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.theme, .default)
        XCTAssertEqual(config.securityLevel, .strict)
        XCTAssertTrue(config.startOnLoad)
    }
    
    func testMermaidConfigurationDark() {
        let config = MermaidConfiguration.dark
        
        XCTAssertEqual(config.theme, .dark)
        XCTAssertTrue(config.enabled)
    }
    
    func testMermaidConfigurationCustom() {
        let config = MermaidConfiguration(
            enabled: true,
            theme: .forest,
            renderMode: .custom(url: "https://example.com/mermaid.js"),
            securityLevel: .loose,
            fontSize: 18,
            htmlIdPrefix: "custom-"
        )
        
        XCTAssertEqual(config.theme, .forest)
        XCTAssertEqual(config.securityLevel, .loose)
        XCTAssertEqual(config.fontSize, 18)
        XCTAssertEqual(config.htmlIdPrefix, "custom-")
        
        if case .custom(let url) = config.renderMode {
            XCTAssertEqual(url, "https://example.com/mermaid.js")
        } else {
            XCTFail("Expected custom render mode")
        }
    }
    
    func testMermaidConfigurationInitScript() {
        let config = MermaidConfiguration(
            theme: .neutral,
            fontSize: 20,
            flowchart: FlowchartConfig(curve: .linear, padding: 12),
            sequence: SequenceConfig(showNumbers: true, actorMargin: 60)
        )
        
        let script = config.generateInitScript()
        
        XCTAssertTrue(script.contains("theme: 'neutral'"))
        XCTAssertTrue(script.contains("fontSize: 20"))
        XCTAssertTrue(script.contains("curve: 'linear'"))
        XCTAssertTrue(script.contains("padding: 12"))
        XCTAssertTrue(script.contains("showSequenceNumbers: true"))
        XCTAssertTrue(script.contains("actorMargin: 60"))
        XCTAssertTrue(script.contains("mermaid.initialize"))
    }
    
    // MARK: - Utility Tests
    
    func testMermaidUtilsValidation() {
        XCTAssertTrue(MermaidUtils.isValidMermaidSyntax("graph TD\n    A --> B"))
        XCTAssertTrue(MermaidUtils.isValidMermaidSyntax("sequenceDiagram\n    Alice->>Bob: Hello"))
        XCTAssertTrue(MermaidUtils.isValidMermaidSyntax("gantt\n    title Test"))
        
        XCTAssertFalse(MermaidUtils.isValidMermaidSyntax("console.log('not mermaid')"))
        XCTAssertFalse(MermaidUtils.isValidMermaidSyntax(""))
        XCTAssertFalse(MermaidUtils.isValidMermaidSyntax("   \n  \n  "))
    }
    
    func testMermaidUtilsTypeExtraction() {
        XCTAssertEqual(MermaidUtils.extractDiagramType(from: "graph TD\n    A --> B"), "flowchart")
        XCTAssertEqual(MermaidUtils.extractDiagramType(from: "flowchart LR\n    A --> B"), "flowchart")
        XCTAssertEqual(MermaidUtils.extractDiagramType(from: "sequenceDiagram\n    A->>B: Hi"), "sequence")
        XCTAssertEqual(MermaidUtils.extractDiagramType(from: "classDiagram\n    class A"), "class")
        XCTAssertEqual(MermaidUtils.extractDiagramType(from: "pie title Test\n    \"A\" : 50"), "pie")
        
        XCTAssertNil(MermaidUtils.extractDiagramType(from: "unknown diagram type"))
    }
    
    func testMermaidUtilsSafeIdGeneration() {
        let id1 = MermaidUtils.generateSafeId(from: "graph TD\n    A --> B")
        let id2 = MermaidUtils.generateSafeId(from: "graph TD\n    A --> B")
        let id3 = MermaidUtils.generateSafeId(from: "sequenceDiagram\n    A->>B: Hi")
        
        // Same content should generate same ID
        XCTAssertEqual(id1, id2)
        
        // Different content should generate different IDs
        XCTAssertNotEqual(id1, id3)
        
        // Should start with default prefix
        XCTAssertTrue(id1.hasPrefix("mermaid-"))
        
        // Test custom prefix
        let customId = MermaidUtils.generateSafeId(from: "graph TD", prefix: "custom-")
        XCTAssertTrue(customId.hasPrefix("custom-"))
    }
    
    // MARK: - Integration Tests
    
    func testFullDocumentWithMermaidAndOtherContent() async throws {
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
        XCTAssertTrue(html.contains("<h1>My Document</h1>"))
        
        // Should contain paragraphs with formatting
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        
        // Should contain both Mermaid diagrams
        XCTAssertTrue(html.contains("graph TD"))
        XCTAssertTrue(html.contains("sequenceDiagram"))
        XCTAssertTrue(html.contains("A[Start] --> B{Decision}"))
        XCTAssertTrue(html.contains("U->>S: Request"))
        
        // Should contain list (list items are wrapped in paragraphs)
        XCTAssertTrue(html.contains("<li><p>List item 1</p>"))
        
        // Should contain regular code block (content is HTML escaped)
        XCTAssertTrue(html.contains("class=\"language-swift\""))
        XCTAssertTrue(html.contains("let code = &quot;This is regular code&quot;"))
        
        // Should have proper Mermaid initialization
        XCTAssertTrue(html.contains("mermaid.init"))
        
        // Should have two mermaid containers
        let containerMatches = html.components(separatedBy: "mermaid-container").count - 1
        XCTAssertEqual(containerMatches, 2)
    }
    
    // MARK: - Error Handling Tests
    
    func testMermaidWithSpecialCharacters() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A["Text with <> & quotes"] --> B[Normal]
            B --> C["More & special > chars"]
        ```
        """
        
        let html = try await parser.parseToHTML(markdown)
        
        // Should preserve special characters in diagram content
        XCTAssertTrue(html.contains("Text with <> & quotes"))
        XCTAssertTrue(html.contains("More & special > chars"))
        
        // Should be valid HTML structure
        XCTAssertTrue(html.contains("class=\"mermaid\""))
        XCTAssertTrue(html.contains("mermaid-container"))
    }
    
    func testMermaidWithUnicodeCharacters() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A["Héllo 世界 🌍"] --> B["Mérci ñoël"]
        ```
        """
        
        let html = try await parser.parseToHTML(markdown)
        
        // Should preserve Unicode characters
        XCTAssertTrue(html.contains("Héllo 世界 🌍"))
        XCTAssertTrue(html.contains("Mérci ñoël"))
    }
    
    // MARK: - Dark Theme Visibility Tests
    
    func testEnhancedDarkThemeVisibility() async throws {
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
        XCTAssertTrue(html.contains("mermaid-container"))
        XCTAssertTrue(html.contains("class=\"mermaid\""))
        
        // Should contain the enhanced dark theme CSS
        XCTAssertTrue(html.contains(".mermaid .messageText"))
        XCTAssertTrue(html.contains("fill: #ffffff !important"))
        XCTAssertTrue(html.contains("font-weight: 500"))
        
        // Should contain custom CSS injection
        XCTAssertTrue(html.contains("document.createElement('style')"))
        
        // Should contain the diagram content
        XCTAssertTrue(html.contains("sequenceDiagram"))
        XCTAssertTrue(html.contains("participant User"))
    }
    
    func testHighContrastDarkTheme() async throws {
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
        XCTAssertTrue(html.contains("font-weight: bold"))
        XCTAssertTrue(html.contains("text-shadow: 1px 1px 2px"))
        XCTAssertTrue(html.contains("stroke-width: 2px"))
        
        // Should contain proper structure
        XCTAssertTrue(html.contains("mermaid-container"))
        XCTAssertTrue(html.contains("sequenceDiagram"))
    }
    
    func testDarkThemeConfigurationGeneration() {
        let darkConfig = MermaidConfiguration.dark
        let script = darkConfig.generateInitScript()
        
        // Should contain dark theme configuration
        XCTAssertTrue(script.contains("theme: 'dark'"))
        XCTAssertTrue(script.contains("mermaid.initialize"))
        
        // Should contain CSS injection code
        XCTAssertTrue(script.contains("document.createElement('style')"))
        XCTAssertTrue(script.contains(".mermaid .messageText"))
    }
    
    func testHighContrastConfigurationGeneration() {
        let highContrastConfig = MermaidConfiguration.darkHighContrast
        let script = highContrastConfig.generateInitScript()
        
        // Should contain dark theme with high contrast styling
        XCTAssertTrue(script.contains("theme: 'dark'"))
        XCTAssertTrue(script.contains("font-weight: bold"))
        XCTAssertTrue(script.contains("text-shadow"))
        XCTAssertTrue(script.contains("stroke-width: 2px"))
    }
    
    func testCustomCSSInjection() async throws {
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
        XCTAssertTrue(html.contains("fill: #ff0000 !important"))
        XCTAssertTrue(html.contains("font-size: 18px"))
        XCTAssertTrue(html.contains("document.createElement('style')"))
    }
    
    // MARK: - Performance Tests
    
    func testMermaidRenderingPerformance() async throws {
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
        XCTAssertLessThan(endTime.timeIntervalSince(startTime), 2.0)
        
        // Should contain all diagrams
        for i in 1...10 {
            XCTAssertTrue(html.contains("Start \(i)"))
            XCTAssertTrue(html.contains("Process \(i)"))
            XCTAssertTrue(html.contains("End \(i)"))
        }
        
        // Should have 10 mermaid containers
        let containerMatches = html.components(separatedBy: "mermaid-container").count - 1
        XCTAssertEqual(containerMatches, 10)
        
        // Should only initialize once (but we have both mermaid.initialize and mermaid.init)
        let initializeMatches = html.components(separatedBy: "mermaid.initialize").count - 1
        let initMatches = html.components(separatedBy: "mermaid.init()").count - 1
        XCTAssertEqual(initializeMatches, 1, "Should have one mermaid.initialize call")
        XCTAssertEqual(initMatches, 1, "Should have one mermaid.init() call")
    }
    
    // MARK: - Theme Support Tests
    
    func testRenderWithDarkTheme() async throws {
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
        XCTAssertTrue(html.contains("theme: 'dark'"))
        XCTAssertTrue(html.contains("mermaid-container"))
        XCTAssertTrue(html.contains("graph TD"))
    }
    
    func testRenderWithForestTheme() async throws {
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
        XCTAssertTrue(html.contains("theme: 'forest'"))
        XCTAssertTrue(html.contains("sequenceDiagram"))
    }
    
    func testRenderWithNeutralTheme() async throws {
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
        XCTAssertTrue(html.contains("theme: 'neutral'"))
        XCTAssertTrue(html.contains("pie title Pets"))
    }
    
    func testRenderWithBaseTheme() async throws {
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
        XCTAssertTrue(html.contains("theme: 'base'"))
        XCTAssertTrue(html.contains("classDiagram"))
    }
    
    func testRenderWithCustomThemeConfiguration() async throws {
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
        XCTAssertTrue(html.contains("theme: 'dark'"))
        XCTAssertTrue(html.contains("fontSize: 18"))
        XCTAssertTrue(html.contains("fontFamily: 'Arial, sans-serif'"))
        XCTAssertTrue(html.contains("curve: 'linear'"))
        XCTAssertTrue(html.contains("padding: 16"))
        XCTAssertTrue(html.contains("nodeSpacing: 75"))
        XCTAssertTrue(html.contains("showSequenceNumbers: true"))
        XCTAssertTrue(html.contains("actorMargin: 65"))
    }
    
    func testMultipleDiagramsWithDifferentThemes() async throws {
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
        XCTAssertTrue(darkHTML.contains("theme: 'dark'"))
        XCTAssertFalse(darkHTML.contains("theme: 'forest'"))
        
        XCTAssertTrue(forestHTML.contains("theme: 'forest'"))
        XCTAssertFalse(forestHTML.contains("theme: 'dark'"))
    }
    
    func testThemeWithDisabledMermaid() async throws {
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
        XCTAssertTrue(html.contains("<code class=\"language-mermaid\">"))
        XCTAssertFalse(html.contains("theme: 'dark'"))
        XCTAssertFalse(html.contains("mermaid.initialize"))
    }
    
    func testParserConvenienceMethodsWithThemes() async throws {
        let markdown = """
        ```mermaid
        graph TD
            A --> B
        ```
        """
        
        // Test dark theme convenience method
        let darkHTML = try await parser.parseToHTMLWithDarkTheme(markdown)
        XCTAssertTrue(darkHTML.contains("theme: 'dark'"))
        
        // Test forest theme convenience method  
        let forestHTML = try await parser.parseToHTMLWithForestTheme(markdown)
        XCTAssertTrue(forestHTML.contains("theme: 'forest'"))
        
        // Test neutral theme convenience method
        let neutralHTML = try await parser.parseToHTMLWithNeutralTheme(markdown)
        XCTAssertTrue(neutralHTML.contains("theme: 'neutral'"))
        
        // Test base theme convenience method
        let baseHTML = try await parser.parseToHTMLWithBaseTheme(markdown)
        XCTAssertTrue(baseHTML.contains("theme: 'base'"))
    }
    
    // MARK: - HTML Output Verification Tests
    
    func testActualHTMLOutputContainsThemeSettings() async throws {
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
            XCTAssertTrue(html.contains(expectedTheme), "HTML should contain \(expectedTheme) for theme \(theme)")
            
            // Verify it contains Mermaid initialization
            XCTAssertTrue(html.contains("mermaid.initialize"), "HTML should contain Mermaid initialization")
            
            // Verify it contains the diagram content
            XCTAssertTrue(html.contains("A[Start] --> B[Process] --> C[End]"), "HTML should contain diagram content")
            
            // Verify it contains proper HTML structure
            XCTAssertTrue(html.contains("<h1>Theme Verification Test</h1>"), "HTML should contain heading")
            XCTAssertTrue(html.contains("class=\"mermaid\""), "HTML should contain Mermaid class")
        }
    }
    
    func testCustomConfigurationGeneratesCorrectHTML() async throws {
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
        XCTAssertTrue(html.contains("theme: 'dark'"))
        XCTAssertTrue(html.contains("cdn.jsdelivr.net/npm/mermaid@10.6.1"))
        XCTAssertTrue(html.contains("securityLevel: 'loose'"))
        XCTAssertTrue(html.contains("fontFamily: 'Arial, sans-serif'"))
        XCTAssertTrue(html.contains("fontSize: 20"))
        XCTAssertTrue(html.contains("maxTextSize: 60000"))
        XCTAssertTrue(html.contains("useMaxWidth: false"))
        XCTAssertTrue(html.contains("logLevel: 3"))
        
        // Verify flowchart configuration
        XCTAssertTrue(html.contains("curve: 'linear'"))
        XCTAssertTrue(html.contains("padding: 20"))
        XCTAssertTrue(html.contains("nodeSpacing: 80"))
        XCTAssertTrue(html.contains("rankSpacing: 100"))
        
        // Verify sequence configuration
        XCTAssertTrue(html.contains("showSequenceNumbers: true"))
        XCTAssertTrue(html.contains("actorMargin: 80"))
        XCTAssertTrue(html.contains("noteMargin: 15"))
        XCTAssertTrue(html.contains("messageMargin: 40"))
        XCTAssertTrue(html.contains("mirrorActors: false"))
    }
    
    func testRenderModeVariationsGenerateCorrectHTML() async throws {
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
        XCTAssertTrue(embeddedHTML.contains("Mermaid.js Embedded Loader"))
        // Note: Embedded mode includes CDN fallback, so we check for the embedded loader marker instead
        
        // Test CDN mode
        let cdnConfig = MermaidConfiguration(renderMode: .cdn(version: "9.4.3"))
        let cdnContext = RenderContext(mermaidConfiguration: cdnConfig)
        let cdnHTML = try await parser.parseToHTML(markdown, context: cdnContext)
        
        // Should contain specific CDN link and not embedded loader
        XCTAssertTrue(cdnHTML.contains("cdn.jsdelivr.net/npm/mermaid@9.4.3"))
        XCTAssertFalse(cdnHTML.contains("Mermaid.js Embedded Loader"))
        
        // Test custom mode
        let customConfig = MermaidConfiguration(renderMode: .custom(url: "https://example.com/custom-mermaid.js"))
        let customContext = RenderContext(mermaidConfiguration: customConfig)
        let customHTML = try await parser.parseToHTML(markdown, context: customContext)
        
        // Should contain custom URL and not embedded loader or standard CDN links
        XCTAssertTrue(customHTML.contains("https://example.com/custom-mermaid.js"))
        XCTAssertFalse(customHTML.contains("Mermaid.js Embedded Loader"))
        XCTAssertFalse(customHTML.contains("cdn.jsdelivr.net/npm/mermaid@9.4.3"))  // Should not contain the specific CDN version from other test
    }
    
    func testDisabledMermaidProducesCodeBlock() async throws {
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
        XCTAssertTrue(html.contains("<code class=\"language-mermaid\">"))
        XCTAssertTrue(html.contains("graph TD"))
        
        // Should not contain Mermaid-specific elements
        XCTAssertFalse(html.contains("mermaid-container"))
        XCTAssertFalse(html.contains("class=\"mermaid\""))
        XCTAssertFalse(html.contains("mermaid.initialize"))
        XCTAssertFalse(html.contains("DOMContentLoaded"))
    }
}