import Foundation
import Testing
@testable import SwiftMarkdownParser

@Suite("HTML output seam")
struct HTMLOutputSeamTests {
    @Test("Renders fragments through one document-level interface")
    func fragment() async throws {
        let document = try SwiftMarkdownParser().parse("# Title\n\nA **deep** module.")

        let html = try await HTMLRenderer().renderFragment(document)

        #expect(html.contains("<h1>Title</h1>"))
        #expect(html.contains("<strong>deep</strong>"))
        #expect(!html.contains("<!DOCTYPE html>"))
    }

    @Test("Places feature resources in head of complete documents")
    func completeDocumentPlacesResources() async throws {
        let markdown = """
        Inline math $x^2$.

        ```mermaid
        graph TD
        A --> B
        ```
        """
        let document = try SwiftMarkdownParser().parse(markdown)

        let html = try await HTMLRenderer().renderDocument(
            document,
            metadata: HTMLDocumentMetadata(title: "Math & Diagrams", language: "pt-BR")
        )

        let headEnd = try #require(html.range(of: "</head>"))
        let bodyStart = try #require(html.range(of: "<body>"))
        let head = html[..<headEnd.lowerBound]
        let body = html[bodyStart.lowerBound...]

        #expect(head.contains("katex.min.css"))
        #expect(head.contains("mermaid.min.js"))
        #expect(body.contains("mermaid.initialize"))
        #expect(!body.contains("<link rel=\"stylesheet\""))
        #expect(html.contains("<html lang=\"pt-BR\">"))
        #expect(html.contains("<title>Math &amp; Diagrams</title>"))
    }

