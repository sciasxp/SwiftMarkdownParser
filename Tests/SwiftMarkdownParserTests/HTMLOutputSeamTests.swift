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
        #expect(head.contains("pele@1.13.0/dist/pele.global.js"))
        #expect(body.contains("pele.mount(container, source, options)"))
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

    @Test("Emits the configured palette as --pele-* custom properties")
    func peleThemeVariables() async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let theme = MermaidConfiguration.Theme(
            background: "#010203",
            foreground: "#111111",
            foregroundOnDark: "#fafafa",
            foregroundOnLight: "#0a0a0a",
            line: "#445566",
            border: "#778899",
            surface: "#112233",
            surfaceAlternate: "#223344",
            muted: "#334455",
            accent: "#0a84ff",
            critical: "#ff453a",
            error: "#ff9f0a",
            series: (1...14).map { String(format: "#%06x", $0 * 1000) }
        )
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(
                theme: theme,
                fontFamily: "\"Avenir Next\", sans-serif"
            )
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        for (name, value) in [
            ("--pele-bg", "#010203"), ("--pele-fg", "#111111"), ("--pele-fg-on-dark", "#fafafa"),
            ("--pele-fg-on-light", "#0a0a0a"), ("--pele-line", "#445566"), ("--pele-border", "#778899"),
            ("--pele-surface", "#112233"), ("--pele-surface-alt", "#223344"), ("--pele-muted", "#334455"),
            ("--pele-accent", "#0a84ff"), ("--pele-critical", "#ff453a"), ("--pele-error", "#ff9f0a")
        ] {
            #expect(html.contains("\(name): \(value);"), "\(name)")
        }
        #expect(html.contains("--pele-series-1: #0003e8;"))
        #expect(html.contains("--pele-series-12: #002ee0;"))
        #expect(!html.contains("--pele-series-13"))
        #expect(html.contains("--pele-font: \\\"Avenir Next\\\", sans-serif;"))
        #expect(html.contains("\"fontFamily\":\"\\\"Avenir Next\\\", sans-serif\""))
        #expect(html.contains("class=\"mermaid\""))
    }

    @Test("Emits no custom properties for the default theme")
    func defaultThemeEmitsNoVariables() async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")

        let html = try await HTMLRenderer().renderDocument(document)

        #expect(!html.contains("--pele-bg"))
        #expect(!html.contains("--pele-font:"))
    }

    @Test("Ignores palette values that could escape a CSS declaration")
    func unsafeThemeValuesAreIgnored() async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let theme = MermaidConfiguration.Theme(
            background: "red; } body { display: none",
            foreground: "#abcdef",
            line: "</style><script>alert(1)</script>"
        )
        let options = HTMLRenderOptions(mermaidConfiguration: MermaidConfiguration(theme: theme))

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(html.contains("--pele-fg: #abcdef;"))
        #expect(!html.contains("--pele-bg"))
        #expect(!html.contains("--pele-line"))
        #expect(!html.contains("display: none"))
    }

    @Test("Maps zoom, size and limit to Pele mount options")
    func peleMountOptions() async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")

        for (zoom, expected) in [
            (MermaidConfiguration.Zoom.auto, "\"zoom\":\"auto\""),
            (.always, "\"zoom\":true"),
            (.disabled, "\"zoom\":false")
        ] {
            let options = HTMLRenderOptions(
                mermaidConfiguration: MermaidConfiguration(fontSize: 14, maxTextSize: 1234, zoom: zoom)
            )
            let html = try await HTMLRenderer(options: options).renderDocument(document)

            #expect(html.contains(expected))
            #expect(html.contains("\"fontSize\":14"))
            #expect(html.contains("\"limit\":1234"))
        }
    }

    @Test("Shows a localized message and the source when Pele rejects a diagram")
    func diagramErrorContract() async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(
                messages: .init(diagramFailed: "Não foi possível desenhar o diagrama.")
            )
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        #expect(html.contains("\"diagramFailed\":\"Não foi possível desenhar o diagrama.\""))
        #expect(html.contains("onError: function() { showDiagramError(container, source); }"))
        // The message and the source are written as text, never as markup, and Pele's own text is not used.
        #expect(html.contains("message.textContent = peleConfiguration.messages.diagramFailed"))
        #expect(html.contains("code.textContent = source"))
        #expect(!html.contains("onError: function(error)"))
    }

    @Test("Localizes the diagram error message from the package catalog")
    func diagramErrorMessageLocalization() {
        let english = MermaidConfiguration.Messages.localized(locale: Locale(identifier: "en")).diagramFailed
        let portuguese = MermaidConfiguration.Messages.localized(locale: Locale(identifier: "pt-BR")).diagramFailed

        #expect(english == "This diagram could not be rendered. Its source is shown below.")
        #expect(portuguese == "Não foi possível desenhar este diagrama. O código-fonte aparece abaixo.")
    }

    @Test("Reports the mermaid feature as failed when the Pele runtime is missing")
    func missingRuntimeFallsBack() async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")

        let html = try await HTMLRenderer().renderDocument(document)

        #expect(html.contains("if (typeof pele === 'undefined' || typeof pele.mount !== 'function')"))
        #expect(html.contains("throw new Error('Pele runtime unavailable')"))
        #expect(html.contains("if (asset === 'pele') { return ['mermaid']; }"))
        #expect(html.contains("onerror=\"window.__swiftMarkdownAssetFailed('pele')\""))
        #expect(html.contains("activeFeature = requiredFeatures.includes('mermaid') ? 'mermaid' : null"))
        // The source stays in the document as text until the runtime replaces it.
        #expect(html.contains("<pre class=\"mermaid\""))
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
        #expect(!html.contains("pele.mount"))
        #expect(!html.contains("pele.global.js"))
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

        #expect(html.occurrences(of: "pele@1.13.0/dist/pele.global.js") == 1)
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
        #expect(html.contains("var pele=(()=>"))
        #expect(html.contains("pele.mount(container, source, options)"))
        #expect(!html.contains("mermaid.min.js"))
        #expect(!html.contains("mermaid.initialize"))
        #expect(!html.contains("mermaid.run"))
        #expect(!html.contains("mermaid.init("))
        #expect(html.occurrences(of: "var pele=(()=>") == 1)
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
                theme: .init(background: attack),
                fontFamily: attack,
                customCSS: attack
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

    @Test("Renders the link text for four slashes against a file base")
    func linkDestination_fourSlashesWithFileBase_rendersLinkText() async throws {
        let document = try SwiftMarkdownParser().parse("[x](////evil.com/share)")
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
