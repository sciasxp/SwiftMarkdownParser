/// Inline parser for converting tokens into inline AST nodes
/// 
/// This parser handles inline elements like emphasis, strong emphasis,
/// links, images, code spans, and other inline formatting.
import Foundation

// MARK: - Inline Parser

/// Parser for inline markdown elements
public final class InlineParser {
    
    private let tokenStream: TokenStream
    private let configuration: SwiftMarkdownParser.Configuration
    private var linkReferences: [String: LinkReference] = [:]
    
    /// Initialize with token stream and configuration
    public init(tokenStream: TokenStream, configuration: SwiftMarkdownParser.Configuration) {
        self.tokenStream = tokenStream
        self.configuration = configuration
    }
    
    /// Parse inline content from current position until specified boundary
    public func parseInlines(until boundary: Set<TokenType> = [.newline, .eof]) throws -> [ASTNode] {
        var nodes: [ASTNode] = []
        
        // Protection mechanisms
        var lastTokenPosition = -1
        var stuckPositionCount = 0
        let maxStuckPositions = 10 // Prevent infinite loops from position not advancing
        
        let startTime = Date()
        let maxParsingTime = configuration.maxParsingTime
        
        while !tokenStream.isAtEnd && !boundary.contains(tokenStream.current.type) {
            // Time-based protection
            if maxParsingTime > 0 && Date().timeIntervalSince(startTime) > maxParsingTime {
                throw MarkdownParsingError.parsingFailed("Inline parsing timeout: document too complex or infinite loop detected")
            }
            
            // Position-based protection (detect if parser is stuck)
            let currentPosition = tokenStream.currentPosition
            if currentPosition == lastTokenPosition {
                stuckPositionCount += 1
                if stuckPositionCount >= maxStuckPositions {
                    throw MarkdownParsingError.parsingFailed("Inline parser stuck: infinite loop detected at token position \(currentPosition)")
                }
            } else {
                stuckPositionCount = 0
                lastTokenPosition = currentPosition
            }
            
            let parsedNodes = try parseInline()
            nodes.append(contentsOf: parsedNodes)
        }
        
        return nodes
    }
    
    /// Parse inline content from a text string
    public func parseInlineContent(_ text: String) throws -> [ASTNode] {
        let inlineTokenizer = MarkdownTokenizer(text)
        let inlineTokenStream = TokenStream(inlineTokenizer.tokenize())
        
        // Create a single parser instance for the entire text
        let tempParser = InlineParser(tokenStream: inlineTokenStream, configuration: configuration)
        
        var nodes: [ASTNode] = []
        
        // Protection mechanisms
        var lastTokenPosition = -1
        var stuckPositionCount = 0
        let maxStuckPositions = 10 // Prevent infinite loops from position not advancing
        
        let startTime = Date()
        let maxParsingTime = configuration.maxParsingTime
        
        while !inlineTokenStream.isAtEnd {
            // Time-based protection
            if maxParsingTime > 0 && Date().timeIntervalSince(startTime) > maxParsingTime {
                throw MarkdownParsingError.parsingFailed("Inline content parsing timeout: document too complex or infinite loop detected")
            }
            
            // Position-based protection (detect if parser is stuck)
            let currentPosition = inlineTokenStream.currentPosition
            if currentPosition == lastTokenPosition {
                stuckPositionCount += 1
                if stuckPositionCount >= maxStuckPositions {
                    throw MarkdownParsingError.parsingFailed("Inline content parser stuck: infinite loop detected at token position \(currentPosition)")
                }
            } else {
                stuckPositionCount = 0
                lastTokenPosition = currentPosition
            }
            
            let parsedNodes = try tempParser.parseInline()
            nodes.append(contentsOf: parsedNodes)
        }
        return nodes
    }
    
