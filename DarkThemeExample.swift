import Foundation
import SwiftMarkdownParser

// Example demonstrating enhanced dark theme support for Mermaid diagrams

let sequenceDiagramMarkdown = """
# Sequence Diagram Example

```mermaid
sequenceDiagram
    participant User
    participant App
    participant FileService  
    participant MermaidRenderer
    
    User->>App: Open Mermaid File
    App->>FileService: Read File Content
    FileService-->>App: Return Content
    App->>MermaidRenderer: Extract Charts
    MermaidRenderer-->>App: Return Processed Content
    App-->>User: Display Rendered Chart
    
    Note over User,App: Labels now visible!
    Note over FileService,MermaidRenderer: Enhanced contrast
```

This diagram demonstrates the improved dark theme visibility.
"""

async func demonstrateDarkThemes() {
    let parser = SwiftMarkdownParser()
    
    do {
        // Regular dark theme with enhanced visibility
        print("=== Enhanced Dark Theme ===")
        let darkHTML = try await parser.parseToHTMLWithDarkTheme(sequenceDiagramMarkdown)
        print("✅ Enhanced dark theme generated successfully")
        
        // High contrast dark theme for maximum visibility
        print("\n=== High Contrast Dark Theme ===")
        let highContrastHTML = try await parser.parseToHTMLWithDarkHighContrastTheme(sequenceDiagramMarkdown)
        print("✅ High contrast dark theme generated successfully")
        
        // Custom theme example
        print("\n=== Custom Dark Theme ===")
        let customConfig = MermaidConfiguration(
            theme: .dark,
            fontSize: 18,
            customCSS: """
            .mermaid text {
                fill: #00ff00 !important;
                font-weight: bold;
                stroke: #000000;
                stroke-width: 0.5;
            }
            .mermaid .actor {
                fill: #1a1a1a !important;
                stroke: #00ff00 !important;
                stroke-width: 3px;
            }
            """
        )
        let context = RenderContext(mermaidConfiguration: customConfig)
        let customHTML = try await parser.parseToHTML(sequenceDiagramMarkdown, context: context)
        print("✅ Custom dark theme with green text generated successfully")
        
        // Verify all themes contain proper styling
        let themes = [
            ("Enhanced Dark", darkHTML),
            ("High Contrast", highContrastHTML),
            ("Custom Green", customHTML)
        ]
        
        for (name, html) in themes {
            let hasCustomCSS = html.contains("document.createElement('style')")
            let hasWhiteText = html.contains("fill: #ffffff") || html.contains("fill: #00ff00")
            let hasMermaidContainer = html.contains("mermaid-container")
            
            print("\n\(name) Theme Validation:")
            print("  ✅ Custom CSS injection: \(hasCustomCSS ? "✓" : "✗")")
            print("  ✅ Visible text colors: \(hasWhiteText ? "✓" : "✗")")
            print("  ✅ Mermaid structure: \(hasMermaidContainer ? "✓" : "✗")")
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
}

// Uncomment to run the example:
// Task {
//     await demonstrateDarkThemes()
// }