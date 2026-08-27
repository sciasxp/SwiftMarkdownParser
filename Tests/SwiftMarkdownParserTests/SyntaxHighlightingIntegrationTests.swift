import Foundation
import Testing
@testable import SwiftMarkdownParser

/// Integration tests for syntax highlighting with HTML renderer
/// These tests verify that syntax highlighting works correctly end-to-end
/// with the HTML renderer and produces expected output.
@Suite struct SyntaxHighlightingIntegrationTests {

    private let parser: SwiftMarkdownParser
    private let renderer: HTMLRenderer

    init() async throws {
        parser = SwiftMarkdownParser()

        let context = HTMLRenderOptions(
            styleConfiguration: HTMLStyleConfiguration(
                syntaxHighlighting: HTMLSyntaxHighlightingOptions(
                    enabled: true,
                    cssPrefix: "hljs-"
                )
            )
        )
        renderer = HTMLRenderer(options: context)
    }

    @Test(
        "Highlights representative built-in language tokens",
        arguments: [
            ("javascript", "const message = 1;", "hljs-keyword"),
            ("javascript", "const message = \"Hello\";", "hljs-string"),
            ("swift", "func greet() {}", "hljs-keyword"),
            ("typescript", "interface User { name: string }", "hljs-type"),
        ]
    )
    func htmlRenderer_highlightsBuiltInLanguage(
        language: String,
        source: String,
        expectedClass: String
    ) async throws {
        let markdown = "```\(language)\n\(source)\n```"
        let document = try parser.parse(markdown)

        let html = try await renderer.renderFragment(document)

        #expect(html.contains("class=\"\(expectedClass)\""))
    }

    // MARK: - End-to-End Integration Tests

    @Test func htmlRenderer_includesSyntaxHighlightingClasses() async throws {
        let markdown = """
        # Code Example

        ```swift
        func greet(name: String) -> String {
            return "Hello, \\(name)!"
        }
        ```
        """

        let ast = try parser.parse(markdown)
        let html = try await renderer.renderFragment(ast)

        // Verify HTML contains syntax highlighting classes
        #expect(html.contains("class=\"hljs-keyword\""), "Should contain keyword highlighting")
        #expect(html.contains("class=\"hljs-string\""), "Should contain string highlighting")
        #expect(html.contains("class=\"hljs-type\""), "Should contain type highlighting")
        #expect(html.contains("class=\"hljs-identifier\""), "Should contain identifier highlighting")
        #expect(html.contains("class=\"hljs-punctuation\""), "Should contain punctuation highlighting")
        #expect(html.contains("class=\"hljs-interpolation\""), "Should contain interpolation highlighting")
    }

    @Test func htmlRenderer_handlesMultipleLanguages() async throws {
        let markdown = """
        # Multi-language Example

        ```javascript
        const greet = (name) => `Hello, ${name}!`;
        ```

        ```python
        def greet(name: str) -> str:
            return f"Hello, {name}!"
        ```

        ```kotlin
        fun greet(name: String): String = "Hello, $name!"
        ```
        """

        let ast = try parser.parse(markdown)
        let html = try await renderer.renderFragment(ast)

        // Verify all languages are properly highlighted
        #expect(html.contains("class=\"hljs-keyword\""), "Should highlight keywords")
        #expect(html.contains("class=\"hljs-string\""), "Should highlight strings")
        #expect(html.contains("class=\"hljs-template\""), "Should highlight template literals")
        #expect(html.contains("class=\"hljs-interpolation\""), "Should highlight interpolations")

        // Verify language-specific classes
        #expect(html.contains("language-javascript"), "Should have JavaScript language class")
        #expect(html.contains("language-python"), "Should have Python language class")
        #expect(html.contains("language-kotlin"), "Should have Kotlin language class")
    }

    @Test func htmlRenderer_handlesUnsupportedLanguageGracefully() async throws {
        let markdown = """
        ```unknown
        some code here
        ```
        """

        let ast = try parser.parse(markdown)
        let html = try await renderer.renderFragment(ast)

        // Should still render as code block without highlighting
        #expect(html.contains("<pre><code"), "Should render as code block")
        #expect(!html.contains("class=\"hljs-"), "Should not contain highlighting classes for unknown language")
    }

    @Test func htmlRenderer_preservesCodeBlockStructure() async throws {
        let markdown = """
        ```swift
        // This is a comment
        func test() {
            let message = "Hello"
            print(message)
        }
        ```
        """

        let ast = try parser.parse(markdown)
        let html = try await renderer.renderFragment(ast)

        // Verify structure is preserved
        #expect(html.contains("<pre><code"), "Should wrap in pre/code tags")
        #expect(html.contains("// This is a comment"), "Should preserve comments")
        #expect(html.contains("func") && html.contains("test"), "Should preserve function definition")
        #expect(html.contains("print") && html.contains("message"), "Should preserve function calls")
    }

