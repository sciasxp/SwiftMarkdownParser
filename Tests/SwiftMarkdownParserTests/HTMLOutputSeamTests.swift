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
        #expect(body.contains("swift-markdown-runtime"))
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
        let root = try #require(try rootStyleSheet(in: html))

        for (name, value) in [
            ("--pele-bg", "#010203"), ("--pele-fg", "#111111"), ("--pele-fg-on-dark", "#fafafa"),
            ("--pele-fg-on-light", "#0a0a0a"), ("--pele-line", "#445566"), ("--pele-border", "#778899"),
            ("--pele-surface", "#112233"), ("--pele-surface-alt", "#223344"), ("--pele-muted", "#334455"),
            ("--pele-accent", "#0a84ff"), ("--pele-critical", "#ff453a"), ("--pele-error", "#ff9f0a")
        ] {
            #expect(root.contains("\(name): \(value);"), "\(name)")
        }
        #expect(root.contains("--pele-series-1: #0003e8;"))
        #expect(root.contains("--pele-series-12: #002ee0;"))
        #expect(!root.contains("--pele-series-13"))
        #expect(root.contains("--pele-font: \"Avenir Next\", sans-serif;"))
        // Pele reads the computed --pele-font to measure and paint, so the mount options carry no font.
        #expect(!html.contains("\"fontFamily\""))
        #expect(html.contains("class=\"mermaid\""))
    }

    @Test("Emits no custom properties for the default theme")
    func defaultThemeEmitsNoVariables() async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")

        let html = try await HTMLRenderer().renderDocument(document)

        #expect(try rootStyleSheet(in: html) == nil)
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

        let root = try #require(try rootStyleSheet(in: html))
        #expect(root.contains("--pele-fg: #abcdef;"))
        #expect(!root.contains("--pele-bg"))
        #expect(!root.contains("--pele-line"))
        #expect(!root.contains("display: none"))
    }

    @Test(
        "Ignores palette values that fetch a resource, open a comment or leave a string open",
        arguments: [
            "url(https://example.com/p.png)", "URL( 'x' )", "image-set(\"a.png\" 1x)", "-webkit-image-set(x)",
            "red /*", "red */", "@import 'x'", "javascript:alert(1)", "JavaScript:alert(1)",
            "\"x", "'x", "\"red\"", "red; color: blue", "red\\"
        ]
    )
    func unsafeColorValues_areIgnored(value: String) async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let theme = MermaidConfiguration.Theme(background: value, foreground: "#abcdef", line: "#112233")
        let options = HTMLRenderOptions(mermaidConfiguration: MermaidConfiguration(theme: theme))

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        let root = try #require(try rootStyleSheet(in: html))
        #expect(!root.contains("--pele-bg"))
        // The declarations after the rejected one are intact.
        #expect(root.contains("--pele-fg: #abcdef;"))
        #expect(root.contains("--pele-line: #112233;"))
    }

    @Test(
        "Accepts a font family only when its quotes are balanced",
        arguments: [
            ("\"Avenir Next\", sans-serif", true), ("'Helvetica Neue', Arial", true),
            ("\"It's\", serif", true), ("-apple-system, BlinkMacSystemFont, sans-serif", true),
            ("\"Avenir, sans-serif", false), ("'x", false), ("\"a' , serif", false),
            ("url(x)", false), ("\"a\" /* b", false)
        ]
    )
    func fontFamilyQuotes_mustBeBalanced(value: String, accepted: Bool) async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let options = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(
                theme: .init(foreground: "#abcdef"),
                fontFamily: value
            )
        )

        let html = try await HTMLRenderer(options: options).renderDocument(document)

        let root = try #require(try rootStyleSheet(in: html))
        #expect(root.contains("--pele-font: \(value);") == accepted)
        #expect(root.contains("--pele-fg: #abcdef;"))
    }

    @Test("Maps zoom, size, limit and link schemes to Pele mount options")
    func peleMountOptions() async throws {
        let document = try SwiftMarkdownParser().parse("```mermaid\ngraph TD\nA --> B\n```")
        let messages = MermaidConfiguration.Messages(
            diagramFailed: "Falhou", zoomIn: "Aproximar", zoomOut: "Afastar", reset: "Restaurar"
        )
        let labels = "\"labels\":{\"reset\":\"Restaurar\",\"zoomIn\":\"Aproximar\",\"zoomOut\":\"Afastar\"}"

        for (zoom, expected) in [
            (MermaidConfiguration.Zoom.auto, "\"zoom\":{\"always\":false,\(labels)}"),
            (.always, "\"zoom\":{\"always\":true,\(labels)}"),
            (.disabled, "\"zoom\":false")
        ] {
            let options = HTMLRenderOptions(
                mermaidConfiguration: MermaidConfiguration(
                    fontSize: 14, maxTextSize: 1234, zoom: zoom, messages: messages
                )
            )
            let html = try await HTMLRenderer(options: options).renderDocument(document)

            #expect(html.contains(expected), "\(zoom)")
            #expect(html.contains("\"fontSize\":14"))
            #expect(html.contains("\"limit\":1234"))
            #expect(html.contains("\"linkSchemes\":[\"http\",\"https\",\"mailto\"]"))
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

        // How the message and the source are shown is covered in WebKit by PeleDiagramRuntimeTests.
        #expect(html.contains("\"diagramFailed\":\"Não foi possível desenhar o diagrama.\""))
    }

    @Test("Localizes the diagram error message from the package catalog")
    func diagramErrorMessageLocalization() {
        let english = MermaidConfiguration.Messages.localized(locale: Locale(identifier: "en")).diagramFailed
        let portuguese = MermaidConfiguration.Messages.localized(locale: Locale(identifier: "pt-BR")).diagramFailed

        #expect(english == "This diagram could not be rendered. Its source is shown below.")
        #expect(portuguese == "Não foi possível desenhar este diagrama. O código-fonte aparece abaixo.")
    }

    @Test("Localizes the zoom labels from the package catalog")
    func zoomLabelLocalization() {
        let english = MermaidConfiguration.Messages.localized(locale: Locale(identifier: "en"))
        let portuguese = MermaidConfiguration.Messages.localized(locale: Locale(identifier: "pt-BR"))

        #expect([english.zoomIn, english.zoomOut, english.reset] == ["Zoom in", "Zoom out", "Reset zoom"])
        #expect(
            [portuguese.zoomIn, portuguese.zoomOut, portuguese.reset]
                == ["Aumentar zoom", "Diminuir zoom", "Redefinir zoom"]
        )
        let explicit = MermaidConfiguration.Messages(diagramFailed: "x")
        #expect(!explicit.zoomIn.isEmpty && !explicit.zoomOut.isEmpty && !explicit.reset.isEmpty)
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
        #expect(html.contains("pele.mount("))
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

/// The CSS strings the bootstrap appends to `<head>` (`customStyles`), decoded from the document.
private func configuredStyleSheets(in html: String) throws -> [String] {
    let marker = "const customStyles = "
    let start = try #require(html.range(of: marker)).upperBound
    let end = try #require(html.range(of: ";\n", range: start..<html.endIndex)).lowerBound
    let json = Data(html[start..<end].utf8)
    return try #require(try JSONSerialization.jsonObject(with: json) as? [String])
}

/// The `:root` rule that declares the `--pele-*` variables, or `nil` when none is emitted.
private func rootStyleSheet(in html: String) throws -> String? {
    try configuredStyleSheets(in: html).first { $0.hasPrefix(":root") }
}
