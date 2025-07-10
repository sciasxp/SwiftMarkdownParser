/// Tokenizer for breaking markdown text into structured tokens
/// 
/// This tokenizer performs lexical analysis on markdown text, converting
/// it into a stream of tokens that can be consumed by the parser.
import Foundation

// MARK: - Token Types

/// Represents a single token in the markdown text
public struct Token: Sendable, Equatable {
    /// The type of the token
    public let type: TokenType
    
    /// The raw content of the token
    public let content: String
    
    /// Source location of the token
    public let location: SourceLocation
    
    /// Length of the token in characters
    public let length: Int
    
    public init(type: TokenType, content: String, location: SourceLocation) {
        self.type = type
        self.content = content
        self.location = location
        self.length = content.count
    }
}

/// Types of tokens that can be found in markdown
public enum TokenType: String, CaseIterable, Sendable, Equatable {
    // Text content
    case text
    case whitespace
    case newline
    
    // Headers
    case atxHeaderStart        // # ## ### etc.
    case setextHeaderUnderline // === or ---
    
    // Emphasis and strong
    case asterisk              // *
    case underscore            // _
    
    // Links and images
    case leftBracket          // [
    case rightBracket         // ]
    case leftParen            // (
    case rightParen           // )
    case exclamation          // !
    
    // Code
    case backtick             // `
    case tildeCodeFence       // ~
    case indentedCodeBlock    // 4+ spaces at line start
    
    // Lists
    case listMarker           // - + * or 1. 2) etc.
    
    // Block quotes
    case blockQuoteMarker     // >
    
    // Thematic breaks
    case thematicBreak        // --- *** ___
    
    // HTML
    case htmlTag              // <tag> </tag>
    case htmlComment          // <!-- -->
    
    // Tables (GFM)
    case pipe                 // |
    case tableAlignment       // :---: :--- ---:
    
    // Strikethrough (GFM)
    case tilde                // ~
    
    // Task lists (GFM)
    case taskListMarker       // [x] [ ]
    
    // URLs and emails (GFM)
    case autolink             // http://... or email@...
    
    // Escapes
    case backslash            // \
    case entity               // &amp; &#39; etc.
    
    // Line endings
    case hardBreak            // two spaces + newline
    case softBreak            // single newline
    
    // Special
    case eof                  // End of file
}

// MARK: - Tokenizer

/// Lexical analyzer for markdown text
public final class MarkdownTokenizer {
    
    private let input: String
    private let characters: [Character]
    private var position: Int = 0
    private var line: Int = 1
    private var column: Int = 1
    
    // State tracking for fenced code blocks
    private var inFencedCodeBlock: Bool = false
    private var fenceCharacter: Character? = nil
    private var fenceLength: Int = 0
    private var fenceStartColumn: Int = 0
    
    /// Initialize tokenizer with markdown text
    public init(_ input: String) {
        self.input = input
        self.characters = Array(input)
    }
    
    /// Tokenize the entire input into a sequence of tokens
    public func tokenize() -> [Token] {
        var tokens: [Token] = []
        
        while !isAtEnd {
            if let token = nextToken() {
                tokens.append(token)
            }
        }
        
        // Add EOF token
        tokens.append(Token(
            type: .eof,
            content: "",
            location: currentLocation
        ))
        
        return tokens
    }
    
