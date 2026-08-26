import Foundation

/// Browser behaviors discovered while rendering a document body.
enum BrowserFeature: String, Hashable, Sendable {
    case mermaid
    case katex
    case footnotes
    case taskLists
}

struct BrowserRequirements: Sendable {
    private(set) var features: Set<BrowserFeature> = []

    mutating func require(_ feature: BrowserFeature) {
        features.insert(feature)
    }

    func contains(_ feature: BrowserFeature) -> Bool {
        features.contains(feature)
    }
}

/// Internal seam for package-owned browser resources.
protocol BrowserAssetLoading: Sendable {
    func data(named name: String) throws -> Data
}

struct PackageBrowserAssetLoader: BrowserAssetLoading {
    func data(named name: String) throws -> Data {
        guard let resourceRoot = Bundle.module.resourceURL else {
            throw HTMLRenderingError.bundledAssetUnavailable(name)
        }

        let url = resourceRoot
            .appendingPathComponent("Browser", isDirectory: true)
            .appendingPathComponent(name)

        do {
            return try Data(contentsOf: url)
        } catch {
            throw HTMLRenderingError.bundledAssetUnavailable(name)
        }
    }
}

struct BrowserAssets: Sendable {
    let head: String
    let bootstrap: String
}

struct BrowserAssetAssembler: Sendable {
    private static let katexFontNames = [
        "KaTeX_AMS-Regular.woff2",
        "KaTeX_Caligraphic-Bold.woff2",
        "KaTeX_Caligraphic-Regular.woff2",
        "KaTeX_Fraktur-Bold.woff2",
        "KaTeX_Fraktur-Regular.woff2",
        "KaTeX_Main-Bold.woff2",
        "KaTeX_Main-BoldItalic.woff2",
        "KaTeX_Main-Italic.woff2",
        "KaTeX_Main-Regular.woff2",
        "KaTeX_Math-BoldItalic.woff2",
        "KaTeX_Math-Italic.woff2",
        "KaTeX_SansSerif-Bold.woff2",
        "KaTeX_SansSerif-Italic.woff2",
        "KaTeX_SansSerif-Regular.woff2",
        "KaTeX_Script-Regular.woff2",
        "KaTeX_Size1-Regular.woff2",
        "KaTeX_Size2-Regular.woff2",
        "KaTeX_Size3-Regular.woff2",
        "KaTeX_Size4-Regular.woff2",
        "KaTeX_Typewriter-Regular.woff2",
    ]

    let options: HTMLRenderOptions
    let loader: any BrowserAssetLoading

    func assemble(requirements: BrowserRequirements) throws -> BrowserAssets {
        var head = runtimePrelude

        if requirements.contains(.mermaid) {
            head += try mermaidAssets()
        }
        if requirements.contains(.katex) {
            head += try katexAssets()
        }

        return BrowserAssets(
            head: head,
            bootstrap: try runtimeBootstrap(requirements: requirements)
        )
    }

    private var runtimePrelude: String {
        """
        <script>
        window.__swiftMarkdownAssetFailures = [];
        window.__swiftMarkdownAssetFailed = function(name) {
            window.__swiftMarkdownAssetFailures.push(name);
        };
        </script>
        """
    }

    private func mermaidAssets() throws -> String {
        switch options.mermaidConfiguration.assetSource {
        case .bundled:
            return try inlineScript(loader.text(named: "mermaid.min.js"))
        case .cdn(let version):
            let encodedVersion = try validatedPackageVersion(version, feature: "Mermaid")
            let url = try validatedRemoteURL(
                "https://cdn.jsdelivr.net/npm/mermaid@\(encodedVersion)/dist/mermaid.min.js",
                feature: "Mermaid"
            )
            return externalScript(url: url, name: "mermaid")
        case .custom(let scriptURL):
            return externalScript(
                url: try validatedAssetURL(scriptURL, feature: "Mermaid"),
                name: "mermaid"
            )
        }
    }

    private func katexAssets() throws -> String {
        switch options.katexConfiguration.assetSource {
        case .bundled:
            let stylesheet = try bundledKaTeXStylesheet()
            let script = try loader.text(named: "katex.min.js")
            return "<style>\(stylesheet)</style>\n\(inlineScript(script))"
        case .cdn(let version):
            let encodedVersion = try validatedPackageVersion(version, feature: "KaTeX")
            let baseURL = try validatedRemoteURL(
                "https://cdn.jsdelivr.net/npm/katex@\(encodedVersion)/dist",
                feature: "KaTeX"
            )
            return externalKaTeXAssets(baseURL: baseURL)
        case .custom(let baseURL):
            return externalKaTeXAssets(
                baseURL: try validatedAssetURL(baseURL, feature: "KaTeX")
            )
        }
    }

