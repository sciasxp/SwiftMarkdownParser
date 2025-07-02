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
        
        while !tokenStream.isAtEnd && !boundary.contains(tokenStream.current.type) {
            if let node = try parseInline() {
                nodes.append(node)
            }
        }
        
        return nodes
    }
    
    /// Parse a single inline element
    private func parseInline() throws -> ASTNode? {
        let token = tokenStream.current
        
        switch token.type {
        case .text:
            return parseText()
            
        case .whitespace:
            return parseWhitespace()
            
        case .asterisk:
            return try parseEmphasisOrStrong(delimiter: "*")
            
        case .underscore:
            return try parseEmphasisOrStrong(delimiter: "_")
            
        case .backtick:
            return try parseCodeSpan()
            
        case .leftBracket:
            return try parseLinkOrImage()
            
        case .exclamation:
            if tokenStream.peek().type == .leftBracket {
                return try parseImage()
            }
            return parseText()
            
        case .backslash:
            return parseEscapedCharacter()
            
        case .entity:
            return parseEntity()
            
        case .autolink:
            return parseAutolink()
            
        case .tilde:
            if configuration.enableGFMExtensions {
                return try parseStrikethrough()
            }
            return parseText()
            
        case .htmlTag:
            return parseHTMLInline()
            
        case .hardBreak:
            return parseHardBreak()
            
        case .softBreak:
            return parseSoftBreak()
            
        default:
            // Treat as text
            return parseText()
        }
    }
    
    // MARK: - Text and Whitespace
    
    private func parseText() -> TextNode {
        let token = tokenStream.consume()
        return TextNode(content: token.content, sourceLocation: token.location)
    }
    
    private func parseWhitespace() -> TextNode {
        let token = tokenStream.consume()
        return TextNode(content: token.content, sourceLocation: token.location)
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
                    
                    return StrongEmphasisNode(
                        children: content,
                        delimiter: delimiterChar,
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
                    
                    return EmphasisNode(
                        children: content,
                        delimiter: delimiterChar,
                        sourceLocation: startLocation
                    )
                }
                
                // Not enough closing delimiters, restore position and continue
                tokenStream.setPosition(closingPosition)
            }
            
            // Parse content
            if let inline = try parseInline() {
                content.append(inline)
            }
        }
        
        // No closing delimiters found, treat as regular text
        tokenStream.setPosition(startPosition)
        return parseText()
    }
    
    // MARK: - Code Spans
    
    private func parseCodeSpan() throws -> CodeSpanNode? {
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
        
        return CodeSpanNode(content: content, sourceLocation: startLocation)
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
            if let inline = try parseInline() {
                linkText.append(inline)
            }
        }
        
        guard tokenStream.match(.rightBracket) else {
            // No closing bracket, treat as text
            return parseText()
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
            if let textNode = node as? TextNode {
                return textNode.content
            }
            return nil
        }.joined()
        
        if let reference = linkReferences[refLabel.lowercased()] {
            if isImage {
                return ImageNode(
                    url: reference.url,
                    title: reference.title,
                    isReference: true,
                    referenceLabel: refLabel,
                    children: linkText,
                    sourceLocation: startLocation
                )
            } else {
                return LinkNode(
                    url: reference.url,
                    title: reference.title,
                    isReference: true,
                    referenceLabel: refLabel,
                    children: linkText,
                    sourceLocation: startLocation
                )
            }
        }
        
        // Not a valid link, treat as text
        return parseText()
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
            return ImageNode(
                url: url,
                title: title,
                children: linkText,
                sourceLocation: startLocation
            )
        } else {
            return LinkNode(
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
                if let textNode = node as? TextNode {
                    return textNode.content
                }
                return nil
            }.joined()
        }
        
        guard let reference = linkReferences[refLabel.lowercased()] else {
            return nil
        }
        
        if isImage {
            return ImageNode(
                url: reference.url,
                title: reference.title,
                isReference: true,
                referenceLabel: refLabel,
                children: linkText,
                sourceLocation: startLocation
            )
        } else {
            return LinkNode(
                url: reference.url,
                title: reference.title,
                isReference: true,
                referenceLabel: refLabel,
                children: linkText,
                sourceLocation: startLocation
            )
        }
    }
    
    // MARK: - Other Inline Elements
    
    private func parseEscapedCharacter() -> ASTNode {
        let token = tokenStream.consume()
        
        // Remove the backslash and return the escaped character
        let escapedContent = token.content.count > 1 ? String(token.content.dropFirst()) : ""
        return TextNode(content: escapedContent, sourceLocation: token.location)
    }
    
    private func parseEntity() -> ASTNode {
        let token = tokenStream.consume()
        
        // TODO: Implement proper entity decoding
        // For now, return the entity as-is
        return TextNode(content: token.content, sourceLocation: token.location)
    }
    
    private func parseAutolink() -> AutolinkNode {
        let token = tokenStream.consume()
        let url = token.content
        
        let linkType: AutolinkType
        if url.contains("@") {
            linkType = .email
        } else if url.hasPrefix("http://") || url.hasPrefix("https://") {
            linkType = .protocol
        } else if url.hasPrefix("www.") {
            linkType = .www
        } else {
            linkType = .url
        }
        
        return AutolinkNode(url: url, linkType: linkType, sourceLocation: token.location)
    }
    
    private func parseStrikethrough() throws -> ASTNode? {
        guard configuration.enableGFMExtensions else { return parseText() }
        
        let startLocation = tokenStream.current.location
        
        // Need at least ~~
        guard tokenStream.current.content.count >= 2 else { return parseText() }
        
        tokenStream.advance() // consume opening ~~
        
        var content: [ASTNode] = []
        var foundClosing = false
        
        while !tokenStream.isAtEnd {
            if tokenStream.current.type == .tilde && tokenStream.current.content.count >= 2 {
                tokenStream.advance()
                foundClosing = true
                break
            }
            
            if let inline = try parseInline() {
                content.append(inline)
            }
        }
        
        guard foundClosing else {
            // No closing ~~, treat as text
            return parseText()
        }
        
        return StrikethroughNode(children: content, sourceLocation: startLocation)
    }
    
    private func parseHTMLInline() -> HTMLInlineNode {
        let token = tokenStream.consume()
        return HTMLInlineNode(content: token.content, sourceLocation: token.location)
    }
    
    private func parseHardBreak() -> LineBreakNode {
        let token = tokenStream.consume()
        return LineBreakNode(isHard: true, sourceLocation: token.location)
    }
    
    private func parseSoftBreak() -> SoftBreakNode {
        let token = tokenStream.consume()
        return SoftBreakNode(sourceLocation: token.location)
    }
    
    // MARK: - Link References
    
    /// Set link references for resolving reference links
    public func setLinkReferences(_ references: [String: LinkReference]) {
        self.linkReferences = references
    }
} 