    /// Get the next token from the input
    private func nextToken() -> Token? {
        // Skip to next meaningful character
        let startLocation = currentLocation
        
        guard !isAtEnd else { return nil }
        
        let char = currentChar
        
        // Handle newlines first
        if char == "\n" {
            advance()
            return Token(type: .newline, content: "\n", location: startLocation)
        }
        
        if char == "\r" {
            advance()
            if currentChar == "\n" {
                advance()
            }
            return Token(type: .newline, content: "\r\n", location: startLocation)
        }
        
        // Check for fenced code block state first
        if inFencedCodeBlock {
            // Attempt to detect a closing fence (allowing up to 3 leading spaces)
            if let closingFence = checkClosingFenceAllowingIndentation() {
                inFencedCodeBlock = false
                fenceCharacter = nil
                fenceLength = 0
                fenceStartColumn = 0
                return closingFence
            }

            // Otherwise, treat everything as text inside the code block
            return tokenizeTextInCodeBlock()
        }
        
        // Check for line-start patterns (headers, lists, block quotes, etc.)
        if column == 1 || isAfterWhitespace() {
            if let lineStartToken = checkLineStartPatterns() {
                return lineStartToken
            }
        }
        
        // Handle whitespace
        if char.isWhitespace && char != "\n" && char != "\r" {
            return tokenizeWhitespace()
        }
        
        // Handle special characters
        switch char {
        case "*":
            return tokenizeAsterisk()
        case "_":
            return tokenizeUnderscore()
        case "#":
            return tokenizeHash()
        case "`":
            return tokenizeBacktick()
        case "~":
            return tokenizeTilde()
        case "[":
            return tokenizeLeftBracket()
        case "]":
            return tokenizeRightBracket()
        case "(":
            advance()
            return Token(type: .leftParen, content: "(", location: startLocation)
        case ")":
            advance()
            return Token(type: .rightParen, content: ")", location: startLocation)
        case "!":
            return tokenizeExclamation()
        case ">":
            return tokenizeBlockQuote()
        case "|":
            advance()
            return Token(type: .pipe, content: "|", location: startLocation)
        case "\\":
            return tokenizeBackslash()
        case "&":
            return tokenizeEntity()
        case "<":
            return tokenizeHTMLOrAutolink()
        case "-":
            return tokenizeDashOrList()
        case "+":
            return tokenizePlusOrList()
        default:
            // Check for numbered list
            if char.isNumber {
                if let listToken = tokenizeNumberedList() {
                    return listToken
                }
            }
            
            // Default to text
            return tokenizeText()
        }
    }
    
    // MARK: - Character Navigation
    
    private var currentChar: Character {
        guard position < characters.count else { return "\0" }
        return characters[position]
    }
    
    private func peek(_ offset: Int = 1) -> Character {
        let pos = position + offset
        guard pos < characters.count else { return "\0" }
        return characters[pos]
    }
    
    private var isAtEnd: Bool {
        return position >= characters.count
    }
    
    private func advance() {
        guard position < characters.count else { return }
        
        if characters[position] == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        
        position += 1
    }
    
    private var currentLocation: SourceLocation {
        return SourceLocation(line: line, column: column, offset: position)
    }
    
    private func isAfterWhitespace() -> Bool {
        guard position > 0 else { return true }
        let prevChar = characters[position - 1]
        return prevChar.isWhitespace
    }
    
    // MARK: - Token Recognition Methods
    
    private func checkLineStartPatterns() -> Token? {
        
        // Check for ATX headers (# ## ###)
        if currentChar == "#" {
            return tokenizeATXHeader()
        }
        
        // Check for block quotes (>)
        if currentChar == ">" {
            return tokenizeBlockQuote()
        }
        
        // Check for list markers (- + * or 1. 2))
        if currentChar == "-" || currentChar == "+" || currentChar == "*" {
            if let listToken = tokenizeListMarker() {
                return listToken
            }
        }
        
        // Check for numbered lists
        if currentChar.isNumber {
            if let listToken = tokenizeNumberedList() {
                return listToken
            }
        }
        
        // Check for thematic breaks (--- *** ___)
        if let thematicBreak = tokenizeThematicBreak() {
            return thematicBreak
        }
        
        // Check for indented code blocks (4+ spaces)
        if currentChar == " " {
            if let codeBlock = tokenizeIndentedCodeBlock() {
                return codeBlock
            }
        }
        
        // Check for fenced code blocks (``` or ~~~)
        if currentChar == "`" || currentChar == "~" {
            if let fenceToken = tokenizeFencedCodeBlock() {
                return fenceToken
            }
        }
        
        return nil
    }
    
