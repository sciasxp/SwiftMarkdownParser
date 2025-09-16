/// Configuration options for Mermaid diagram rendering
/// 
/// This file provides configuration settings for customizing Mermaid diagram
/// appearance and behavior when rendering markdown with embedded diagrams.

import Foundation

// MARK: - Mermaid Configuration

/// Configuration for Mermaid diagram rendering
public struct MermaidConfiguration: Sendable {
    
    /// Mermaid theme options
    public enum Theme: String, Sendable, CaseIterable {
        case `default` = "default"
        case dark = "dark"
        case forest = "forest"
        case neutral = "neutral"
        case base = "base"
    }
    
    /// Mermaid rendering mode
    public enum RenderMode: Sendable {
        /// Use embedded Mermaid.js (no external dependencies)
        case embedded
        /// Use CDN-hosted Mermaid.js (requires internet connection)
        case cdn(version: String)
        /// Use custom Mermaid.js URL
        case custom(url: String)
    }
    
    /// Security level for Mermaid rendering
    public enum SecurityLevel: String, Sendable {
        case strict = "strict"
        case loose = "loose"
        case antiscript = "antiscript"
        case sandbox = "sandbox"
    }
    
    /// Whether Mermaid rendering is enabled
    public let enabled: Bool
    
    /// Mermaid theme to use
    public let theme: Theme
    
    /// Rendering mode (embedded, CDN, or custom)
    public let renderMode: RenderMode
    
    /// Security level for rendering
    public let securityLevel: SecurityLevel
    
    /// Start on load (auto-render on page load)
    public let startOnLoad: Bool
    
    /// Font family for diagrams
    public let fontFamily: String
    
    /// Font size in pixels
    public let fontSize: Int
    
    /// Maximum text size allowed
    public let maxTextSize: Int
    
    /// Whether to use max width for diagrams
    public let useMaxWidth: Bool
    
    /// HTML ID prefix for diagram containers
    public let htmlIdPrefix: String
    
    /// Enable error rendering in diagrams
    public let displayErrors: Bool
    
    /// Log level for debugging
    public let logLevel: Int
    
    /// Custom CSS to inject for diagrams
    public let customCSS: String?
    
    /// Flowchart-specific configuration
    public let flowchart: FlowchartConfig
    
    /// Sequence diagram-specific configuration
    public let sequence: SequenceConfig
    
    /// Default configuration
    public static let `default` = MermaidConfiguration()
    
    /// Dark theme configuration with enhanced visibility
    public static let dark = MermaidConfiguration(
        theme: .dark,
        customCSS: """
        .mermaid .messageText {
            fill: #ffffff !important;
            font-weight: 500;
        }
        .mermaid .actor {
            fill: #2d2d2d !important;
            stroke: #ffffff !important;
        }
        .mermaid .actor-box {
            fill: #2d2d2d !important;
        }
        .mermaid .labelText {
            fill: #ffffff !important;
            font-weight: 500;
        }
        .mermaid text {
            fill: #ffffff !important;
        }
        .mermaid .sequenceNumber {
            fill: #ffffff !important;
        }
        .mermaid .note {
            fill: #4a4a4a !important;
            stroke: #ffffff !important;
        }
        .mermaid .noteText {
            fill: #ffffff !important;
        }
        """
    )
    
    /// High contrast dark theme configuration for maximum visibility
    public static let darkHighContrast = MermaidConfiguration(
        theme: .dark,
        customCSS: """
        .mermaid .messageText {
            fill: #ffffff !important;
            font-weight: bold;
            font-size: 14px;
        }
        .mermaid .actor {
            fill: #1a1a1a !important;
            stroke: #ffffff !important;
            stroke-width: 2px;
        }
        .mermaid .actor-box {
            fill: #1a1a1a !important;
        }
        .mermaid .labelText, .mermaid text {
            fill: #ffffff !important;
            font-weight: bold;
            text-shadow: 1px 1px 2px rgba(0,0,0,0.8);
        }
        .mermaid .sequenceNumber {
            fill: #ffffff !important;
            font-weight: bold;
        }
        .mermaid .note {
            fill: #2d2d2d !important;
            stroke: #ffffff !important;
            stroke-width: 2px;
        }
        .mermaid .noteText {
            fill: #ffffff !important;
            font-weight: bold;
        }
        .mermaid .activation0, .mermaid .activation1, .mermaid .activation2 {
            fill: #4a4a4a !important;
            stroke: #ffffff !important;
        }
        """
    )
    