    @Test func htmlRenderer_escapesHTMLInCode() async throws {
        let markdown = """
        ```html
        <div class="test">
            <script>alert('xss')</script>
        </div>
        ```
        """

        let ast = try parser.parse(markdown)
        let html = try await renderer.renderFragment(ast)

        // Verify HTML is properly escaped
        #expect(html.contains("&lt;div"), "Should escape < as &lt;")
        #expect(html.contains("&lt;script&gt;"), "Should escape script tags")
        #expect(!html.contains("<script>"), "Should not contain unescaped script tags")
    }

    // MARK: - Configuration Tests

    @Test func htmlRenderer_customCSSPrefix() async throws {
        let context = HTMLRenderOptions(
            styleConfiguration: HTMLStyleConfiguration(
                syntaxHighlighting: HTMLSyntaxHighlightingOptions(
                    enabled: true,
                    cssPrefix: "custom-"
                )
            )
        )
        let renderer = HTMLRenderer(options: context)

        let markdown = """
        ```swift
        let message = "Hello"
        ```
        """

        let ast = try parser.parse(markdown)
        let html = try await renderer.renderFragment(ast)

        // Should use custom CSS prefix
        #expect(html.contains("class=\"custom-keyword\""), "Should use custom CSS prefix")
        #expect(!html.contains("class=\"hljs-keyword\""), "Should not use default prefix")
    }

    @Test func htmlRenderer_disablesSyntaxHighlighting() async throws {
        let context = HTMLRenderOptions(
            styleConfiguration: HTMLStyleConfiguration(
                syntaxHighlighting: HTMLSyntaxHighlightingOptions(
                    enabled: false
                )
            )
        )
        let renderer = HTMLRenderer(options: context)

        let markdown = """
        ```javascript
        const test = "no highlighting";
        ```
        """

        let ast = try parser.parse(markdown)
        let html = try await renderer.renderFragment(ast)

        // Should not contain highlighting classes
        #expect(!html.contains("class=\"hljs-keyword\""), "Should not have keyword highlighting")
        #expect(!html.contains("class=\"hljs-string\""), "Should not have string highlighting")
        #expect(html.contains("<pre><code"), "Should still render as code block")
    }

    @Test("Preserves source gaps around semantic tokens")
    func htmlRenderer_preservesSourceGaps() async throws {
        let options = HTMLRenderOptions(
            styleConfiguration: HTMLStyleConfiguration(
                syntaxHighlighting: HTMLSyntaxHighlightingOptions(
                    enabled: true,
                    cssPrefix: "hljs-"
                )
            )
        )
        let highlighter = SyntaxHighlighter(
            engines: [IntegrationSyntaxEngine(outcome: .middleToken)]
        )
        let renderer = HTMLRenderer(
            options: options,
            assetLoader: PackageBrowserAssetLoader(),
            syntaxHighlighter: highlighter
        )
        let document = try parser.parse("""
        ```fixture
        before keyword after
        ```
        """)

        let html = try await renderer.renderFragment(document)

        #expect(html.contains("before <span class=\"hljs-keyword\">keyword</span> after"))
    }

    @Test("Reuses highlighting across repeated code blocks")
    func htmlRenderer_reusesHighlighting() async throws {
        let counter = IntegrationInvocationCounter()
        let highlighter = SyntaxHighlighter(
            engines: [IntegrationSyntaxEngine(outcome: .wholeSource, counter: counter)],
            cacheCapacity: 2
        )
        let options = HTMLRenderOptions(
            styleConfiguration: HTMLStyleConfiguration(
                syntaxHighlighting: HTMLSyntaxHighlightingOptions(enabled: true)
            )
        )
        let renderer = HTMLRenderer(
            options: options,
            assetLoader: PackageBrowserAssetLoader(),
            syntaxHighlighter: highlighter
        )
        let document = try parser.parse("""
        ```fixture
        repeated source
        ```

        ```fixture
        repeated source
        ```
        """)

        _ = try await renderer.renderFragment(document)
        let invocationCount = await counter.value

        #expect(invocationCount == 1)
    }
}

private actor IntegrationInvocationCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private struct IntegrationSyntaxEngine: SyntaxHighlightingEngine {
    enum Outcome: Sendable {
        case middleToken
        case wholeSource
    }

    let outcome: Outcome
    let counter: IntegrationInvocationCounter?

    init(
        outcome: Outcome,
        counter: IntegrationInvocationCounter? = nil
    ) {
        self.outcome = outcome
        self.counter = counter
    }

    func supportedLanguages() -> Set<String> {
        ["fixture"]
    }

    func highlight(_ code: String, language: String) async throws -> [SyntaxToken] {
        await counter?.increment()

        switch outcome {
        case .middleToken:
            guard let range = code.range(of: "keyword") else { return [] }
            return [SyntaxToken(content: "keyword", tokenType: .keyword, range: range)]
        case .wholeSource:
            return [SyntaxToken(
                content: code,
                tokenType: .plain,
                range: code.startIndex..<code.endIndex
            )]
        }
    }
}
