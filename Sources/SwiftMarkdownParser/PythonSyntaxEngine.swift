import Foundation

public struct PythonSyntaxEngine: SyntaxHighlightingEngine {
    
    public init() {}
    
    public func highlight(_ code: String, language: String) async throws -> [SyntaxToken] {
        guard supportedLanguages().contains(language.lowercased()) else {
            throw SyntaxHighlightingError.unsupportedLanguage(language)
        }
        
        return try await tokenize(code)
    }
    
    public func supportedLanguages() -> Set<String> {
        return Set(["python", "py"])
    }
    
    private func tokenize(_ code: String) async throws -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var currentIndex = code.startIndex
        
        while currentIndex < code.endIndex {
            let char = code[currentIndex]
            
            // Skip whitespace
            if char.isWhitespace {
                currentIndex = code.index(after: currentIndex)
                continue
            }
            
            // Comments
            if char == "#" {
                if let token = try parseComment(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Strings
            if char == "\"" || char == "'" {
                if let token = try parseString(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Numbers
            if char.isNumber {
                if let token = try parseNumber(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Identifiers and keywords
            if char.isLetter || char == "_" {
                if let token = try parseIdentifier(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Operators and punctuation
            if let token = try parseOperatorOrPunctuation(code, startIndex: currentIndex) {
                tokens.append(token)
                currentIndex = token.range.upperBound
                continue
            }
            
            // Fallback: single character as plain text
            let endIndex = code.index(after: currentIndex)
            let content = String(code[currentIndex..<endIndex])
            tokens.append(SyntaxToken(content: content, tokenType: .plain, range: currentIndex..<endIndex))
            currentIndex = endIndex
        }
        
        return tokens
    }
    
    // MARK: - Parsing Methods
    
    private func parseComment(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex] == "#" else { return nil }
        
        var endIndex = startIndex
        while endIndex < code.endIndex && code[endIndex] != "\n" {
            endIndex = code.index(after: endIndex)
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .comment, range: startIndex..<endIndex)
    }
    
    private func parseString(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex else { return nil }
        
        let quoteChar = code[startIndex]
        guard quoteChar == "\"" || quoteChar == "'" else { return nil }
        
        // Check for triple quotes
        // Ensure at least three characters remain so we can safely look ahead
        let remainingCount = code.distance(from: startIndex, to: code.endIndex)
        if remainingCount >= 3 {
            if let tripleQuoteEnd = code.index(startIndex, offsetBy: 3, limitedBy: code.endIndex) {
                let firstThree = String(code[startIndex..<tripleQuoteEnd])
                if firstThree == String(repeating: String(quoteChar), count: 3) {
                    return parseTripleQuotedString(code, startIndex: startIndex, quoteChar: quoteChar)
                }
            }
        }
        
        // Regular string
        var currentIndex = code.index(after: startIndex)
        while currentIndex < code.endIndex {
            let char = code[currentIndex]
            if char == quoteChar {
                currentIndex = code.index(after: currentIndex)
                break
            }
            if char == "\\" {
                let nextIndex = code.index(after: currentIndex)
                if nextIndex < code.endIndex {
                    currentIndex = nextIndex
                }
            }
            currentIndex = code.index(after: currentIndex)
        }
        
        let content = String(code[startIndex..<currentIndex])
        return SyntaxToken(content: content, tokenType: .string, range: startIndex..<currentIndex)
    }
    
    private func parseTripleQuotedString(_ code: String, startIndex: String.Index, quoteChar: Character) -> SyntaxToken? {
        let tripleQuote = String(repeating: String(quoteChar), count: 3)
        guard let tripleQuoteEnd = code.index(startIndex, offsetBy: 3, limitedBy: code.endIndex) else {
            return nil
        }
        var currentIndex = tripleQuoteEnd

        // Traverse the string safely until we find the terminating triple quote or reach the end.
        // Walk through the source until we either encounter a terminating triple quote
        // or exhaust the input, guaranteeing that unclosed strings include every
        // remaining character in the resulting token.
        while currentIndex < code.endIndex {
            if code[currentIndex...].hasPrefix(tripleQuote) {
                if let newIndex = code.index(currentIndex, offsetBy: 3, limitedBy: code.endIndex) {
                    currentIndex = newIndex
                } else {
                    currentIndex = code.endIndex
                }
                break
            }
            currentIndex = code.index(after: currentIndex)
        }
        
        let content = String(code[startIndex..<currentIndex])
        return SyntaxToken(content: content, tokenType: .string, range: startIndex..<currentIndex)
    }
    
    private func parseNumber(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex].isNumber else { return nil }
        
        var currentIndex = startIndex
        
        // Handle hex numbers
        if currentIndex < code.endIndex && code[currentIndex] == "0" {
            let nextIndex = code.index(after: currentIndex)
            if nextIndex < code.endIndex && (code[nextIndex] == "x" || code[nextIndex] == "X") {
                currentIndex = code.index(nextIndex, offsetBy: 1)
                
                while currentIndex < code.endIndex && code[currentIndex].isHexDigit {
                    currentIndex = code.index(after: currentIndex)
                }
                
                let content = String(code[startIndex..<currentIndex])
                return SyntaxToken(content: content, tokenType: .number, range: startIndex..<currentIndex)
            }
        }
        
        // Regular numbers
        while currentIndex < code.endIndex && (code[currentIndex].isNumber || code[currentIndex] == ".") {
            currentIndex = code.index(after: currentIndex)
        }
        
        // Handle scientific notation
        if currentIndex < code.endIndex && (code[currentIndex] == "e" || code[currentIndex] == "E") {
            currentIndex = code.index(after: currentIndex)
            if currentIndex < code.endIndex && (code[currentIndex] == "+" || code[currentIndex] == "-") {
                currentIndex = code.index(after: currentIndex)
            }
            while currentIndex < code.endIndex && code[currentIndex].isNumber {
                currentIndex = code.index(after: currentIndex)
            }
        }
        
        let content = String(code[startIndex..<currentIndex])
        return SyntaxToken(content: content, tokenType: .number, range: startIndex..<currentIndex)
    }
    
    private func parseIdentifier(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && (code[startIndex].isLetter || code[startIndex] == "_") else { return nil }
        
        var currentIndex = startIndex
        while currentIndex < code.endIndex && (code[currentIndex].isLetter || code[currentIndex].isNumber || code[currentIndex] == "_") {
            currentIndex = code.index(after: currentIndex)
        }
        
        let content = String(code[startIndex..<currentIndex])
        let tokenType = classifyIdentifier(content)
        
        return SyntaxToken(content: content, tokenType: tokenType, range: startIndex..<currentIndex)
    }
    
    private func parseOperatorOrPunctuation(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex else { return nil }
        
        let remainingString = String(code[startIndex...])
        
        // Multi-character operators (check longer ones first)
        let multiCharOperators = ["==", "!=", "<=", ">=", "//", "**", "<<", ">>", "+=", "-=", "*=", "/=", "%=", "//=", "**=", "&=", "|=", "^=", ">>=", "<<="]
        for op in multiCharOperators {
            if remainingString.hasPrefix(op) {
                let endIndex = code.index(startIndex, offsetBy: op.count)
                return SyntaxToken(content: op, tokenType: .`operator`, range: startIndex..<endIndex)
            }
        }
        
        // Single character operators
        let singleCharOperators: Set<Character> = ["+", "-", "*", "/", "%", "=", "!", "<", ">", "&", "|", "^", "~", "@"]
        if singleCharOperators.contains(code[startIndex]) {
            let content = String(code[startIndex])
            let endIndex = code.index(after: startIndex)
            return SyntaxToken(content: content, tokenType: .`operator`, range: startIndex..<endIndex)
        }
        
        // Punctuation
        let punctuation: Set<Character> = ["(", ")", "[", "]", "{", "}", ",", ";", ".", ":", "?"]
        if punctuation.contains(code[startIndex]) {
            let content = String(code[startIndex])
            let endIndex = code.index(after: startIndex)
            return SyntaxToken(content: content, tokenType: .punctuation, range: startIndex..<endIndex)
        }
        
        return nil
    }
    
    private func classifyIdentifier(_ content: String) -> SyntaxTokenType {
        // Keywords
        if pythonKeywords.contains(content) {
            return .keyword
        }
        
        // Built-in functions
        if pythonBuiltins.contains(content) {
            return .builtin
        }
        
        // Built-in types
        if pythonTypes.contains(content) {
            return .type
        }
        
        // Constants
        if pythonConstants.contains(content) {
            return .constant
        }
        
        return .identifier
    }
    
    // MARK: - Python Language Definitions
    
    private let pythonKeywords: Set<String> = [
        "and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del",
        "elif", "else", "except", "finally", "for", "from", "global", "if", "import", "in",
        "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try", "while",
        "with", "yield", "False", "None", "True"
    ]
    
    private let pythonBuiltins: Set<String> = [
        "abs", "all", "any", "ascii", "bin", "bool", "bytearray", "bytes", "callable", "chr",
        "classmethod", "compile", "complex", "delattr", "dict", "dir", "divmod", "enumerate",
        "eval", "exec", "filter", "float", "format", "frozenset", "getattr", "globals", "hasattr",
        "hash", "help", "hex", "id", "input", "int", "isinstance", "issubclass", "iter", "len",
        "list", "locals", "map", "max", "memoryview", "min", "next", "object", "oct", "open",
        "ord", "pow", "print", "property", "range", "repr", "reversed", "round", "set", "setattr",
        "slice", "sorted", "staticmethod", "str", "sum", "super", "tuple", "type", "vars", "zip"
    ]
    
    private let pythonTypes: Set<String> = [
        "int", "float", "str", "bool", "list", "dict", "tuple", "set", "frozenset", "bytes",
        "bytearray", "memoryview", "complex", "object", "type", "slice", "range", "enumerate",
        "zip", "map", "filter", "reversed", "sorted"
    ]
    
    private let pythonConstants: Set<String> = [
        "True", "False", "None", "__debug__", "NotImplemented", "Ellipsis"
    ]
} 