    /// Parse a single inline element
    private func parseInline() throws -> [ASTNode] {
        let token = tokenStream.current
        switch token.type {
        case .text, .whitespace:
            return [AST.TextNode(content: tokenStream.consume().content)]
        case .asterisk:
            // Handle emphasis and strong emphasis with *
            if let emphasisNode = try parseEmphasisOrStrong(delimiter: "*") {
                return [emphasisNode]
            } else {
                return [AST.TextNode(content: tokenStream.consume().content)]
            }
        case .underscore:
            // Handle emphasis and strong emphasis with _
            if let emphasisNode = try parseEmphasisOrStrong(delimiter: "_") {
                return [emphasisNode]
            } else {
                return [AST.TextNode(content: tokenStream.consume().content)]
            }
        case .backtick:
            // Handle code spans
            if let codeSpan = try parseCodeSpan() {
                return [codeSpan]
            } else {
                return [AST.TextNode(content: tokenStream.consume().content)]
            }
        case .leftBracket:
            // Handle links
            if let link = try parseLinkOrImage() {
                return [link]
            } else {
                return [AST.TextNode(content: tokenStream.consume().content)]
            }
        case .exclamation:
            // Handle images
            if let image = try parseImage() {
                return [image]
            } else {
                return [AST.TextNode(content: tokenStream.consume().content)]
            }
        case .tilde:
            // Handle strikethrough
            if let strikethrough = try parseStrikethrough() {
                return [strikethrough]
            } else {
                return [AST.TextNode(content: tokenStream.consume().content)]
            }
        case .autolink:
            // Handle autolinks
            if let autolink = parseAutolink() {
                return [autolink]
            } else {
                return [AST.TextNode(content: tokenStream.consume().content)]
            }
        case .backslash:
            // Handle escaped characters
            if let escaped = parseEscapedCharacter() {
                return [escaped]
            } else {
                return [AST.TextNode(content: tokenStream.consume().content)]
            }
        default:
            // For other tokens, treat as text
            return [AST.TextNode(content: tokenStream.consume().content)]
        }
    }
    
    // MARK: - Text and Whitespace
    
    private func parseText() -> AST.TextNode {
        let token = tokenStream.consume()
        return AST.TextNode(content: token.content, sourceLocation: token.location)
    }
    
    private func parseWhitespace() -> AST.TextNode {
        let token = tokenStream.consume()
        return AST.TextNode(content: token.content, sourceLocation: token.location)
    }
    
    // MARK: - Emphasis and Strong Emphasis
    
    private func parseEmphasisOrStrong(delimiter: String) throws -> ASTNode? {
        let startLocation = tokenStream.current.location
        let delimiterChar = Character(delimiter)
        
        // Count consecutive delimiters
        var delimiterCount = 0
        let startPosition = tokenStream.currentPosition
        
        while !tokenStream.isAtEnd && 
              (tokenStream.current.type == .asterisk || tokenStream.current.type == .underscore) &&
              tokenStream.current.content.first == delimiterChar {
            delimiterCount += tokenStream.current.content.count
            tokenStream.advance()
        }
        
        // Need at least 1 delimiter
        guard delimiterCount > 0 else {
            tokenStream.setPosition(startPosition)
            return parseText()
        }
        
        // Look for closing delimiters
        var content: [ASTNode] = []
        
        while !tokenStream.isAtEnd {
            // Check for closing delimiters
            if (tokenStream.current.type == .asterisk || tokenStream.current.type == .underscore) &&
               tokenStream.current.content.first == delimiterChar {
                
                // Count closing delimiters
                var closingCount = 0
                let closingPosition = tokenStream.currentPosition
                
                while !tokenStream.isAtEnd && 
                      (tokenStream.current.type == .asterisk || tokenStream.current.type == .underscore) &&
                      tokenStream.current.content.first == delimiterChar {
                    closingCount += tokenStream.current.content.count
                    tokenStream.advance()
                }
                
                // Strong emphasis (2+ delimiters)
                if delimiterCount >= 2 && closingCount >= 2 {
                    // Put back extra delimiters
                    let extraDelimiters = closingCount - 2
                    if extraDelimiters > 0 {
                        tokenStream.setPosition(tokenStream.currentPosition - 1)
                    }
                    
                    return AST.StrongEmphasisNode(
                        children: content,
                        sourceLocation: startLocation
                    )
                }
                
                // Emphasis (1 delimiter)
                if delimiterCount >= 1 && closingCount >= 1 {
                    // Put back extra delimiters
                    let extraDelimiters = closingCount - 1
                    if extraDelimiters > 0 {
                        tokenStream.setPosition(tokenStream.currentPosition - 1)
                    }
                    
                    return AST.EmphasisNode(
                        children: content,
                        sourceLocation: startLocation
                    )
                }
                
                // Not enough closing delimiters, restore position and continue
                tokenStream.setPosition(closingPosition)
            }
            
            // Parse content
            let inlineNodes = try parseInline()
            for inline in inlineNodes {
                if let fragment = inline as? AST.FragmentNode {
                    content.append(contentsOf: fragment.children)
                } else {
                    content.append(inline)
                }
            }
        }
        
        // No closing delimiters found, treat as regular text
        tokenStream.setPosition(startPosition)
        return parseText()
    }
    
    // MARK: - Code Spans
    
