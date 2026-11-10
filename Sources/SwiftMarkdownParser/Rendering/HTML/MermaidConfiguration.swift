/// HTML output options for diagram rendering.
///
/// Diagrams are written in Mermaid syntax (a ```mermaid fenced block) and drawn in
/// the browser by the Pele runtime bundled with this package.

public import Foundation

// MARK: - Mermaid Configuration

/// Configuration for rendering Mermaid-syntax diagrams with the Pele browser runtime.
public struct MermaidConfiguration: Sendable, Equatable {

    /// Data-only palette projected onto the `--pele-*` CSS custom properties.
    ///
    /// Pele paints with these variables at paint time, so changing them restyles an
    /// already rendered diagram without rendering it again. Every value is a CSS
    /// color. A value containing `;`, `{`, `}`, `<`, `>`, a backslash or a line
    /// break is ignored, because it cannot be a color and could escape the declaration.
    public struct Theme: Sendable, Equatable {
        /// Number of `--pele-series-N` variables Pele reads.
        public static let seriesCount = 12

        public let background: String?
        public let foreground: String?
        public let foregroundOnDark: String?
        public let foregroundOnLight: String?
        public let line: String?
        public let border: String?
        public let surface: String?
        public let surfaceAlternate: String?
        public let muted: String?
        public let accent: String?
        public let critical: String?
        public let error: String?
        /// Series colors in order. Entries beyond ``seriesCount`` are ignored.
        public let series: [String]

        public init(
            background: String? = nil,
            foreground: String? = nil,
            foregroundOnDark: String? = nil,
            foregroundOnLight: String? = nil,
            line: String? = nil,
            border: String? = nil,
            surface: String? = nil,
            surfaceAlternate: String? = nil,
            muted: String? = nil,
            accent: String? = nil,
            critical: String? = nil,
            error: String? = nil,
            series: [String] = []
        ) {
            self.background = background
            self.foreground = foreground
            self.foregroundOnDark = foregroundOnDark
            self.foregroundOnLight = foregroundOnLight
            self.line = line
            self.border = border
            self.surface = surface
            self.surfaceAlternate = surfaceAlternate
            self.muted = muted
            self.accent = accent
            self.critical = critical
            self.error = error
            self.series = series
        }

        /// The Pele defaults: no variable is set.
        public static let `default` = Theme()
    }

    /// Texts shown by the browser runtime. The host owns localization.
    public struct Messages: Sendable, Equatable {
        /// Shown above the diagram source when Pele rejects a diagram.
        public let diagramFailed: String

        public init(diagramFailed: String) {
            self.diagramFailed = diagramFailed
        }

        /// Messages from the package string catalog, in the given locale.
        ///
        /// Pass the locale the document is shown in when it is not the process locale.
        public static func localized(locale: Locale = .current) -> Messages {
            var resource = LocalizedStringResource(
                "html.diagram.error.render_failed",
                defaultValue: "This diagram could not be rendered. Its source is shown below.",
                bundle: #bundle,
                comment: "Message shown above the source of a diagram that the renderer rejected."
            )
            resource.locale = locale
            return Messages(diagramFailed: String(localized: resource))
        }
    }

    /// Source used to load the Pele browser runtime.
    public enum AssetSource: Sendable, Equatable {
        /// Inline the Pele runtime shipped with this package.
        case bundled
        /// Use the CDN-hosted runtime (requires internet connection).
        case cdn(version: String)
        /// Use a caller-owned `pele.global.js` URL (HTTPS or file).
        case custom(scriptURL: URL)
    }

    /// Pan and zoom controls for diagrams wider than their container.
    public enum Zoom: String, Sendable, Equatable {
        /// Controls appear only when the diagram is scaled down to fit.
        case auto
        /// Controls are always available.
        case always
        /// No controls.
        case disabled
    }

    /// The Pele version `.cdn` loads by default; it matches the bundled runtime.
    public static let defaultRuntimeVersion = "1.13.0"

    /// Whether diagram rendering is enabled. When `false`, diagrams stay as code blocks.
    public let enabled: Bool

    /// Source used to load the Pele runtime.
    public let assetSource: AssetSource

    /// Palette projected onto the `--pele-*` custom properties.
    public let theme: Theme

    /// Font family for diagram text. `nil` inherits `--pele-font`, then the page font.
    public let fontFamily: String?

    /// Base font size in pixels.
    public let fontSize: Int

    /// Maximum diagram source length in characters. Longer sources are rejected by Pele.
    public let maxTextSize: Int

    /// Zoom controls.
    public let zoom: Zoom

    /// HTML ID prefix for diagram containers
    public let htmlIdPrefix: String

    /// Texts shown by the browser runtime.
    public let messages: Messages

    /// Custom CSS to inject for diagrams
    public let customCSS: String?

    /// Default configuration
    public static let `default` = MermaidConfiguration()

    /// Initialize with custom settings
    public init(
        enabled: Bool = true,
        assetSource: AssetSource = .cdn(version: MermaidConfiguration.defaultRuntimeVersion),
        theme: Theme = .default,
        fontFamily: String? = nil,
        fontSize: Int = 16,
        maxTextSize: Int = 50000,
        zoom: Zoom = .auto,
        htmlIdPrefix: String = "mermaid-",
        messages: Messages = .localized(),
        customCSS: String? = nil
    ) {
        self.enabled = enabled
        self.assetSource = assetSource
        self.theme = theme
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.maxTextSize = maxTextSize
        self.zoom = zoom
        self.htmlIdPrefix = htmlIdPrefix
        self.messages = messages
        self.customCSS = customCSS
    }
}

// MARK: - CSS projection

extension MermaidConfiguration {
    /// The `:root` rule declaring every configured `--pele-*` variable, or `nil` when none is set.
    var themeStyleSheet: String? {
        var variables: [(name: String, value: String)] = []
        func add(_ name: String, _ value: String?) {
            guard let value = Self.safeCSSValue(value) else { return }
            variables.append((name, value))
        }

        add("--pele-bg", theme.background)
        add("--pele-fg", theme.foreground)
        add("--pele-fg-on-dark", theme.foregroundOnDark)
        add("--pele-fg-on-light", theme.foregroundOnLight)
        add("--pele-line", theme.line)
        add("--pele-border", theme.border)
        add("--pele-surface", theme.surface)
        add("--pele-surface-alt", theme.surfaceAlternate)
        add("--pele-muted", theme.muted)
        add("--pele-accent", theme.accent)
        add("--pele-critical", theme.critical)
        add("--pele-error", theme.error)
        for (index, color) in theme.series.prefix(Theme.seriesCount).enumerated() {
            add("--pele-series-\(index + 1)", color)
        }
        add("--pele-font", fontFamily)

        guard !variables.isEmpty else { return nil }
        let declarations = variables.map { "    \($0.name): \($0.value);" }.joined(separator: "\n")
        return ":root {\n\(declarations)\n}"
    }

    private static func safeCSSValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        let forbidden = CharacterSet(charactersIn: ";{}<>\\").union(.newlines)
        guard trimmed.rangeOfCharacter(from: forbidden) == nil else { return nil }
        return trimmed
    }
}
