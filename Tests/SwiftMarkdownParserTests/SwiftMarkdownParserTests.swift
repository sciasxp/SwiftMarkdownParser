import Testing
@testable import SwiftMarkdownParser

/// Test suite for the SwiftMarkdownParser functionality.
/// 
/// This test suite covers the AST-focused parsing functionality,
/// including parsing various markdown elements and error handling.
struct SwiftMarkdownParserTests {
    
    @Test func test_init_createsParserInstance() async throws {
        // Given & When
        let parser = SwiftMarkdownParser()
        
        // Then
        // Verify that the parser instance was created successfully
        #expect(type(of: parser) == SwiftMarkdownParser.self)
    }
    
    @Test func test_parseToAST_emptyString_returnsEmptyDocument() async throws {
        // Given
        let parser = SwiftMarkdownParser()
        let emptyMarkdown = ""
        
        // When
        let document = try await parser.parseToAST(emptyMarkdown)
        
        // Then
        #expect(type(of: document) == DocumentNode.self)
        #expect(document.children.count == 0) // Empty string should result in empty document
    }
    
    @Test func test_parseToAST_validMarkdown_returnsDocument() async throws {
        // Given
        let parser = SwiftMarkdownParser()
        let markdown = "# Hello World"
        
        // When
        let document = try await parser.parseToAST(markdown)
        
        // Then
        #expect(type(of: document) == DocumentNode.self)
        #expect(document.children.count >= 1) // Should contain at least one element
    }
    
    @Test func test_parseToHTML_simpleMarkdown_returnsHTML() async throws {
        // Given
        let parser = SwiftMarkdownParser()
        let markdown = "**Bold text**"
        
        // When
        let html = try await parser.parseToHTML(markdown)
        
        // Then
        #expect(html.contains("<p"))
        #expect(html.contains("Bold text"))
        #expect(html.contains("</p>"))
    }
    
    // MARK: - AST Node Tests
    
    @Test func test_documentNode_init_createsEmptyDocument() async throws {
        // Given & When
        let document = DocumentNode(children: [])
        
        // Then
        #expect(document.nodeType == .document)
        #expect(document.children.isEmpty)
    }
    
    @Test func test_textNode_init_createsTextNode() async throws {
        // Given
        let text = "Hello, World!"
        
        // When
        let textNode = TextNode(content: text)
        
        // Then
        #expect(textNode.nodeType == .text)
        #expect(textNode.content == text)
        #expect(textNode.children.isEmpty)
    }
    
    @Test func test_headingNode_init_createsHeadingWithLevel() async throws {
        // Given
        let level = 2
        let text = "Test Heading"
        let textNode = TextNode(content: text)
        
        // When
        let heading = HeadingNode(level: level, children: [textNode])
        
        // Then
        #expect(heading.nodeType == .heading)
        #expect(heading.level == level)
        #expect(heading.children.count == 1)
    }
    
    @Test func test_paragraphNode_init_createsParagraph() async throws {
        // Given
        let text = "This is a paragraph."
        let textNode = TextNode(content: text)
        
        // When
        let paragraph = ParagraphNode(children: [textNode])
        
        // Then
        #expect(paragraph.nodeType == .paragraph)
        #expect(paragraph.children.count == 1)
    }
    
    @Test func test_emphasisNode_init_createsEmphasis() async throws {
        // Given
        let text = "italic text"
        let textNode = TextNode(content: text)
        
        // When
        let emphasis = EmphasisNode(children: [textNode])
        
        // Then
        #expect(emphasis.nodeType == .emphasis)
        #expect(emphasis.delimiter == "*")
        #expect(emphasis.children.count == 1)
    }
    
    @Test func test_strongEmphasisNode_init_createsStrongEmphasis() async throws {
        // Given
        let text = "bold text"
        let textNode = TextNode(content: text)
        
        // When
        let strong = StrongEmphasisNode(children: [textNode])
        
        // Then
        #expect(strong.nodeType == .strongEmphasis)
        #expect(strong.delimiter == "*")
        #expect(strong.children.count == 1)
    }
    
    @Test func test_linkNode_init_createsLink() async throws {
        // Given
        let url = "https://swift.org"
        let title = "Swift.org"
        let textNode = TextNode(content: "Swift")
        
        // When
        let link = LinkNode(url: url, title: title, children: [textNode])
        
        // Then
        #expect(link.nodeType == .link)
        #expect(link.url == url)
        #expect(link.title == title)
        #expect(link.children.count == 1)
    }
    