    private func tokenizeWhitespace() -> Token {
        let startLocation = currentLocation
        var content = ""
        
        while !isAtEnd && currentChar.isWhitespace && currentChar != "\n" && currentChar != "\r" {
            content.append(currentChar)
            advance()
        }
        
        return Token(type: .whitespace, content: content, location: startLocation)
    }
    
    private func tokenizeText() -> Token {
        let startLocation = currentLocation
        var content = ""
        
        while !isAtEnd && !isSpecialCharacter(currentChar) && currentChar != "\n" && currentChar != "\r" {
            content.append(currentChar)
            advance()
        }
        
        // If we didn't consume any characters, consume at least one to avoid infinite loop
        if content.isEmpty && !isAtEnd {
            content.append(currentChar)
            advance()
        }
        
        return Token(type: .text, content: content, location: startLocation)
    }
    
    private func isSpecialCharacter(_ char: Character) -> Bool {
        return "*_#`~[]()!>|\\&<-+".contains(char) || char.isWhitespace
    }
    
    private func tokenizeAsterisk() -> Token {
        let startLocation = currentLocation
        advance()
        return Token(type: .asterisk, content: "*", location: startLocation)
    }
    
    private func tokenizeUnderscore() -> Token {
        let startLocation = currentLocation
        advance()
        return Token(type: .underscore, content: "_", location: startLocation)
    }
    
    private func tokenizeHash() -> Token {
        let startLocation = currentLocation
        advance()
        return Token(type: .atxHeaderStart, content: "#", location: startLocation)
    }
    
    private func tokenizeATXHeader() -> Token {
        let startLocation = currentLocation
        var content = ""
        
        while !isAtEnd && currentChar == "#" && content.count < 6 {
            content.append(currentChar)
            advance()
        }
        
        // Must be followed by space or end of line
        if !isAtEnd && !currentChar.isWhitespace {
            // Not a header, backtrack and return as text
            position = startLocation.offset
            line = startLocation.line
            column = startLocation.column
            return tokenizeText()
        }
        
        return Token(type: .atxHeaderStart, content: content, location: startLocation)
    }
    
    private func tokenizeBacktick() -> Token {
        let startLocation = currentLocation
        var content = ""
        
        while !isAtEnd && currentChar == "`" {
            content.append(currentChar)
            advance()
        }
        
        return Token(type: .backtick, content: content, location: startLocation)
    }
    
    private func tokenizeTilde() -> Token {
        let startLocation = currentLocation
        var content = ""
        
        while !isAtEnd && currentChar == "~" {
            content.append(currentChar)
            advance()
        }
        
        return Token(type: .tilde, content: content, location: startLocation)
    }
    
    private func tokenizeLeftBracket() -> Token {
        let startLocation = currentLocation
        advance()
        return Token(type: .leftBracket, content: "[", location: startLocation)
    }
    
    private func tokenizeRightBracket() -> Token {
        let startLocation = currentLocation
        advance()
        return Token(type: .rightBracket, content: "]", location: startLocation)
    }
    
    private func tokenizeExclamation() -> Token {
        let startLocation = currentLocation
        advance()
        return Token(type: .exclamation, content: "!", location: startLocation)
    }
    
    private func tokenizeBlockQuote() -> Token {
        let startLocation = currentLocation
        advance()
        return Token(type: .blockQuoteMarker, content: ">", location: startLocation)
    }
    
    private func tokenizeBackslash() -> Token {
        let startLocation = currentLocation
        var content = ""
        content.append(currentChar)
        advance()
        
        // Include the escaped character if present
        if !isAtEnd {
            content.append(currentChar)
            advance()
        }
        
        return Token(type: .backslash, content: content, location: startLocation)
    }
    