    private func parseCodeSpan() throws -> AST.CodeSpanNode? {
        let startLocation = tokenStream.current.location
        let openingToken = tokenStream.consume()
        let backtickCount = openingToken.content.count
        
        var content = ""
        var foundClosing = false
        
        while !tokenStream.isAtEnd {
            let token = tokenStream.current
            
            if token.type == .backtick && token.content.count == backtickCount {
                tokenStream.advance()
                foundClosing = true
                break
            }
            
            content += token.content
            tokenStream.advance()
        }
        
        guard foundClosing else {
            // No closing backticks, treat as regular text
            return nil
        }
        
        // Trim one space from each end if present
        if content.hasPrefix(" ") && content.hasSuffix(" ") && content.count > 2 {
            content = String(content.dropFirst().dropLast())
        }
        
        return AST.CodeSpanNode(content: content, sourceLocation: startLocation)
    }
    
    // MARK: - Links and Images
    
    private func parseLinkOrImage() throws -> ASTNode? {
        let startLocation = tokenStream.current.location
        
        // Check if this is an image (preceded by !)
        let isImage = tokenStream.currentPosition > 0 && 
                     tokenStream.peek(-1).type == .exclamation
        
        guard tokenStream.match(.leftBracket) else { return parseText() }
        
        // Parse link text/alt text
        var linkText: [ASTNode] = []
        
        while !tokenStream.isAtEnd && !tokenStream.check(.rightBracket) {
            let inlineNodes = try parseInline()
            for inline in inlineNodes {
                if let fragment = inline as? AST.FragmentNode {
                    linkText.append(contentsOf: fragment.children)
                } else {
                    linkText.append(inline)
                }
            }
        }
        
        guard tokenStream.match(.rightBracket) else {
            // No closing bracket, treat as text - reconstruct the original content
            let linkTextContent = linkText.compactMap { node in
                if let textNode = node as? AST.TextNode {
                    return textNode.content
                }
                return nil
            }.joined()
            
            return AST.TextNode(content: "[\(linkTextContent)", sourceLocation: startLocation)
        }
        
        // Check for inline link: [text](url "title")
        if tokenStream.check(.leftParen) {
            return try parseInlineLink(linkText: linkText, isImage: isImage, startLocation: startLocation)
        }
        
        // Check for reference link: [text][ref] or [text][]
        if tokenStream.check(.leftBracket) {
            return try parseReferenceLink(linkText: linkText, isImage: isImage, startLocation: startLocation)
        }
        
        // Shortcut reference link: [ref]
        let refLabel = linkText.compactMap { node in
            if let textNode = node as? AST.TextNode {
                return textNode.content
            }
            return nil
        }.joined()
        
        if let reference = linkReferences[refLabel.lowercased()] {
            if isImage {
                return AST.ImageNode(
                    url: reference.url,
                    altText: refLabel,
                    title: reference.title,
                    sourceLocation: startLocation
                )
            } else {
                return AST.LinkNode(
                    url: reference.url,
                    title: reference.title,
                    children: linkText,
                    sourceLocation: startLocation
                )
            }
        }
        
        // Not a valid link, treat as text - reconstruct the original bracket content
        let linkTextContent = linkText.compactMap { node in
            if let textNode = node as? AST.TextNode {
                return textNode.content
            }
            return nil
        }.joined()
        
        return AST.TextNode(content: "[\(linkTextContent)]", sourceLocation: startLocation)
    }
    
    private func parseImage() throws -> ASTNode? {
        guard tokenStream.match(.exclamation) else { return parseText() }
        return try parseLinkOrImage()
    }
    
    private func parseInlineLink(linkText: [ASTNode], isImage: Bool, startLocation: SourceLocation) throws -> ASTNode? {
        guard tokenStream.match(.leftParen) else { return nil }
        
        // Skip whitespace
        while tokenStream.check(.whitespace) {
            tokenStream.advance()
        }
        
        // Parse URL
        var url = ""
        while !tokenStream.isAtEnd && 
              !tokenStream.check(.rightParen) && 
              !tokenStream.check(.whitespace) &&
              tokenStream.current.content != "\"" {
            url += tokenStream.consume().content
        }
        
        // Skip whitespace
        while tokenStream.check(.whitespace) {
            tokenStream.advance()
        }
        
        // Parse optional title
        var title: String?
        if tokenStream.current.content == "\"" {
            tokenStream.advance() // consume opening quote
            var titleContent = ""
            
            while !tokenStream.isAtEnd && tokenStream.current.content != "\"" {
                titleContent += tokenStream.consume().content
            }
            
            if tokenStream.current.content == "\"" {
                tokenStream.advance() // consume closing quote
                title = titleContent
            }
        }
        
        // Skip whitespace
        while tokenStream.check(.whitespace) {
            tokenStream.advance()
        }
        
        guard tokenStream.match(.rightParen) else {
            // Invalid link syntax
            return nil
        }
        
        if isImage {
            // For images, extract alt text from linkText
            let altText = linkText.compactMap { node in
                if let textNode = node as? AST.TextNode {
                    return textNode.content
                }
                return nil
            }.joined()
            
            return AST.ImageNode(
                url: url,
                altText: altText,
                title: title,
                sourceLocation: startLocation
            )
        } else {
            return AST.LinkNode(
                url: url,
                title: title,
                children: linkText,
                sourceLocation: startLocation
            )
        }
    }
    