    @Test("Allows a presentation owner to replace default document styles")
    func completeDocumentWithoutDefaultStyles() async throws {
        let document = try SwiftMarkdownParser().parse("# Styled by the host")
        let options = HTMLRenderOptions(includeDefaultStyles: false)

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("<h1>Styled by the host</h1>"))
        #expect(!html.contains("/* Base styling */"))
    }

    @Test(
        "Owns Mermaid theme generation",
        arguments: [
            (MermaidConfiguration.Theme.dark, "\"theme\":\"dark\""),
            (.forest, "\"theme\":\"forest\""),
            (.neutral, "\"theme\":\"neutral\""),
            (.base, "\"theme\":\"base\""),
        ]
    )
    func mermaidThemes(theme: MermaidConfiguration.Theme, expected: String) async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(theme: theme)
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(html.contains(expected))
        #expect(html.contains("class=\"mermaid\""))
    }

    @Test("Encodes typed Mermaid theme variables as configuration data")
    func mermaidThemeVariables() async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let variables = MermaidConfiguration.ThemeVariables(
            primaryColor: "#112233",
            lineColor: "#445566",
            darkMode: true
        )
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(
                theme: .base,
                themeVariables: variables
            )
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(html.contains("\"theme\":\"base\""))
        #expect(html.contains("\"themeVariables\":{\"darkMode\":true"))
        #expect(html.contains("\"lineColor\":\"#445566\""))
        #expect(html.contains("\"primaryColor\":\"#112233\""))
    }

    @Test("Uses configured KaTeX assets")
    func customKaTeXAssets() async throws {
        let document = try SwiftMarkdownParser().parse("$x + y$")
        let baseURL = try #require(URL(string: "https://assets.example/katex"))
        let configuration = KaTeXConfiguration(
            assetSource: .custom(baseURL: baseURL)
        )
        let options = HTMLRenderOptions(katexConfiguration: configuration)

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(html.contains("https://assets.example/katex/katex.min.css"))
        #expect(html.contains("https://assets.example/katex/katex.min.js"))
    }

    @Test("Omits disabled feature resources and keeps safe fallbacks")
    func disabledFeatures() async throws {
        let document = try SwiftMarkdownParser().parse("$x$\n\n```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(enabled: false),
            katexConfiguration: KaTeXConfiguration(enabled: false)
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(!html.contains("katex.min.js"))
        #expect(!html.contains("mermaid.initialize"))
        #expect(html.contains("<code class=\"language-mermaid\">"))
    }

    @Test("Rejects unsupported custom nodes atomically")
    func unsupportedNode() async {
        let document = AST.DocumentNode(children: [UnsupportedTestNode()])

        await #expect(throws: HTMLRenderingError.self) {
            try await HTMLRenderer().renderFragment(document)
        }
    }

    @Test("Includes each required runtime exactly once")
    func deduplicatesRuntimeAssets() async throws {
        let markdown = """
        $a$ and $b$.

        ```mermaid
        graph TD
        A --> B
        ```

        ```mermaid
        graph TD
        C --> D
        ```
        """
        let document = try SwiftMarkdownParser().parse(markdown)

        let html = try await HTMLRenderer().renderDocument(document)

        #expect(html.occurrences(of: "mermaid@10.9.1/dist/mermaid.min.js") == 1)
        #expect(html.occurrences(of: "katex@0.16.21/dist/katex.min.js") == 1)
        #expect(html.occurrences(of: "const requiredFeatures = [\"katex\",\"mermaid\"]") == 1)
        #expect(html.contains("version: 1"))
        #expect(html.contains("requiredFeatures: requiredFeatures"))
        #expect(html.contains("failedFeatures:"))
        #expect(html.contains("if (didReport) { return; }"))
        #expect(html.contains("activeFeature = requiredFeatures.includes('mermaid') ? 'mermaid' : null"))
    }

    @Test("Produces a self-contained document with bundled runtimes")
    func bundledAssets() async throws {
        let document = try SwiftMarkdownParser().parse("$x^2$\n\n```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(assetSource: .bundled),
            katexConfiguration: KaTeXConfiguration(assetSource: .bundled)
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(!html.contains("cdn.jsdelivr.net"))
        #expect(html.contains("data:font/woff2;base64,"))
        #expect(html.contains("mermaid.initialize(mermaidConfiguration)"))
        #expect(html.contains("katex.render(element.textContent"))
    }

    @Test("Caches successful bundled fragments and retries failed construction")
    func bundledAssetCache() {
        let cache = BundledBrowserAssetCache()
        var successfulLoads = 0

        let first = cache.value(for: "success") {
            successfulLoads += 1
            return "fragment"
        }
        let second = cache.value(for: "success") {
            successfulLoads += 1
            return "different"
        }

        #expect(first == "fragment")
        #expect(second == "fragment")
        #expect(successfulLoads == 1)

        var failedLoads = 0
        #expect(throws: AssetCacheFixtureError.failed) {
            try cache.value(for: "failure") {
                failedLoads += 1
                throw AssetCacheFixtureError.failed
            }
        }
        let recovered = cache.value(for: "failure") {
            failedLoads += 1
            return "recovered"
        }

        #expect(recovered == "recovered")
        #expect(failedLoads == 2)
    }

    @Test("Rejects unsafe custom runtime URLs")
    func rejectsUnsafeAssetURL() async throws {
        let document = try SwiftMarkdownParser().parse("$x$")
        let url = try #require(URL(string: "javascript:alert(1)"))
        let options = HTMLRenderOptions(
            katexConfiguration: KaTeXConfiguration(assetSource: .custom(baseURL: url))
        )

        await #expect(throws: HTMLRenderingError.self) {
            try await HTMLRenderer(options: options).renderDocument(document)
        }
    }

    @Test("Encodes configuration without creating executable markup")
    func safelyEncodesConfiguration() async throws {
        let attack = "</script><script>alert('configuration')</script>"
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(
                fontFamily: attack,
                customCSS: attack,
                themeVariables: .init(primaryColor: attack)
            )
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(!html.contains(attack))
        #expect(html.contains("\\u003C\\/script\\u003E\\u003Cscript\\u003E"))
    }

    @Test("Surfaces unavailable bundled assets through the document interface")
    func unavailableBundledAsset() async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(assetSource: .bundled)
        )
        let renderer = HTMLRenderer(
            options: options,
            assetLoader: MissingBrowserAssetLoader()
        )

        await #expect(throws: HTMLRenderingError.self) {
            try await renderer.renderDocument(document)
        }
    }

    @Test("Does not emit a script href when a tab splits the scheme of a reference definition")
    func referenceDestination_tabInsideScheme_rendersLinkText() async throws {
        let document = try SwiftMarkdownParser().parse("[click]\n\n[click]: <java\tscript:alert(1)>")

        let html = try await HTMLRenderer().renderFragment(document)

        #expect(!html.contains("href"))
        #expect(html.contains("click"))
    }

    @Test(
        "Renders the fallback for destinations outside the allowlist, even when split by controls",
        arguments: [
            "java\tscript:alert(1)",
            "java\nscript:alert(1)",
            "java\rscript:alert(1)",
            " \tjavascript:alert(1)",
            "\u{01}javascript:alert(1)",
            "vbscript:msgbox(1)",
            "file:///etc/passwd"
        ]
    )
    func destination_controlCharactersInsideScheme_rendersFallback(destination: String) async throws {
        let document = AST.DocumentNode(children: [
            AST.ParagraphNode(children: [
                AST.LinkNode(url: destination, title: nil, children: [AST.TextNode(content: "link")]),
                AST.ImageNode(url: destination, altText: "image", title: nil),
                AST.AutolinkNode(url: destination, text: "autolink")
            ])
        ])

        let html = try await HTMLRenderer().renderFragment(document)

        #expect(!html.contains("href"))
        #expect(!html.contains("src"))
        #expect(html.contains("link"))
        #expect(html.contains("image"))
        #expect(html.contains("autolink"))
    }

    @Test(
        "Renders the fallback when a combining or joiner character follows a reference's scheme colon",
        arguments: markAfterSchemeColonDestinations, destinationBaseURLs
    )
    func referenceDestination_markAfterSchemeColon_rendersFallback(destination: String, baseURL: URL) async throws {
        let document = try SwiftMarkdownParser().parse("[link] ![image][link]\n\n[link]: <\(destination)>")
        let nodes = document.depthFirst().map(\.node)
        try #require(nodes.contains { $0 is AST.LinkNode })
        try #require(nodes.contains { $0 is AST.ImageNode })

        let html = try await HTMLRenderer(options: HTMLRenderOptions(baseURL: baseURL)).renderFragment(document)

        #expect(!html.contains("href"))
        #expect(!html.contains("src"))
        #expect(html.contains("link"))
        #expect(html.contains("image"))
    }

    @Test(
        "Renders the autolink text when a combining or joiner character follows its scheme colon",
        arguments: markAfterSchemeColonDestinations, destinationBaseURLs
    )
    func autolinkDestination_markAfterSchemeColon_rendersText(destination: String, baseURL: URL) async throws {
        let document = AST.DocumentNode(children: [
            AST.ParagraphNode(children: [AST.AutolinkNode(url: destination, text: "autolink")])
        ])

        let html = try await HTMLRenderer(options: HTMLRenderOptions(baseURL: baseURL)).renderFragment(document)

        #expect(!html.contains("href"))
        #expect(html.contains("autolink"))
    }

    @Test("Links an empty destination to the document itself, as CommonMark does")
    func linkDestination_empty_rendersEmptyHref() async throws {
        let document = try SwiftMarkdownParser().parse("[x]()")

        let html = try await HTMLRenderer().renderFragment(document)

        #expect(html.contains(#"href="""#))
    }

    @Test("Resolves an empty destination against the base URL as an empty relative reference")
    func linkDestination_emptyWithBase_rendersBaseHref() async throws {
        let document = try SwiftMarkdownParser().parse("[x]()")
        let options = HTMLRenderOptions(baseURL: URL(string: "https://example.com/docs/guide.html#top"))

        let html = try await HTMLRenderer(options: options).renderFragment(document)

        #expect(html.contains(#"href="https://example.com/docs/guide.html""#))
    }

    @Test("Renders the link text for a protocol-relative reference that would name a file host")
    func linkDestination_protocolRelativeWithFileBase_rendersLinkText() async throws {
        let document = try SwiftMarkdownParser().parse("[x](//evil.com/share)")
        let options = HTMLRenderOptions(baseURL: URL(fileURLWithPath: "/docs/", isDirectory: true))

        let html = try await HTMLRenderer(options: options).renderFragment(document)

        #expect(!html.contains("href"))
        #expect(html.contains("x"))
    }

    @Test("Renders the alt text for a protocol-relative image without a base URL")
    func imageDestination_protocolRelativeWithoutBase_rendersAltText() async throws {
        let document = try SwiftMarkdownParser().parse("![x](//evil.com/a.png)")

        let html = try await HTMLRenderer().renderFragment(document)

        #expect(!html.contains("src"))
        #expect(!html.contains("evil.com"))
        #expect(html.contains("x"))
    }

    @Test(
        "Renders the fallback for protocol-relative destinations without a base URL",
        arguments: protocolRelativeDestinations
    )
    func destination_protocolRelativeWithoutBase_rendersFallback(destination: String) async throws {
        let document = AST.DocumentNode(children: [
            AST.ParagraphNode(children: [
                AST.LinkNode(url: destination, title: nil, children: [AST.TextNode(content: "link")]),
                AST.ImageNode(url: destination, altText: "image", title: nil),
                AST.AutolinkNode(url: destination, text: "autolink")
            ])
        ])

        let html = try await HTMLRenderer().renderFragment(document)

        #expect(!html.contains("href"))
        #expect(!html.contains("src"))
        #expect(html.contains("link"))
        #expect(html.contains("image"))
        #expect(html.contains("autolink"))
    }

    @Test("Renders the link text for a protocol-relative reference with only a port against a file base")
    func linkDestination_portOnlyWithFileBase_rendersLinkText() async throws {
        let document = try SwiftMarkdownParser().parse("[x](//:80/x)")
        let options = HTMLRenderOptions(baseURL: URL(fileURLWithPath: "/docs/", isDirectory: true))

        let html = try await HTMLRenderer(options: options).renderFragment(document)

        #expect(!html.contains("href"))
        #expect(html.contains("x"))
    }

    @Test("Resolves a protocol-relative image against a web base URL")
    func imageDestination_protocolRelativeWithWebBase_takesBaseScheme() async throws {
        let document = try SwiftMarkdownParser().parse("![x](//cdn.example/a.png)")
        let options = HTMLRenderOptions(baseURL: URL(string: "https://example.com/docs/"))

        let html = try await HTMLRenderer(options: options).renderFragment(document)

        #expect(html.contains(#"src="https://cdn.example/a.png""#))
    }
}

private let markAfterSchemeColonDestinations = [
    "javascript:\u{301}alert(1)",
    "data:\u{200D}text/html,x",
    "file:\u{301}///etc/passwd"
]

private let destinationBaseURLs = [
    URL(string: "https://example.com/docs/guide.html")!,
    URL(fileURLWithPath: "/Users/reader/docs/", isDirectory: true)
]

private struct MissingBrowserAssetLoader: BrowserAssetLoading {
    func data(named name: String) throws -> Data {
        throw HTMLRenderingError.bundledAssetUnavailable(name)
    }
}

private enum AssetCacheFixtureError: Error {
    case failed
}

private extension String {
    func occurrences(of value: String) -> Int {
        components(separatedBy: value).count - 1
    }
}