    private func tokenizeEntity() -> Token {
        let startLocation = currentLocation
        var content = ""
        
        content.append(currentChar) // &
        advance()
        
        // Read until ; or whitespace
        while !isAtEnd && currentChar != ";" && !currentChar.isWhitespace {
            content.append(currentChar)
            advance()
        }
        
        if currentChar == ";" {
            content.append(currentChar)
            advance()
        }
        
        return Token(type: .entity, content: content, location: startLocation)
    }
    
    private func tokenizeHTMLOrAutolink() -> Token {
        
        // Check if this looks like an HTML tag
        if isHTMLTag() {
            return tokenizeHTMLTag()
        }
        
        // Check if this looks like an autolink
        if isAutolink() {
            return tokenizeAutolink()
        }
        
        // Default to text
        return tokenizeText()
    }
    
    private func isHTMLTag() -> Bool {
        guard currentChar == "<" else { return false }
        
        var pos = position + 1
        guard pos < characters.count else { return false }
        
        // Check for closing tag
        if characters[pos] == "/" {
            pos += 1
        }
        
        // Must start with letter
        guard pos < characters.count && characters[pos].isLetter else { return false }
        
        // Look for closing >
        while pos < characters.count && characters[pos] != ">" {
            pos += 1
        }
        
        return pos < characters.count && characters[pos] == ">"
    }
    
    private func tokenizeHTMLTag() -> Token {
        let startLocation = currentLocation
        var content = ""
        
        while !isAtEnd && currentChar != ">" {
            content.append(currentChar)
            advance()
        }
        
        if currentChar == ">" {
            content.append(currentChar)
            advance()
        }
        
        return Token(type: .htmlTag, content: content, location: startLocation)
    }
    
    private func isAutolink() -> Bool {
        // Simple check for http:// https:// or email patterns
        let remaining = String(characters[position...])
        return remaining.hasPrefix("http://") || 
               remaining.hasPrefix("https://") || 
               remaining.contains("@")
    }
    
    private func tokenizeAutolink() -> Token {
        let startLocation = currentLocation
        var content = ""
        
        // Read until whitespace or special character
        while !isAtEnd && !currentChar.isWhitespace && !"[]()".contains(currentChar) {
            content.append(currentChar)
            advance()
        }
        
        return Token(type: .autolink, content: content, location: startLocation)
    }
    
    private func tokenizeDashOrList() -> Token {
        
        // Check if this is a list marker
        if let listToken = tokenizeListMarker() {
            return listToken
        }
        
        // Check if this is a thematic break
        if let thematicBreak = tokenizeThematicBreak() {
            return thematicBreak
        }
        
        // Default to text
        return tokenizeText()
    }
    
    private func tokenizePlusOrList() -> Token {
        
        // Check if this is a list marker
        if let listToken = tokenizeListMarker() {
            return listToken
        }
        
        // Default to text
        return tokenizeText()
    }
    
    private func tokenizeListMarker() -> Token? {
        let startLocation = currentLocation
        let char = currentChar
        
        guard char == "-" || char == "+" || char == "*" else { return nil }
        
        advance()
        
        // Must be followed by whitespace
        if !isAtEnd && !currentChar.isWhitespace {
            // Not a list marker, backtrack
            position = startLocation.offset
            line = startLocation.line
            column = startLocation.column
            return nil
        }
        
        return Token(type: .listMarker, content: String(char), location: startLocation)
    }
    
    private func tokenizeNumberedList() -> Token? {
        let startLocation = currentLocation
        var content = ""
        
        // Read digits
        while !isAtEnd && currentChar.isNumber && content.count < 9 {
            content.append(currentChar)
            advance()
        }
        
        // Must be followed by . or )
        guard !isAtEnd && (currentChar == "." || currentChar == ")") else {
            // Not a numbered list, backtrack
            position = startLocation.offset
            line = startLocation.line
            column = startLocation.column
            return nil
        }
        
        content.append(currentChar)
        advance()
        
        // Must be followed by whitespace
        if !isAtEnd && !currentChar.isWhitespace {
            // Not a list marker, backtrack
            position = startLocation.offset
            line = startLocation.line
            column = startLocation.column
            return nil
        }
        
        return Token(type: .listMarker, content: content, location: startLocation)
    }
    
