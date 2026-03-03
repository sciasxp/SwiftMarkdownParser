/// Configuration options for KaTeX math rendering
///
/// This file provides configuration settings for customizing KaTeX math expression
/// appearance and behavior when rendering markdown with embedded math.

import Foundation

// MARK: - KaTeX CSS Class Names

/// Shared CSS class name constants used by both the Swift renderer and the KaTeX init script
public enum KaTeXCSS {
    public static let mathBase = "math"
    public static let mathDisplay = "math-display"
    public static let mathInline = "math-inline"
}

// MARK: - KaTeX Configuration

/// Configuration for KaTeX math rendering
public struct KaTeXConfiguration: Sendable {

    /// KaTeX rendering mode for loading the library
    public enum RenderMode: Sendable {
        /// Use CDN-hosted KaTeX (requires internet connection)
        case cdn(version: String)
        /// Use custom KaTeX URL (local or alternative CDN)
        case custom(url: String)
    }

    /// Whether KaTeX rendering is enabled
    public let enabled: Bool

    /// Rendering mode (CDN or custom URL)
    public let renderMode: RenderMode

    /// Whether to throw on KaTeX rendering errors
    public let throwOnError: Bool

    /// Color used for error messages when throwOnError is false
    public let errorColor: String

    /// Minimum thickness of fraction lines and similar elements (in em)
    public let minRuleThickness: Double?

    /// Default display mode (overridden per-element by CSS class detection)
    public let displayMode: Bool

    /// Custom CSS to inject for math elements
    public let customCSS: String?

    /// Default configuration
    public static let `default` = KaTeXConfiguration()

    /// Initialize with custom settings
    public init(
        enabled: Bool = true,
        renderMode: RenderMode = .cdn(version: "0.16.21"),
        throwOnError: Bool = false,
        errorColor: String = "#cc0000",
        minRuleThickness: Double? = nil,
        displayMode: Bool = false,
        customCSS: String? = nil
    ) {
        self.enabled = enabled
        self.renderMode = renderMode
        self.throwOnError = throwOnError
        self.errorColor = errorColor
        self.minRuleThickness = minRuleThickness
        self.displayMode = displayMode
        self.customCSS = customCSS
    }

    /// Generate the KaTeX initialization script that renders math elements on page load
    public func generateInitScript() -> String {
        var options: [String] = []
        options.append("throwOnError: \(throwOnError ? "true" : "false")")
        options.append("errorColor: '\(errorColor)'")

        if let minRuleThickness = minRuleThickness {
            options.append("minRuleThickness: \(minRuleThickness)")
        }

        let optionsString = options.joined(separator: ", ")

        var script = """
        document.addEventListener("DOMContentLoaded", function() {
            if (typeof katex === 'undefined') { return; }
            var mathElements = document.querySelectorAll('.\(KaTeXCSS.mathBase)');
            mathElements.forEach(function(el) {
                var isDisplay = el.classList.contains('\(KaTeXCSS.mathDisplay)');
                var text = el.textContent;
                try {
                    katex.render(text, el, {displayMode: isDisplay, \(optionsString)});
                } catch (e) {
                    if (\(throwOnError ? "true" : "false")) { throw e; }
                    el.style.color = '\(errorColor)';
                }
            });
        });
        """

        // Add custom CSS injection if provided
        if let customCSS = customCSS, !customCSS.isEmpty {
            script += """

            // Inject custom CSS for math elements
            document.addEventListener('DOMContentLoaded', function() {
                var style = document.createElement('style');
                style.textContent = `\(customCSS)`;
                document.head.appendChild(style);
            });
            """
        }

        return script
    }

    /// Resolved base URL for KaTeX assets
    private var resolvedBaseURL: String {
        switch renderMode {
        case .cdn(let version):
            return "https://cdn.jsdelivr.net/npm/katex@\(version)/dist"
        case .custom(let url):
            return url
        }
    }

    /// Generate the KaTeX CSS stylesheet link tag
    public func generateStylesheetLink() -> String {
        return "<link rel=\"stylesheet\" href=\"\(resolvedBaseURL)/katex.min.css\">"
    }

    /// Generate the KaTeX JavaScript script tags
    public func generateScriptTags() -> String {
        return "<script defer src=\"\(resolvedBaseURL)/katex.min.js\"></script>"
    }
}