    private func externalKaTeXAssets(baseURL: URL) -> String {
        let stylesheetURL = baseURL.appendingPathComponent("katex.min.css")
        let scriptURL = baseURL.appendingPathComponent("katex.min.js")
        let stylesheet = RendererUtils.escapeHTMLAttribute(stylesheetURL.absoluteString)

        return """
        <link rel="stylesheet" href="\(stylesheet)" onerror="window.__swiftMarkdownAssetFailed('katex-css')">
        \(externalScript(url: scriptURL, name: "katex"))
        """
    }

    private func externalScript(url: URL, name: String) -> String {
        let escapedURL = RendererUtils.escapeHTMLAttribute(url.absoluteString)
        let escapedName = RendererUtils.escapeHTMLAttribute(name)
        return "<script defer src=\"\(escapedURL)\" onerror=\"window.__swiftMarkdownAssetFailed('\(escapedName)')\"></script>\n"
    }

    private func inlineScript(_ source: String) -> String {
        let safeSource = source.replacingOccurrences(
            of: "</script",
            with: "<\\/script",
            options: .caseInsensitive
        )
        return "<script>\n\(safeSource)\n</script>\n"
    }

    private func bundledKaTeXStylesheet() throws -> String {
        var stylesheet = try loader.text(named: "katex.min.css")
        stylesheet = stylesheet.replacingOccurrences(
            of: #",url\(fonts/[^)]*\.(?:woff|ttf)\) format\(\"[^\"]+\"\)"#,
            with: "",
            options: .regularExpression
        )

        for fontName in Self.katexFontNames {
            let fontData = try loader.data(named: "fonts/\(fontName)")
            let dataURL = "data:font/woff2;base64,\(fontData.base64EncodedString())"
            stylesheet = stylesheet.replacingOccurrences(
                of: "fonts/\(fontName)",
                with: dataURL
            )
        }

        return stylesheet.replacingOccurrences(
            of: "</style",
            with: "<\\/style",
            options: .caseInsensitive
        )
    }

    private func validatedRemoteURL(_ value: String, feature: String) throws -> URL {
        guard let url = URL(string: value) else {
            throw HTMLRenderingError.invalidAssetURL(feature: feature, value: value)
        }
        return try validatedAssetURL(url, feature: feature)
    }

    private func validatedPackageVersion(_ version: String, feature: String) throws -> String {
        let permittedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        guard
            !version.isEmpty,
            version.unicodeScalars.allSatisfy(permittedCharacters.contains)
        else {
            throw HTMLRenderingError.invalidAssetURL(feature: feature, value: version)
        }
        return version
    }

    private func validatedAssetURL(_ url: URL, feature: String) throws -> URL {
        let permittedSchemes = ["https", "file"]
        guard let scheme = url.scheme?.lowercased(), permittedSchemes.contains(scheme) else {
            throw HTMLRenderingError.invalidAssetURL(feature: feature, value: url.absoluteString)
        }
        return url
    }

