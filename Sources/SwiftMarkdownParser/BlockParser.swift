/// Block parser for converting tokens into block-level AST nodes
/// 
/// This parser handles container blocks (block quotes, lists) and leaf blocks
/// (headings, paragraphs, code blocks) according to the CommonMark specification.
import Foundation

// MARK: - Block Parser

/// Parser for block-level markdown elements
public final class BlockParser {
    
    private let tokenStream: TokenStream
    private let configuration: SwiftMarkdownParser.Configuration
    private var linkReferences: [String: LinkReference] = [:]
    
    /// Initialize with token stream and configuration
    public init(tokenStream: TokenStream, configuration: SwiftMarkdownParser.Configuration) {
        self.tokenStream = tokenStream
        self.configuration = configuration
    }
    
    /// Parse the token stream into a document AST
    public func parseDocument() throws -> DocumentNode {
        var blocks: [ASTNode] = []
        
        // Skip leading whitespace and newlines
        skipWhitespaceAndNewlines()
        
        while !tokenStream.isAtEnd {
            if let block = try parseBlock() {
                blocks.append(block)
            }
            skipWhitespaceAndNewlines()
        }
        
        // Create document with link references
        let document = DocumentNode(children: blocks)
        return document
    }
    
    /// Parse a single block element
    private func parseBlock() throws -> ASTNode? {
        // Skip whitespace at start of line
        skipWhitespace()
        
        guard !tokenStream.isAtEnd else { return nil }
        
        let token = tokenStream.current
        
        switch token.type {
        case .atxHeaderStart:
            return try parseATXHeading()
            
        case .blockQuoteMarker:
            return try parseBlockQuote()
            
        case .listMarker:
            return try parseList()
            
        case .backtick, .tildeCodeFence:
            if token.content.count >= 3 {
                return try parseFencedCodeBlock()
            }
            fallthrough
            
        case .indentedCodeBlock:
            return try parseIndentedCodeBlock()
            
        case .thematicBreak:
            return parseThematicBreak()
            
        case .htmlTag:
            return try parseHTMLBlock()
            
        case .newline:
            // Empty line - skip
            tokenStream.advance()
            return nil
            
        default:
            // Check for setext heading
            if let setextHeading = try parseSetextHeading() {
                return setextHeading
            }
            
            // Default to paragraph
            return try parseParagraph()
        }
    }
    
    // MARK: - Heading Parsers
    