    private func tokenizeThematicBreak() -> Token? {
        let startLocation = currentLocation
        let char = currentChar
        
        guard char == "-" || char == "*" || char == "_" else { return nil }
        
        var count = 0
        var pos = position
        
        // Count consecutive characters, allowing spaces
        while pos < characters.count {
            let c = characters[pos]
            if c == char {
                count += 1
            } else if c == " " || c == "\t" {
                // Spaces are allowed
            } else if c == "\n" || c == "\r" {
                break
            } else {
                // Other characters break the pattern
                return nil
            }
            pos += 1
        }
        
        // Must have at least 3 characters
        guard count >= 3 else { return nil }
        
        // Consume the entire line
        var content = ""
        while !isAtEnd && currentChar != "\n" && currentChar != "\r" {
            content.append(currentChar)
            advance()
        }
        
        return Token(type: .thematicBreak, content: content, location: startLocation)
    }
    
    private func tokenizeIndentedCodeBlock() -> Token? {
        let startLocation = currentLocation
        var spaceCount = 0
        
        // Count leading spaces
        while !isAtEnd && currentChar == " " {
            spaceCount += 1
            advance()
        }
        
        // Must have at least 4 spaces
        guard spaceCount >= 4 else {
            // Backtrack
            position = startLocation.offset
            line = startLocation.line
            column = startLocation.column
            return nil
        }
        
        return Token(type: .indentedCodeBlock, content: String(repeating: " ", count: spaceCount), location: startLocation)
    }
    
    private func tokenizeFencedCodeBlock() -> Token? {
        let startLocation = currentLocation
        let fenceChar = currentChar
        var content = ""
        
        // Count fence characters
        while !isAtEnd && currentChar == fenceChar {
            content.append(currentChar)
            advance()
        }
        
        // Must have at least 3 characters
        guard content.count >= 3 else {
            // Backtrack
            position = startLocation.offset
            line = startLocation.line
            column = startLocation.column
            return nil
        }
        
        // Set fenced code block state
        inFencedCodeBlock = true
        fenceCharacter = fenceChar
        fenceLength = content.count
        fenceStartColumn = startLocation.column
        
        let tokenType: TokenType = fenceChar == "`" ? .backtick : .tildeCodeFence
        return Token(type: tokenType, content: content, location: startLocation)
    }
    
    private func checkClosingFence() -> Token? {
        let startLocation = currentLocation
        let char = currentChar
        
        guard char == fenceCharacter else { return nil }
        
        var content = ""
        var count = 0
        
        // Count fence characters
        while !isAtEnd && currentChar == char {
            content.append(currentChar)
            count += 1
            advance()
        }
        
        // Must have at least the same length as opening fence
        guard count >= fenceLength else {
            // Backtrack - this is not a closing fence
            position = startLocation.offset
            line = startLocation.line
            column = startLocation.column
            return nil
        }
        
        // Check that this is followed by end of line or whitespace only
        // This ensures we don't close on fence characters that are part of content
        var tempPos = position
        
        while tempPos < characters.count && characters[tempPos] != "\n" && characters[tempPos] != "\r" {
            if !characters[tempPos].isWhitespace {
                // There's non-whitespace content after the fence, so this is not a closing fence
                position = startLocation.offset
                line = startLocation.line
                column = startLocation.column
                return nil
            }
            tempPos += 1
        }
        
        let tokenType: TokenType = char == "`" ? .backtick : .tildeCodeFence
        return Token(type: tokenType, content: content, location: startLocation)
    }
    
