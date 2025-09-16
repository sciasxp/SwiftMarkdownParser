import Foundation
import SwiftMarkdownParser

@main
struct WebViewTest {
    static func main() async {
        // Test the problematic triple asterisk content specifically
        let testMarkdown = """
        ### Text Styling Mastery

        **Bold text** makes important points stand out, while *italic text* adds subtle emphasis. You can even combine them for ***bold italic*** text. Need to show corrections? Use ~~strikethrough~~ text.

        For technical documentation, `inline code` snippets are essential.

        ### Lists That Work

        #### Ordered Lists for Procedures
        1. **Project Setup**
           1. Install dependencies
           2. Configure environment
           3. Initialize repository
        2. **Development Workflow**
           1. Create feature branch
           2. Implement changes
           3. Write tests

        #### Unordered Lists for Features
        - **Editor Features**
          - Auto-save functionality
          - Customizable themes
        - **Export Options**
          - PDF with custom styling
          - HTML with embedded CSS

        ---

        ## Advanced Features

        ### Task Lists for Project Management
        - [x] Enhanced syntax highlighting engine
        - [x] Performance optimization (2x faster)
        - [ ] Collaborative editing features
        - [ ] Cloud synchronization

        **Bold text** and *italic text* and ***bold italic*** should all work now.
        """
        
        do {
            print("🧪 Testing WebView HTML generation...")
            
            // Test the new WebView HTML document generation
            let htmlDocument = try await WebViewSupport.generateMarkdownHTMLDocument(
                testMarkdown,
                title: "WebView Test Document",
                includeMathSupport: true,
                includeTaskListSupport: true
            )
            
            // Save the generated HTML to a file for inspection
            let outputURL = URL(fileURLWithPath: "/Users/lucianonunes/Projects/markdown/test_output.html")
            try htmlDocument.write(to: outputURL, atomically: true, encoding: String.Encoding.utf8)
            
            print("✅ Successfully generated HTML document")
            print("📄 Output saved to: \(outputURL.path)")
            print("🌐 Open in browser to verify rendering")
            
            // Print a snippet of the generated HTML for verification
            let snippet = String(htmlDocument.prefix(500))
            print("\n📋 HTML Preview (first 500 chars):")
            print(snippet)
            
        } catch {
            print("❌ Error generating HTML: \(error)")
        }
    }
}