    private func parseATXHeading() throws -> HeadingNode {
        let startLocation = tokenStream.current.location
        let headerToken = tokenStream.consume()
        let level = headerToken.content.count
        
        // Skip whitespace after #
        skipWhitespace()
        
        // Parse inline content until end of line
        var children: [ASTNode] = []
        var textContent = ""
        
        while !tokenStream.isAtEnd && !tokenStream.check(.newline) {
            let token = tokenStream.consume()
            if token.type == .text || token.type == .whitespace {
                textContent += token.content
            }
            // TODO: Parse inline elements here
        }
        
        // Remove trailing # characters and whitespace
        textContent = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if textContent.hasSuffix("#") {
            textContent = String(textContent.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if !textContent.isEmpty {
            children.append(TextNode(content: textContent, sourceLocation: startLocation))
        }
        
        return HeadingNode(
            level: level,
            isSetext: false,
            children: children,
            sourceLocation: startLocation
        )
    }
    
    private func parseSetextHeading() throws -> HeadingNode? {
        // Look ahead to see if next line is setext underline
        let startPosition = tokenStream.currentPosition
        
        // Parse potential heading text
        var textTokens: [Token] = []
        while !tokenStream.isAtEnd && !tokenStream.check(.newline) {
            textTokens.append(tokenStream.consume())
        }
        
        // Must have newline
        guard tokenStream.match(.newline) else {
            // Backtrack
            tokenStream.setPosition(startPosition)
            return nil
        }
        
        // Check for underline
        guard !tokenStream.isAtEnd else {
            tokenStream.setPosition(startPosition)
            return nil
        }
        
        let underlineToken = tokenStream.current
        let isLevel1 = underlineToken.content.contains("=")
        let isLevel2 = underlineToken.content.contains("-")
        
        guard isLevel1 || isLevel2 else {
            tokenStream.setPosition(startPosition)
            return nil
        }
        
        // Consume underline
        tokenStream.advance()
        
        // Create heading
        let textContent = textTokens.map { $0.content }.joined()
        let children = [TextNode(content: textContent.trimmingCharacters(in: .whitespacesAndNewlines))]
        
        return HeadingNode(
            level: isLevel1 ? 1 : 2,
            isSetext: true,
            children: children,
            sourceLocation: textTokens.first?.location
        )
    }
    
    // MARK: - Block Quote Parser
    
    private func parseBlockQuote() throws -> BlockQuoteNode {
        let startLocation = tokenStream.current.location
        var children: [ASTNode] = []
        
        while !tokenStream.isAtEnd && tokenStream.check(.blockQuoteMarker) {
            tokenStream.advance() // consume >
            skipWhitespace()
            
            // Parse the content of this line
            if let block = try parseBlock() {
                children.append(block)
            }
            
            // Look for continuation
            skipWhitespaceAndNewlines()
        }
        
        return BlockQuoteNode(children: children, sourceLocation: startLocation)
    }
    
    // MARK: - List Parsers
    
    private func parseList() throws -> ListNode {
        let startLocation = tokenStream.current.location
        let firstMarker = tokenStream.current.content
        
        let isOrdered = firstMarker.last == "." || firstMarker.last == ")"
        let startNumber = isOrdered ? Int(firstMarker.dropLast()) : nil
        let delimiter = isOrdered ? firstMarker.last : nil
        let bulletChar = isOrdered ? nil : firstMarker.first
        
        var items: [ASTNode] = []
        
        while !tokenStream.isAtEnd && tokenStream.check(.listMarker) {
            let marker = tokenStream.current.content
            
            // Check if this marker matches the list type
            let markerIsOrdered = marker.last == "." || marker.last == ")"
            if markerIsOrdered != isOrdered {
                break
            }
            
            if isOrdered {
                if marker.last != delimiter {
                    break
                }
            } else {
                if marker.first != bulletChar {
                    break
                }
            }
            
            // Parse list item
            let item = try parseListItem()
            items.append(item)
            
            skipWhitespaceAndNewlines()
        }
        
        return ListNode(
            isOrdered: isOrdered,
            startNumber: startNumber,
            delimiter: delimiter,
            bulletChar: bulletChar,
            isTight: true, // TODO: Implement tight vs loose detection
            children: items,
            sourceLocation: startLocation
        )
    }
    
    private func parseListItem() throws -> ListItemNode {
        let startLocation = tokenStream.current.location
        
        // Consume list marker
        tokenStream.advance()
        skipWhitespace()
        
        var children: [ASTNode] = []
        
        // Parse content until next list item or end
        while !tokenStream.isAtEnd && !isNextListItem() {
            if let block = try parseBlock() {
                children.append(block)
            } else {
                break
            }
        }
        
        return ListItemNode(children: children, sourceLocation: startLocation)
    }
    
    private func isNextListItem() -> Bool {
        // Look ahead to see if we have a list marker at start of line
        let currentPos = tokenStream.currentPosition
        
        // Skip newlines and whitespace
        while !tokenStream.isAtEnd && (tokenStream.check(.newline) || tokenStream.check(.whitespace)) {
            tokenStream.advance()
        }
        
        let isListItem = tokenStream.check(.listMarker)
        
        // Restore position
        tokenStream.setPosition(currentPos)
        
        return isListItem
    }
    
    // MARK: - Code Block Parsers
    
    private func parseFencedCodeBlock() throws -> CodeBlockNode {
        let startLocation = tokenStream.current.location
        let fenceToken = tokenStream.consume()
        let fenceChar = fenceToken.content.first!
        let fenceLength = fenceToken.content.count
        
        // Parse language info
        var language: String?
        var infoString = ""
        
        while !tokenStream.isAtEnd && !tokenStream.check(.newline) {
            infoString += tokenStream.consume().content
        }
        
        if !infoString.isEmpty {
            language = infoString.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces).first
        }
        
        // Skip newline after opening fence
        _ = tokenStream.match(.newline)
        
        // Collect code content
        var content = ""
        
        while !tokenStream.isAtEnd {
            // Check for closing fence
            if tokenStream.check(.backtick) || tokenStream.check(.tildeCodeFence) {
                let closingToken = tokenStream.current
                if closingToken.content.first == fenceChar && closingToken.content.count >= fenceLength {
                    tokenStream.advance()
                    break
                }
            }
            
            if tokenStream.check(.newline) {
                content += "\n"
            } else {
                content += tokenStream.current.content
            }
            tokenStream.advance()
        }
        
        return CodeBlockNode(
            content: content,
            language: language,
            isFenced: true,
            fenceChar: fenceChar,
            sourceLocation: startLocation
        )
    }
    
    private func parseIndentedCodeBlock() throws -> CodeBlockNode {
        let startLocation = tokenStream.current.location
        var content = ""
        
        while !tokenStream.isAtEnd && tokenStream.check(.indentedCodeBlock) {
            _ = tokenStream.consume()
            
            // Collect rest of line
            var lineContent = ""
            while !tokenStream.isAtEnd && !tokenStream.check(.newline) {
                lineContent += tokenStream.consume().content
            }
            
            content += lineContent
            
            if tokenStream.match(.newline) {
                content += "\n"
            }
        }
        
        return CodeBlockNode(
            content: content,
            language: nil,
            isFenced: false,
            sourceLocation: startLocation
        )
    }
    
    // MARK: - Other Block Parsers
    
    private func parseThematicBreak() -> ThematicBreakNode {
        let startLocation = tokenStream.current.location
        let token = tokenStream.consume()
        let character = token.content.first { !$0.isWhitespace } ?? "-"
        
        return ThematicBreakNode(character: character, sourceLocation: startLocation)
    }
    
    private func parseHTMLBlock() throws -> HTMLBlockNode {
        let startLocation = tokenStream.current.location
        var content = ""
        
        // Simple HTML block parsing - collect until blank line
        while !tokenStream.isAtEnd {
            let token = tokenStream.consume()
            content += token.content
            
            if token.type == .newline {
                // Check if next line is blank
                if tokenStream.check(.newline) {
                    break
                }
            }
        }
        
        return HTMLBlockNode(
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            htmlType: .element, // TODO: Implement proper HTML type detection
            sourceLocation: startLocation
        )
    }
    
    private func parseParagraph() throws -> ParagraphNode {
        let startLocation = tokenStream.current.location
        var children: [ASTNode] = []
        var textContent = ""
        
        // Collect text until blank line or block element
        while !tokenStream.isAtEnd && !isBlockBoundary() {
            let token = tokenStream.consume()
            
            switch token.type {
            case .text, .whitespace:
                textContent += token.content
            case .newline:
                // Single newline becomes space in paragraph
                if !textContent.isEmpty && !textContent.hasSuffix(" ") {
                    textContent += " "
                }
            default:
                // TODO: Handle inline elements
                textContent += token.content
            }
        }
        
        textContent = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !textContent.isEmpty {
            children.append(TextNode(content: textContent, sourceLocation: startLocation))
        }
        
        return ParagraphNode(children: children, sourceLocation: startLocation)
    }
    
    private func isBlockBoundary() -> Bool {
        let token = tokenStream.current
        
        switch token.type {
        case .newline:
            // Check if followed by another newline (blank line)
            return tokenStream.peek().type == .newline
        case .atxHeaderStart, .blockQuoteMarker, .listMarker, .thematicBreak:
            return true
        case .backtick, .tildeCodeFence:
            return token.content.count >= 3
        case .indentedCodeBlock:
            return true
        case .eof:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Utility Methods
    
    private func skipWhitespace() {
        while tokenStream.check(.whitespace) {
            tokenStream.advance()
        }
    }
    
    private func skipWhitespaceAndNewlines() {
        while tokenStream.check(.whitespace) || tokenStream.check(.newline) {
            tokenStream.advance()
        }
    }
}

 