    private func parseReferenceLink(linkText: [ASTNode], isImage: Bool, startLocation: SourceLocation) throws -> ASTNode? {
        guard tokenStream.match(.leftBracket) else { return nil }
        
        var refLabel = ""
        
        // Parse reference label
        while !tokenStream.isAtEnd && !tokenStream.check(.rightBracket) {
            refLabel += tokenStream.consume().content
        }
        
        guard tokenStream.match(.rightBracket) else { return nil }
        
        // If empty reference, use link text as reference
        if refLabel.isEmpty {
            refLabel = linkText.compactMap { node in
                if let textNode = node as? AST.TextNode {
                    return textNode.content
                }
                return nil
            }.joined()
        }
        
        guard let reference = linkReferences[refLabel.lowercased()] else {
            return nil
        }
        
        if isImage {
            // For images, extract alt text from linkText
            let altText = linkText.compactMap { node in
                if let textNode = node as? AST.TextNode {
                    return textNode.content
                }
                return nil
            }.joined()
            
            return AST.ImageNode(
                url: reference.url,
                altText: altText,
                title: reference.title,
                sourceLocation: startLocation
            )
        } else {
            return AST.LinkNode(
                url: reference.url,
                title: reference.title,
                children: linkText,
                sourceLocation: startLocation
            )
        }
    }
    
    // MARK: - Other Inline Elements
    
    private func parseEscapedCharacter() -> ASTNode? {
        let token = tokenStream.consume()
        
        // Remove the backslash and return the escaped character
        let escapedContent = token.content.count > 1 ? String(token.content.dropFirst()) : ""
        return AST.TextNode(content: escapedContent, sourceLocation: token.location)
    }
    
    private func parseEntity() throws -> ASTNode {
        let token = tokenStream.consume()
        // TODO: Implement proper entity decoding
        // For now, return the entity as-is
        return AST.TextNode(content: token.content, sourceLocation: token.location)
    }
    
    private func parseAutolink() -> AST.AutolinkNode? {
        let token = tokenStream.consume()
        let url = token.content
        
        let displayText = if url.contains("@") {
            url
        } else {
            url
        }
        
        return AST.AutolinkNode(url: url, text: displayText, sourceLocation: token.location)
    }
    
    private func parseStrikethrough() throws -> ASTNode? {
        let startPosition = tokenStream.currentPosition
        let startLocation = tokenStream.current.location
        
        // Check if we have opening ~~
        guard tokenStream.check(.tilde) else { return nil }
        let openingTilde = tokenStream.current
        guard openingTilde.content == "~~" else { 
            // Single tilde, not strikethrough
            return nil 
        }
        
        // Consume the opening ~~
        tokenStream.advance()
        
        var content: [ASTNode] = []
        var foundClosing = false
        
        // Look for closing ~~
        while !tokenStream.isAtEnd {
            if tokenStream.check(.tilde) {
                let closingTilde = tokenStream.current
                if closingTilde.content == "~~" {
                    // Found closing ~~
                    tokenStream.advance()
                    foundClosing = true
                    break
                }
            }
            
            // Add content inside strikethrough
            let token = tokenStream.consume()
            content.append(AST.TextNode(content: token.content, sourceLocation: token.location))
        }
        
        if foundClosing {
            return AST.StrikethroughNode(content: content, sourceLocation: startLocation)
        } else {
            // No closing delimiter found, backtrack and treat as text
            tokenStream.setPosition(startPosition)
            return nil
        }
    }
    
    private func parseHTMLInline() -> AST.HTMLInlineNode {
        let token = tokenStream.consume()
        return AST.HTMLInlineNode(content: token.content, sourceLocation: token.location)
    }
    
    private func parseHardBreak() -> AST.LineBreakNode {
        let token = tokenStream.consume()
        return AST.LineBreakNode(isHard: true, sourceLocation: token.location)
    }
    
    private func parseSoftBreak() -> AST.SoftBreakNode {
        let token = tokenStream.consume()
        return AST.SoftBreakNode(sourceLocation: token.location)
    }
    
    // MARK: - Link References
    
    /// Set link references for resolving reference links
    public func setLinkReferences(_ references: [String: LinkReference]) {
        self.linkReferences = references
    }
} 