    @Test func test_codeBlockNode_init_createsCodeBlock() async throws {
        // Given
        let content = "let x = 42"
        let language = "swift"
        
        // When
        let codeBlock = CodeBlockNode(content: content, language: language, isFenced: true)
        
        // Then
        #expect(codeBlock.nodeType == .codeBlock)
        #expect(codeBlock.content == content)
        #expect(codeBlock.language == language)
        #expect(codeBlock.isFenced == true)
    }
    
    // MARK: - HTML Renderer Tests
    
    @Test func test_htmlRenderer_renderTextNode_returnsEscapedHTML() async throws {
        // Given
        let renderer = HTMLRenderer()
        let textNode = TextNode(content: "Hello & <world>")
        
        // When
        let html = try await renderer.render(node: textNode)
        
        // Then
        #expect(html == "Hello &amp; &lt;world&gt;")
    }
    
    @Test func test_htmlRenderer_renderParagraphNode_returnsWrappedHTML() async throws {
        // Given
        let renderer = HTMLRenderer()
        let textNode = TextNode(content: "Hello, World!")
        let paragraph = ParagraphNode(children: [textNode])
        
        // When
        let html = try await renderer.render(node: paragraph)
        
        // Then
        #expect(html.contains("<p"))
        #expect(html.contains("Hello, World!"))
        #expect(html.contains("</p>"))
    }
    
    @Test func test_htmlRenderer_renderHeadingNode_returnsHeadingHTML() async throws {
        // Given
        let renderer = HTMLRenderer()
        let textNode = TextNode(content: "Test Heading")
        let heading = HeadingNode(level: 2, children: [textNode])
        
        // When
        let html = try await renderer.render(node: heading)
        
        // Then
        #expect(html.contains("<h2"))
        #expect(html.contains("Test Heading"))
        #expect(html.contains("</h2>"))
    }
    
    @Test func test_htmlRenderer_renderLinkNode_returnsLinkHTML() async throws {
        // Given
        let renderer = HTMLRenderer()
        let textNode = TextNode(content: "Swift")
        let link = LinkNode(url: "https://swift.org", title: "Swift.org", children: [textNode])
        
        // When
        let html = try await renderer.render(node: link)
        
        // Then
        #expect(html.contains("<a"))
        #expect(html.contains("href=\"https://swift.org\""))
        #expect(html.contains("title=\"Swift.org\""))
        #expect(html.contains("Swift"))
        #expect(html.contains("</a>"))
    }
    
    // MARK: - Error Handling Tests
    
    @Test func test_markdownParserError_invalidInput_hasCorrectDescription() async throws {
        // Given
        let error = MarkdownParserError.invalidInput("Test message")
        
        // When
        let description = error.errorDescription
        
        // Then
        #expect(description?.contains("Invalid input") == true)
        #expect(description?.contains("Test message") == true)
    }
    
    @Test func test_markdownParserError_nestingTooDeep_hasCorrectDescription() async throws {
        // Given
        let depth = 150
        let error = MarkdownParserError.nestingTooDeep(depth)
        
        // When
        let description = error.errorDescription
        
        // Then
        #expect(description?.contains("Nesting too deep") == true)
        #expect(description?.contains("150") == true)
    }
    
    @Test func test_rendererError_unsupportedNodeType_hasCorrectDescription() async throws {
        // Given
        let error = RendererError.unsupportedNodeType(.document)
        
        // When
        let description = error.errorDescription
        
        // Then
        #expect(description?.contains("Unsupported AST node type") == true)
        #expect(description?.contains("document") == true)
    }
    
    // MARK: - Utility Tests
    
    @Test func test_rendererUtils_escapeHTML_escapesSpecialCharacters() async throws {
        // Given
        let input = "Hello & <world> \"quoted\" 'text'"
        
        // When
        let escaped = RendererUtils.escapeHTML(input)
        
        // Then
        #expect(escaped == "Hello &amp; &lt;world&gt; &quot;quoted&quot; &#39;text&#39;")
    }
    
    @Test func test_rendererUtils_normalizeURL_rejectsJavaScript() async throws {
        // Given
        let jsURL = "javascript:alert('xss')"
        
        // When
        let normalized = RendererUtils.normalizeURL(jsURL)
        
        // Then
        #expect(normalized == nil)
    }
    
    @Test func test_rendererUtils_normalizeURL_acceptsHTTPS() async throws {
        // Given
        let httpsURL = "https://example.com"
        
        // When
        let normalized = RendererUtils.normalizeURL(httpsURL)
        
        // Then
        #expect(normalized == httpsURL)
    }
}