    /// Initialize with custom settings
    public init(
        enabled: Bool = true,
        theme: Theme = .default,
        renderMode: RenderMode = .embedded,
        securityLevel: SecurityLevel = .strict,
        startOnLoad: Bool = true,
        fontFamily: String = "\"Trebuchet MS\", verdana, arial, sans-serif",
        fontSize: Int = 16,
        maxTextSize: Int = 50000,
        useMaxWidth: Bool = true,
        htmlIdPrefix: String = "mermaid-",
        displayErrors: Bool = false,
        logLevel: Int = 5,
        customCSS: String? = nil,
        flowchart: FlowchartConfig = .default,
        sequence: SequenceConfig = .default
    ) {
        self.enabled = enabled
        self.theme = theme
        self.renderMode = renderMode
        self.securityLevel = securityLevel
        self.startOnLoad = startOnLoad
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.maxTextSize = maxTextSize
        self.useMaxWidth = useMaxWidth
        self.htmlIdPrefix = htmlIdPrefix
        self.displayErrors = displayErrors
        self.logLevel = logLevel
        self.customCSS = customCSS
        self.flowchart = flowchart
        self.sequence = sequence
    }
    
    /// Generate Mermaid initialization JavaScript
    public func generateInitScript() -> String {
        let config = """
        {
            startOnLoad: \(startOnLoad ? "true" : "false"),
            theme: '\(theme.rawValue)',
            securityLevel: '\(securityLevel.rawValue)',
            fontFamily: '\(fontFamily)',
            fontSize: \(fontSize),
            maxTextSize: \(maxTextSize),
            useMaxWidth: \(useMaxWidth ? "true" : "false"),
            htmlLabels: true,
            displayMode: 'iframe',
            logLevel: \(logLevel),
            flowchart: {
                curve: '\(flowchart.curve.rawValue)',
                padding: \(flowchart.padding),
                nodeSpacing: \(flowchart.nodeSpacing),
                rankSpacing: \(flowchart.rankSpacing),
                useMaxWidth: \(flowchart.useMaxWidth ? "true" : "false")
            },
            sequence: {
                showSequenceNumbers: \(sequence.showNumbers ? "true" : "false"),
                actorMargin: \(sequence.actorMargin),
                noteMargin: \(sequence.noteMargin),
                messageMargin: \(sequence.messageMargin),
                mirrorActors: \(sequence.mirrorActors ? "true" : "false"),
                useMaxWidth: \(sequence.useMaxWidth ? "true" : "false")
            }
        }
        """
        
        var scriptContent = """
        window.mermaidConfig = \(config);
        if (typeof mermaid !== 'undefined') {
            mermaid.initialize(window.mermaidConfig);
        }
        """
        
        // Add custom CSS if provided
        if let customCSS = customCSS, !customCSS.isEmpty {
            scriptContent += """
            
            // Inject custom CSS for enhanced theme support
            document.addEventListener('DOMContentLoaded', function() {
                const style = document.createElement('style');
                style.textContent = `\(customCSS)`;
                document.head.appendChild(style);
            });
            """
        }
        
        return scriptContent
    }
}

// MARK: - Flowchart Configuration

/// Configuration specific to flowchart diagrams
public struct FlowchartConfig: Sendable {
    
    /// Curve style for flowchart edges
    public enum Curve: String, Sendable {
        case basis = "basis"
        case linear = "linear"
        case cardinal = "cardinal"
        case stepBefore = "stepBefore"
        case stepAfter = "stepAfter"
    }
    
    /// Curve style for edges
    public let curve: Curve
    
    /// Padding around nodes
    public let padding: Int
    
    /// Spacing between nodes
    public let nodeSpacing: Int
    
    /// Spacing between ranks
    public let rankSpacing: Int
    
    /// Whether to use max width
    public let useMaxWidth: Bool
    
    /// Default flowchart configuration
    public static let `default` = FlowchartConfig()
    
    public init(
        curve: Curve = .basis,
        padding: Int = 8,
        nodeSpacing: Int = 50,
        rankSpacing: Int = 50,
        useMaxWidth: Bool = true
    ) {
        self.curve = curve
        self.padding = padding
        self.nodeSpacing = nodeSpacing
        self.rankSpacing = rankSpacing
        self.useMaxWidth = useMaxWidth
    }
}

// MARK: - Sequence Diagram Configuration

/// Configuration specific to sequence diagrams
public struct SequenceConfig: Sendable {
    
    /// Whether to show sequence numbers
    public let showNumbers: Bool
    
    /// Margin between actors
    public let actorMargin: Int
    
    /// Margin for notes
    public let noteMargin: Int
    
    /// Margin for messages
    public let messageMargin: Int
    
    /// Whether to mirror actors at bottom
    public let mirrorActors: Bool
    
    /// Whether to use max width
    public let useMaxWidth: Bool
    
    /// Default sequence diagram configuration
    public static let `default` = SequenceConfig()
    
    public init(
        showNumbers: Bool = false,
        actorMargin: Int = 50,
        noteMargin: Int = 10,
        messageMargin: Int = 35,
        mirrorActors: Bool = true,
        useMaxWidth: Bool = true
    ) {
        self.showNumbers = showNumbers
        self.actorMargin = actorMargin
        self.noteMargin = noteMargin
        self.messageMargin = messageMargin
        self.mirrorActors = mirrorActors
        self.useMaxWidth = useMaxWidth
    }
}

