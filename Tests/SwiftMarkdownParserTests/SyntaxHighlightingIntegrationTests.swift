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

    // MARK: - Theme Integration Tests

    // GitHub theme test
    @Test func htmlRenderer_appliesGitHubTheme() async throws {
        let context = HTMLRenderOptions(
            styleConfiguration: HTMLStyleConfiguration(
                syntaxHighlighting: HTMLSyntaxHighlightingOptions(
                    enabled: true,
                    cssPrefix: "hljs-"
                )
            )
        )
        let renderer = HTMLRenderer(options: context)

        let markdown = """
        ```javascript
        const message = "Hello World";
        ```
        """

        let ast = try parser.parse(markdown)
        let html = try await renderer.renderFragment(ast)

        // Verify theme-specific styling
        #expect(html.contains("class=\"hljs-string\""), "Should highlight strings")
        #expect(html.contains("class=\"hljs-keyword\""), "Should highlight keywords")
    }

    // Xcode theme test
    @Test func htmlRenderer_appliesXcodeTheme() async throws {
        let context = HTMLRenderOptions(
            styleConfiguration: HTMLStyleConfiguration(
                syntaxHighlighting: HTMLSyntaxHighlightingOptions(
                    enabled: true,
                    cssPrefix: "hljs-"
                )
            )
        )
        let renderer = HTMLRenderer(options: context)

        let markdown = """
        ```swift
        func test() -> String {
            return "Hello"
        }
        ```
        """

        let ast = try parser.parse(markdown)
        let html = try await renderer.renderFragment(ast)

        // Verify theme is applied
        #expect(html.contains("class=\"hljs-string\""), "Should highlight strings")
        #expect(html.contains("class=\"hljs-keyword\""), "Should highlight keywords")
    }

    // VS Code Dark theme test
    @Test func htmlRenderer_appliesVSCodeDarkTheme() async throws {
        let context = HTMLRenderOptions(
            styleConfiguration: HTMLStyleConfiguration(
                syntaxHighlighting: HTMLSyntaxHighlightingOptions(
                    enabled: true,
                    cssPrefix: "hljs-"
                )
            )
        )
        let renderer = HTMLRenderer(options: context)

        let markdown = """
        ```typescript
        interface User {
            name: string;
            age: number;
        }
        ```
        """

        let ast = try parser.parse(markdown)
        let html = try await renderer.renderFragment(ast)

        // Verify theme-specific styling
        #expect(html.contains("class=\"hljs-keyword\""), "Should highlight keywords")
        #expect(html.contains("class=\"hljs-type\""), "Should highlight types")
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
}
