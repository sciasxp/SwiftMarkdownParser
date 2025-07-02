import Testing
@testable import SwiftMarkdownParser

/// Test suite for the SwiftMarkdownParser functionality.
/// 
/// This test suite covers the basic functionality of the markdown parser,
/// including parsing various markdown elements and error handling.
struct SwiftMarkdownParserTests {
    
    @Test func test_init_createsParserInstance() async throws {
        // Given & When
        let parser = SwiftMarkdownParser()
        
        // Then
        // Verify that the parser instance was created successfully
        #expect(type(of: parser) == SwiftMarkdownParser.self)
    }
    
    @Test func test_parse_emptyString_returnsEmptyDocument() async throws {
        // Given
        let parser = SwiftMarkdownParser()
        let emptyMarkdown = ""
        
        // When
        let document = try parser.parse(emptyMarkdown)
        
        // Then
        #expect(document.elements.isEmpty)
    }
    
    @Test func test_parse_validMarkdown_returnsDocument() async throws {
        // Given
        let parser = SwiftMarkdownParser()
        let markdown = "# Hello World"
        
        // When
        let document = try parser.parse(markdown)
        
        // Then
        #expect(type(of: document) == MarkdownDocument.self)
    }
    
    @Test func test_markdownDocument_init_createsEmptyDocument() async throws {
        // Given & When
        let document = MarkdownDocument()
        
        // Then
        #expect(document.elements.isEmpty)
    }
    
    @Test func test_markdownDocument_addElement_addsElementToDocument() async throws {
        // Given
        var document = MarkdownDocument()
        let element = MarkdownElement.heading(level: 1, text: "Test")
        
        // When
        document.addElement(element)
        
        // Then
        #expect(document.elements.count == 1)
        if case .heading(let level, let text) = document.elements[0] {
            #expect(level == 1)
            #expect(text == "Test")
        } else {
            #expect(Bool(false), "Expected heading element")
        }
    }
    
    @Test func test_markdownElement_heading_storesCorrectData() async throws {
        // Given
        let level = 2
        let text = "Sample Heading"
        
        // When
        let element = MarkdownElement.heading(level: level, text: text)
        
        // Then
        if case .heading(let storedLevel, let storedText) = element {
            #expect(storedLevel == level)
            #expect(storedText == text)
        } else {
            #expect(Bool(false), "Expected heading element")
        }
    }
    
    @Test func test_markdownElement_paragraph_storesCorrectData() async throws {
        // Given
        let text = "This is a paragraph."
        
        // When
        let element = MarkdownElement.paragraph(text: text)
        
        // Then
        if case .paragraph(let storedText) = element {
            #expect(storedText == text)
        } else {
            #expect(Bool(false), "Expected paragraph element")
        }
    }
    
    @Test func test_markdownParseError_invalidInput_hasCorrectDescription() async throws {
        // Given
        let error = MarkdownParseError.invalidInput
        
        // When
        let description = error.errorDescription
        
        // Then
        #expect(description == "The provided input is not valid Markdown")
    }
    
    @Test func test_markdownParseError_unsupportedElement_hasCorrectDescription() async throws {
        // Given
        let elementName = "custom-element"
        let error = MarkdownParseError.unsupportedElement(elementName)
        
        // When
        let description = error.errorDescription
        
        // Then
        #expect(description == "Unsupported Markdown element: \(elementName)")
    }
    
    @Test func test_markdownParseError_parsingFailed_hasCorrectDescription() async throws {
        // Given
        let reason = "Invalid syntax"
        let error = MarkdownParseError.parsingFailed(reason)
        
        // When
        let description = error.errorDescription
        
        // Then
        #expect(description == "Parsing failed: \(reason)")
    }
}