    private func runtimeBootstrap(requirements: BrowserRequirements) throws -> String {
        let hasMermaid = requirements.contains(.mermaid)
        let hasKaTeX = requirements.contains(.katex)
        let mermaidConfiguration = hasMermaid ? try inlineJSON(mermaidConfigurationObject) : "null"
        let katexConfiguration = hasKaTeX ? try inlineJSON(katexConfigurationObject) : "null"
        var configuredStyles: [String] = []
        if hasMermaid, let css = options.mermaidConfiguration.customCSS, !css.isEmpty {
            configuredStyles.append(css)
        }
        if hasKaTeX, let css = options.katexConfiguration.customCSS, !css.isEmpty {
            configuredStyles.append(css)
        }
        let customStyles = try inlineJSON(configuredStyles)
        let requiredFeatures = try inlineJSON(requirements.features.map(\.rawValue).sorted())
        let katexInitialization = hasKaTeX ? """
                    if (typeof katex === 'undefined') { throw new Error('KaTeX runtime unavailable'); }
                    document.querySelectorAll('.\(KaTeXCSS.mathBase)').forEach(function(element) {
                        const displayMode = element.classList.contains('\(KaTeXCSS.mathDisplay)');
                        try {
                            katex.render(element.textContent, element, Object.assign({}, katexConfiguration, { displayMode }));
                        } catch (error) {
                            if (katexConfiguration.throwOnError) { throw error; }
                            element.style.color = katexConfiguration.errorColor;
                        }
                    });
        """ : ""
        let mermaidInitialization = hasMermaid ? """
                    if (typeof mermaid === 'undefined') { throw new Error('Mermaid runtime unavailable'); }
                    mermaid.initialize(mermaidConfiguration);
                    if (mermaidConfiguration.startOnLoad) {
                        if (typeof mermaid.run === 'function') {
                            await mermaid.run({ querySelector: '.mermaid' });
                        } else {
                            mermaid.init(undefined, document.querySelectorAll('.mermaid'));
                        }
                    }
        """ : ""

        return """
        <script>
        (function() {
            const requiredFeatures = \(requiredFeatures);
            const mermaidConfiguration = \(mermaidConfiguration);
            const katexConfiguration = \(katexConfiguration);
            const customStyles = \(customStyles);

            function report(status, detail) {
                const payload = { status: status, detail: detail || null };
                window.dispatchEvent(new CustomEvent('swift-markdown-runtime', { detail: payload }));
                const handler = window.webkit && window.webkit.messageHandlers.markdownRuntime;
                if (handler) { handler.postMessage(payload); }
            }

            function installCustomStyles() {
                customStyles.forEach(function(css) {
                    const style = document.createElement('style');
                    style.textContent = css;
                    document.head.appendChild(style);
                });
            }

            function initializeFootnotes() {
                document.querySelectorAll('a[href^="#fn"]').forEach(function(link) {
                    link.addEventListener('click', function(event) {
                        event.preventDefault();
                        const target = document.querySelector(this.getAttribute('href'));
                        if (target) { target.scrollIntoView({ behavior: 'smooth' }); }
                    });
                });
            }

            function initializeTaskLists() {
                document.querySelectorAll('.task-list-checkbox').forEach(function(checkbox) {
                    checkbox.setAttribute('tabindex', '0');
                    checkbox.addEventListener('keydown', function(event) {
                        if (event.key === 'Enter' || event.key === ' ') {
                            event.preventDefault();
                            this.click();
                        }
                    });
                });
            }

            async function initialize() {
                try {
                    if (window.__swiftMarkdownAssetFailures.length > 0) {
                        throw new Error('Failed browser assets: ' + window.__swiftMarkdownAssetFailures.join(', '));
                    }

                    installCustomStyles();

        \(katexInitialization)
        \(mermaidInitialization)

                    if (requiredFeatures.includes('footnotes')) { initializeFootnotes(); }
                    if (requiredFeatures.includes('taskLists')) { initializeTaskLists(); }
                    report('ready');
                } catch (error) {
                    report('failed', error instanceof Error ? error.message : String(error));
                }
            }

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', initialize, { once: true });
            } else {
                initialize();
            }
        })();
        </script>
        """
    }

    private var mermaidConfigurationObject: [String: Any] {
        let configuration = options.mermaidConfiguration
        return [
            "startOnLoad": configuration.startOnLoad,
            "theme": configuration.theme.rawValue,
            "securityLevel": configuration.securityLevel.rawValue,
            "fontFamily": configuration.fontFamily,
            "fontSize": configuration.fontSize,
            "maxTextSize": configuration.maxTextSize,
            "useMaxWidth": configuration.useMaxWidth,
            "htmlLabels": true,
            "suppressErrorRendering": !configuration.displayErrors,
            "logLevel": configuration.logLevel,
            "flowchart": [
                "curve": configuration.flowchart.curve.rawValue,
                "padding": configuration.flowchart.padding,
                "nodeSpacing": configuration.flowchart.nodeSpacing,
                "rankSpacing": configuration.flowchart.rankSpacing,
                "useMaxWidth": configuration.flowchart.useMaxWidth,
            ],
            "sequence": [
                "showSequenceNumbers": configuration.sequence.showNumbers,
                "actorMargin": configuration.sequence.actorMargin,
                "noteMargin": configuration.sequence.noteMargin,
                "messageMargin": configuration.sequence.messageMargin,
                "mirrorActors": configuration.sequence.mirrorActors,
                "useMaxWidth": configuration.sequence.useMaxWidth,
            ],
        ]
    }

    private var katexConfigurationObject: [String: Any] {
        let configuration = options.katexConfiguration
        var result: [String: Any] = [
            "throwOnError": configuration.throwOnError,
            "errorColor": configuration.errorColor,
        ]
        if let minRuleThickness = configuration.minRuleThickness {
            result["minRuleThickness"] = minRuleThickness
        }
        return result
    }

    private func inlineJSON(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw HTMLRenderingError.browserConfigurationEncodingFailed
        }
        return json
            .replacingOccurrences(of: "<", with: "\\u003C")
            .replacingOccurrences(of: ">", with: "\\u003E")
            .replacingOccurrences(of: "&", with: "\\u0026")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}

private extension BrowserAssetLoading {
    func text(named name: String) throws -> String {
        let data = try data(named: name)
        guard let value = String(data: data, encoding: .utf8) else {
            throw HTMLRenderingError.bundledAssetUnavailable(name)
        }
        return value
    }
}
