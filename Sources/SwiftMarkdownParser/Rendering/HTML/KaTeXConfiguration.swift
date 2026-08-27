/// HTML output options for KaTeX math rendering.
///
/// This file provides configuration settings for customizing KaTeX math expression
/// appearance and behavior when rendering markdown with embedded math.

public import Foundation

// MARK: - KaTeX CSS Class Names

/// Shared CSS class name constants used by both the Swift renderer and the KaTeX init script
enum KaTeXCSS {
    static let mathBase = "math"
    static let mathDisplay = "math-display"
    static let mathInline = "math-inline"
}

// MARK: - KaTeX Configuration

/// Configuration for KaTeX math rendering
public struct KaTeXConfiguration: Sendable {

    /// Source used to load the KaTeX browser runtime.
    public enum AssetSource: Sendable, Equatable {
        /// Inline the KaTeX resources shipped with this package.
        case bundled
        /// Use CDN-hosted KaTeX (requires internet connection)
        case cdn(version: String)
        /// Use a caller-owned KaTeX distribution base URL.
        case custom(baseURL: URL)
    }

    /// Whether KaTeX rendering is enabled
    public let enabled: Bool

    /// Source used to load KaTeX assets.
    public let assetSource: AssetSource

    /// Whether to throw on KaTeX rendering errors
    public let throwOnError: Bool

    /// Color used for error messages when throwOnError is false
    public let errorColor: String

    /// Minimum thickness of fraction lines and similar elements (in em)
    public let minRuleThickness: Double?

    /// Custom CSS to inject for math elements
    public let customCSS: String?

    /// Default configuration
    public static let `default` = KaTeXConfiguration()

    /// Initialize with custom settings
    public init(
        enabled: Bool = true,
        assetSource: AssetSource = .cdn(version: "0.16.21"),
        throwOnError: Bool = false,
        errorColor: String = "#cc0000",
        minRuleThickness: Double? = nil,
        customCSS: String? = nil
    ) {
        self.enabled = enabled
        self.assetSource = assetSource
        self.throwOnError = throwOnError
        self.errorColor = errorColor
        self.minRuleThickness = minRuleThickness
        self.customCSS = customCSS
    }

}
