import Testing
@testable import SwiftMarkdownParser

/// Tests for KaTeX math rendering functionality
@Suite struct KaTeXRendererTests {

    let parser: SwiftMarkdownParser

    init() {
        parser = SwiftMarkdownParser()
    }

    // MARK: - Configuration Tests

    @Test func defaultConfiguration_hasExpectedDefaults() async throws {
        let config = KaTeXConfiguration.default
        #expect(config.enabled)
        #expect(!config.throwOnError)
        #expect(config.errorColor == "#cc0000")
        #expect(!config.displayMode)
        #expect(config.minRuleThickness == nil)
        #expect(config.customCSS == nil)
    }

    @Test func disabledConfiguration_omitsScripts() async throws {
        let config = KaTeXConfiguration(enabled: false)
        let renderer = KaTeXRenderer(configuration: config)
        let headContent = renderer.generateKaTeXHeadContent()
        #expect(headContent.isEmpty)
    }

    @Test func customCDNVersion_usesCorrectURL() async throws {
        let config = KaTeXConfiguration(renderMode: .cdn(version: "0.16.10"))
        let stylesheet = config.generateStylesheetLink()
        let script = config.generateScriptTags()

        #expect(stylesheet.contains("katex@0.16.10"))
        #expect(stylesheet.contains("katex.min.css"))
        #expect(script.contains("katex@0.16.10"))
        #expect(script.contains("katex.min.js"))
    }

    @Test func customURL_usesProvidedURL() async throws {
        let config = KaTeXConfiguration(renderMode: .custom(url: "https://example.com/katex"))
        let stylesheet = config.generateStylesheetLink()
        let script = config.generateScriptTags()

        #expect(stylesheet.contains("https://example.com/katex/katex.min.css"))
        #expect(script.contains("https://example.com/katex/katex.min.js"))
    }

    // MARK: - HTML Rendering Tests

    @Test func renderBlockMath_containsKaTeXScripts() async throws {
        let markdown = """
        $$
        E = mc^2
        $$
        """

        let html = try await parser.parseToHTMLWithMath(markdown)

        // Should contain KaTeX CSS
        #expect(html.contains("katex.min.css"), "Should include KaTeX stylesheet")
        // Should contain KaTeX JS
        #expect(html.contains("katex.min.js"), "Should include KaTeX script")
        // Should contain init script
        #expect(html.contains("katex.render"), "Should include init script")
        // Should contain the math element
        #expect(html.contains("class=\"math math-display\""), "Should contain display math element")
    }

    @Test func renderInlineMath_containsKaTeXScripts() async throws {
        let markdown = "The equation $E=mc^2$ is famous."

        let html = try await parser.parseToHTMLWithMath(markdown)

        // Should contain KaTeX CSS and JS
        #expect(html.contains("katex.min.css"), "Should include KaTeX stylesheet")
        #expect(html.contains("katex.min.js"), "Should include KaTeX script")
        // Should contain the math element
        #expect(html.contains("class=\"math math-inline\""), "Should contain inline math element")
    }

    @Test func renderMath_escapesHTMLEntities() async throws {
        let markdown = "The expression $a < b & c > d$ is valid."

        let html = try await parser.parseToHTMLWithMath(markdown)

        #expect(html.contains("&lt;"), "Should escape < to &lt;")
        #expect(html.contains("&amp;"), "Should escape & to &amp;")
        #expect(html.contains("&gt;"), "Should escape > to &gt;")
    }

    @Test func renderNoMath_noKaTeXScripts() async throws {
        let markdown = "Just a regular paragraph with **bold** text."

        let html = try await parser.parseToHTML(markdown)

        #expect(!html.contains("katex.min.css"), "Should not include KaTeX stylesheet")
        #expect(!html.contains("katex.min.js"), "Should not include KaTeX script")
    }

    @Test func renderDisabledKaTeX_noScripts() async throws {
        let markdown = "$E=mc^2$"

        let config = KaTeXConfiguration(enabled: false)
        let context = RenderContext(katexConfiguration: config)
        let html = try await parser.parseToHTML(markdown, context: context)

        // Semantic math elements should still be present
        #expect(html.contains("class=\"math math-inline\""), "Should still have semantic math element")
        // But no KaTeX scripts
        #expect(!html.contains("katex.min.css"), "Should not include KaTeX stylesheet when disabled")
        #expect(!html.contains("katex.min.js"), "Should not include KaTeX script when disabled")
    }

