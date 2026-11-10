import Foundation
import SwiftMarkdownParser

// Example demonstrating a dark palette for diagrams drawn by the bundled Pele runtime

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

func demonstrateDarkThemes() async {
    let parser = SwiftMarkdownParser()

    do {
        let document = try parser.parse(sequenceDiagramMarkdown)

        // Diagrams are drawn by the bundled Pele runtime, which paints with --pele-* variables.
        let darkTheme = MermaidConfiguration.Theme(
            background: "#0d1117",
            foreground: "#e6edf3",
            line: "#8b949e",
            border: "#30363d",
            surface: "#161b22",
            accent: "#2f81f7"
        )
        let darkOptions = HTMLRenderOptions(
            mermaidConfiguration: MermaidConfiguration(assetSource: .bundled, theme: darkTheme)
        )
        let darkHTML = try await HTMLRenderer(options: darkOptions).renderFragment(document)

        let hasThemeVariables = darkHTML.contains("--pele-bg: #0d1117;")
        let hasMermaidContainer = darkHTML.contains("mermaid-container")
        print("Dark theme variables: \(hasThemeVariables ? "✓" : "✗")")
        print("Diagram container: \(hasMermaidContainer ? "✓" : "✗")")
    } catch {
        print("❌ Error: \(error)")
    }
}

// Uncomment to run the example:
// Task {
//     await demonstrateDarkThemes()
// }
