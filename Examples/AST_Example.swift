/// Example demonstrating AST-focused markdown parsing with multiple renderers
/// 
/// This example shows how the same AST can be used by different renderers
/// to produce various output formats.
import Foundation
import SwiftMarkdownParser

@main
struct ASTExample {
    static func main() async {
        print("🔄 Swift Markdown Parser - AST Example")
        print("=====================================\n")
        
        // Sample markdown content
        let markdown = """
        # Welcome to Swift Markdown Parser
        
        This is a **bold** statement with *italic* text and a [link](https://swift.org).
        
        ## Code Example
        
        ```swift
        let parser = SwiftMarkdownParser()
        let ast = try await parser.parseToAST(markdown)
        ```
        
        > This is a blockquote with some important information.
        
        - List item 1
        - List item 2
        - List item 3
        """
        
        do {
            // Create parser instance
            let parser = SwiftMarkdownParser()
            
            // Parse markdown to AST
            print("📝 Parsing markdown to AST...")
            let ast = try await parser.parseToAST(markdown)
            
            // Display AST structure
            print("\n🌳 AST Structure:")
            printAST(ast, indent: 0)
            
            // Render to HTML
            print("\n🌐 HTML Output:")
            let htmlRenderer = HTMLRenderer()
            let html = try await htmlRenderer.render(document: ast)
            print(html)
            
            // Demonstrate custom renderer context
            print("\n🎨 HTML with Custom Styling:")
            let customContext = RenderContext(
                styleConfiguration: StyleConfiguration(
                    cssClasses: [
                        .heading: "custom-heading",
                        .paragraph: "custom-paragraph",
                        .emphasis: "custom-italic",
                        .strongEmphasis: "custom-bold"
                    ],
                    includeSourcePositions: true
                )
            )
            let customRenderer = HTMLRenderer(context: customContext)
            let customHTML = try await customRenderer.render(document: ast)
            print(customHTML)
            
            // SwiftUI rendering is also available via SwiftUIRenderer
            // See SwiftUIRenderer.swift for native iOS/macOS rendering
            print("\n📱 SwiftUI Renderer:")
            print("// Use SwiftUIRenderer from the library for native SwiftUI output:")
            print("// let swiftUIRenderer = SwiftUIRenderer()")
            print("// let view = try await swiftUIRenderer.render(document: ast)")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    /// Recursively print AST structure for debugging
    static func printAST(_ node: ASTNode, indent: Int) {
        let indentString = String(repeating: "  ", count: indent)
        
        switch node {
        case let document as DocumentNode:
            print("\(indentString)📄 Document (\(document.children.count) children)")
            
        case let paragraph as ParagraphNode:
            print("\(indentString)📝 Paragraph (\(paragraph.children.count) children)")
            
        case let heading as HeadingNode:
            print("\(indentString)📋 Heading Level \(heading.level) (\(heading.children.count) children)")
            
        case let text as TextNode:
            let preview = text.content.prefix(30)
            print("\(indentString)📄 Text: \"\(preview)\(text.content.count > 30 ? "..." : "")\"")
            
        case let emphasis as EmphasisNode:
            print("\(indentString)📝 Emphasis (\(emphasis.children.count) children)")
            
        case let strong as StrongEmphasisNode:
            print("\(indentString)💪 Strong (\(strong.children.count) children)")
            
        case let link as LinkNode:
            print("\(indentString)🔗 Link: \(link.url) (\(link.children.count) children)")
            
        case let image as ImageNode:
            print("\(indentString)🖼️ Image: \(image.url) (\(image.children.count) children)")
            
        case let codeBlock as CodeBlockNode:
            let language = codeBlock.language ?? "plain"
            print("\(indentString)💻 CodeBlock (\(language)): \(codeBlock.content.prefix(20))...")
            
        case let blockQuote as BlockQuoteNode:
            print("\(indentString)💬 BlockQuote (\(blockQuote.children.count) children)")
            
        case let list as ListNode:
            let type = list.isOrdered ? "Ordered" : "Unordered"
            print("\(indentString)📋 \(type) List (\(list.children.count) items)")
            
        case let listItem as ListItemNode:
            print("\(indentString)• ListItem (\(listItem.children.count) children)")
            
        default:
            print("\(indentString)❓ \(node.nodeType): \(type(of: node))")
        }
        
        // Recursively print children
        for child in node.children {
            printAST(child, indent: indent + 1)
        }
    }
}

// MARK: - SwiftUI Rendering
// SwiftUI rendering is provided by `SwiftUIRenderer` in the SwiftMarkdownParser library.
// See Docs/SwiftUIRenderer.md for usage details. 