    // MARK: - Integration Tests

    @Test func mathWithMermaid_bothScriptsPresent() async throws {
        let markdown = """
        Some math: $E=mc^2$

        ```mermaid
        graph TD
            A --> B
        ```
        """

        let context = RenderContext(
            mermaidConfiguration: .default,
            katexConfiguration: .default
        )
        let html = try await parser.parseToHTML(markdown, context: context)

        // Both KaTeX and Mermaid should be present
        #expect(html.contains("katex.min.css"), "Should include KaTeX stylesheet")
        #expect(html.contains("katex.min.js"), "Should include KaTeX script")
        #expect(html.contains("mermaid"), "Should include Mermaid content")
    }

    @Test func multipleMathExpressions_singleScriptInjection() async throws {
        let markdown = """
        Inline: $a + b$

        Block:
        $$
        \\int_0^1 f(x)dx
        $$

        More inline: $x^2$
        """

        let html = try await parser.parseToHTMLWithMath(markdown)

        // Count occurrences of KaTeX script tag — should be exactly 1
        let scriptCount = html.components(separatedBy: "katex.min.js").count - 1
        #expect(scriptCount == 1, "Should inject KaTeX script tags only once")

        // Count occurrences of KaTeX CSS — should be exactly 1
        let cssCount = html.components(separatedBy: "katex.min.css").count - 1
        #expect(cssCount == 1, "Should inject KaTeX stylesheet only once")
    }

    // MARK: - Init Script Tests

    @Test func initScript_targetsCorrectClasses() async throws {
        let config = KaTeXConfiguration.default
        let script = config.generateInitScript()

        #expect(script.contains(".math"), "Should target .math elements")
        #expect(script.contains("math-display"), "Should detect math-display class")
    }

    @Test func initScript_respectsThrowOnError() async throws {
        let config = KaTeXConfiguration(throwOnError: true)
        let script = config.generateInitScript()

        #expect(script.contains("throwOnError: true"), "Should set throwOnError to true")

        let defaultConfig = KaTeXConfiguration.default
        let defaultScript = defaultConfig.generateInitScript()

        #expect(defaultScript.contains("throwOnError: false"), "Default should set throwOnError to false")
    }

    // MARK: - KaTeXRenderer Direct Tests

    @Test func renderMathBlock_outputsCorrectHTML() async throws {
        let node = AST.MathBlockNode(content: "E = mc^2")
        let renderer = KaTeXRenderer()
        let html = renderer.renderMathBlock(node)

        #expect(html == "<div class=\"math math-display\">E = mc^2</div>\n")
    }

    @Test func renderInlineMath_outputsCorrectHTML() async throws {
        let node = AST.InlineMathNode(content: "x^2")
        let renderer = KaTeXRenderer()
        let html = renderer.renderInlineMath(node)

        #expect(html == "<span class=\"math math-inline\">x^2</span>")
    }

    @Test func standaloneHTML_includesKaTeXHead() async throws {
        let renderer = KaTeXRenderer()
        let html = renderer.generateStandaloneHTML(content: "<p>Test</p>", title: "Test")

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("katex.min.css"))
        #expect(html.contains("katex.min.js"))
        #expect(html.contains("<title>Test</title>"))
        #expect(html.contains("<p>Test</p>"))
    }

    @Test func headContent_includesAllParts() async throws {
        let renderer = KaTeXRenderer()
        let head = renderer.generateKaTeXHeadContent()

        // Should have CSS link, JS script, and init script
        #expect(head.contains("<link rel=\"stylesheet\""), "Should include stylesheet link")
        #expect(head.contains("<script defer src="), "Should include deferred script tag")
        #expect(head.contains("katex.render"), "Should include render init script")
    }

    @Test func parseToHTMLWithMath_convenienceMethod() async throws {
        let markdown = "$x^2$"
        let html = try await parser.parseToHTMLWithMath(markdown)

        #expect(html.contains("katex.min.css"))
        #expect(html.contains("class=\"math math-inline\""))
    }

    @Test func parseToHTMLWithMath_customConfig() async throws {
        let markdown = "$x^2$"
        let config = KaTeXConfiguration(throwOnError: true, errorColor: "#ff0000")
        let html = try await parser.parseToHTMLWithMath(markdown, katexConfiguration: config)

        #expect(html.contains("throwOnError: true"))
        #expect(html.contains("#ff0000"))
    }
}