    private func tokenizeTextInCodeBlock() -> Token {
        let startLocation = currentLocation
        var content = ""
        
        // The main `nextToken` loop has already checked for a valid closing fence.
        // Therefore, any character that is not a newline should be consumed as
        // part of the code block's content. This includes ` and ~ characters
        // that do not form a valid closing fence.
        while !isAtEnd && currentChar != "\n" && currentChar != "\r" {
            content.append(currentChar)
            advance()
        }
        
        return Token(type: .text, content: content, location: startLocation)
    }
    
    /// Attempt to detect a closing code fence that may be indented by up to three leading spaces.
    /// This ensures that we can preserve whitespace inside code blocks while still correctly
    /// terminating the fenced block when the specification allows indentation.
    private func checkClosingFenceAllowingIndentation() -> Token? {
        // Fast-path: if the current character is the fence character, rely on the existing logic.
        if (currentChar == "`" || currentChar == "~") && isAtLineStart() {
            return checkClosingFence()
        }

        // Only attempt this check if we're at the start of a line (or only preceded by whitespace)
        guard isAtLineStart() else { return nil }

        // Save the current parser state in case this isn't a closing fence
        let originalPosition = position
        let originalLine = line
        let originalColumn = column

        // Skip up to three leading spaces or tabs
        var spacesSkipped = 0
        while spacesSkipped < 3 && !isAtEnd {
            if currentChar == " " || currentChar == "\t" {
                advance()
                spacesSkipped += 1
            } else {
                break
            }
        }

        // After skipping, the next character must match the opening fence character
        if (currentChar == "`" || currentChar == "~") {
            // Delegate to existing fence-checking logic.
            if let fence = checkClosingFence() {
                return fence
            }
        }

        // Not a closing fence – restore state and return nil.
        position = originalPosition
        line = originalLine
        column = originalColumn
        return nil
    }

    private func isAtLineStart() -> Bool {
        // Check if we're at the actual start of a line (column 1)
        // or if we're after whitespace at the start of a line
        if column == 1 {
            return true
        }
        
        // Check if all characters before this on the current line are whitespace
        var pos = position - 1
        while pos >= 0 && characters[pos] != "\n" && characters[pos] != "\r" {
            if !characters[pos].isWhitespace {
                return false
            }
            pos -= 1
        }
        return true
    }
}

// MARK: - Token Stream

/// A stream of tokens that can be consumed by the parser
public final class TokenStream {
    private let tokens: [Token]
    private var position: Int = 0
    
    public init(_ tokens: [Token]) {
        self.tokens = tokens
    }
    
    /// Current token
    public var current: Token {
        guard position < tokens.count else { 
            return Token(type: .eof, content: "", location: SourceLocation(line: 0, column: 0, offset: 0))
        }
        return tokens[position]
    }
    
    /// Peek at the next token
    public func peek(_ offset: Int = 1) -> Token {
        let pos = position + offset
        guard pos >= 0 && pos < tokens.count else {
            return Token(type: .eof, content: "", location: SourceLocation(line: 0, column: 0, offset: 0))
        }
        return tokens[pos]
    }
    
    /// Advance to the next token
    public func advance() {
        if position < tokens.count {
            position += 1
        }
    }
    
    /// Check if we're at the end
    public var isAtEnd: Bool {
        return position >= tokens.count || current.type == .eof
    }
    
    /// Consume and return the current token
    public func consume() -> Token {
        let token = current
        advance()
        return token
    }
    
    /// Check if current token matches the given type
    public func check(_ type: TokenType) -> Bool {
        return current.type == type
    }
    
    /// Consume token if it matches the given type
    public func match(_ types: TokenType...) -> Bool {
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        return false
    }
    
    /// Current position in the token stream (for backtracking)
    public var currentPosition: Int {
        return position
    }
    
    /// Set position in the token stream (for backtracking)
    public func setPosition(_ pos: Int) {
        position = max(0, min(pos, tokens.count))
    }
} 