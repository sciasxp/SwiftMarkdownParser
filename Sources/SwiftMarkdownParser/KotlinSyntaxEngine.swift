import Foundation

public struct KotlinSyntaxEngine: SyntaxHighlightingEngine {
    
    public init() {}
    
    public func highlight(_ code: String, language: String) async throws -> [SyntaxToken] {
        guard supportedLanguages().contains(language.lowercased()) else {
            throw SyntaxHighlightingError.unsupportedLanguage(language)
        }
        
        return try await tokenize(code)
    }
    
    public func supportedLanguages() -> Set<String> {
        return Set(["kotlin", "kt"])
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
            if char == "/" && currentIndex < code.index(before: code.endIndex) {
                let nextChar = code[code.index(after: currentIndex)]
                if nextChar == "/" {
                    // Single-line comment
                    if let token = try parseLineComment(code, startIndex: currentIndex) {
                        tokens.append(token)
                        currentIndex = token.range.upperBound
                        continue
                    }
                } else if nextChar == "*" {
                    // Multi-line comment
                    if let token = try parseBlockComment(code, startIndex: currentIndex) {
                        tokens.append(token)
                        currentIndex = token.range.upperBound
                        continue
                    }
                }
            }
            
            // Strings
            if char == "\"" {
                if let token = try parseString(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            if char == "'" {
                if let token = try parseCharacter(code, startIndex: currentIndex) {
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
                if let token = try parseIdentifier(code, startIndex: currentIndex, previousToken: tokens.last) {
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
    
    private func parseLineComment(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex] == "/" else { return nil }
        
        let nextIndex = code.index(after: startIndex)
        guard nextIndex < code.endIndex && code[nextIndex] == "/" else { return nil }
        
        var endIndex = nextIndex
        while endIndex < code.endIndex && code[endIndex] != "\n" {
            endIndex = code.index(after: endIndex)
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .comment, range: startIndex..<endIndex)
    }
    
    private func parseBlockComment(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex] == "/" else { return nil }
        
        let nextIndex = code.index(after: startIndex)
        guard nextIndex < code.endIndex && code[nextIndex] == "*" else { return nil }
        
        var endIndex = code.index(after: nextIndex)
        
        // Iterate until we find a terminating "*/" or reach the end of the input.
        // By not imposing a look-ahead constraint, we guarantee that an unclosed
        // block comment token spans the entire remainder of the source.
        while endIndex < code.endIndex {
            if code[endIndex...].hasPrefix("*/") {
                if let newIndex = code.index(endIndex, offsetBy: 2, limitedBy: code.endIndex) {
                    endIndex = newIndex
                } else {
                    endIndex = code.endIndex
                }
                break
            }
            endIndex = code.index(after: endIndex)
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .comment, range: startIndex..<endIndex)
    }
    
    private func parseString(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex] == "\"" else { return nil }
        
        var currentIndex = code.index(after: startIndex)
        while currentIndex < code.endIndex {
            let char = code[currentIndex]
            if char == "\"" {
                currentIndex = code.index(after: currentIndex)
                break
            }
            if char == "\\" && currentIndex < code.index(before: code.endIndex) {
                currentIndex = code.index(after: currentIndex)
            }
            currentIndex = code.index(after: currentIndex)
        }
        
        let content = String(code[startIndex..<currentIndex])
        return SyntaxToken(content: content, tokenType: .string, range: startIndex..<currentIndex)
    }
    
    private func parseCharacter(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex] == "'" else { return nil }
        
        var currentIndex = code.index(after: startIndex)
        while currentIndex < code.endIndex {
            let char = code[currentIndex]
            if char == "'" {
                currentIndex = code.index(after: currentIndex)
                break
            }
            if char == "\\" && currentIndex < code.index(before: code.endIndex) {
                currentIndex = code.index(after: currentIndex)
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
        
        // Handle suffixes like L, f, d
        if currentIndex < code.endIndex && ["L", "f", "d", "F", "D"].contains(String(code[currentIndex])) {
            currentIndex = code.index(after: currentIndex)
        }
        
        let content = String(code[startIndex..<currentIndex])
        return SyntaxToken(content: content, tokenType: .number, range: startIndex..<currentIndex)
    }
    
    private func parseIdentifier(_ code: String, startIndex: String.Index, previousToken: SyntaxToken?) throws -> SyntaxToken? {
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
        let multiCharOperators = ["?:", "!!", "?."]
        for op in multiCharOperators {
            if remainingString.hasPrefix(op) {
                let endIndex = code.index(startIndex, offsetBy: op.count)
                return SyntaxToken(content: op, tokenType: .`operator`, range: startIndex..<endIndex)
            }
        }
        
        // Single character operators
        let singleCharOperators: Set<Character> = ["+", "-", "*", "/", "%", "=", "!", "<", ">", "&", "|", "^", "~", "?", ":"]
        if singleCharOperators.contains(code[startIndex]) {
            let content = String(code[startIndex])
            let endIndex = code.index(after: startIndex)
            return SyntaxToken(content: content, tokenType: .`operator`, range: startIndex..<endIndex)
        }
        
        // Punctuation
        let punctuation: Set<Character> = ["(", ")", "[", "]", "{", "}", ",", ";", ".", "@"]
        if punctuation.contains(code[startIndex]) {
            let content = String(code[startIndex])
            let endIndex = code.index(after: startIndex)
            return SyntaxToken(content: content, tokenType: .punctuation, range: startIndex..<endIndex)
        }
        
        return nil
    }
    
    private func classifyIdentifier(_ content: String) -> SyntaxTokenType {
        // Keywords
        if kotlinKeywords.contains(content) {
            return .keyword
        }
        
        // Modifiers
        if kotlinModifiers.contains(content) {
            return .modifier
        }
        
        // Built-in types
        if kotlinTypes.contains(content) {
            return .type
        }
        
        // Built-in functions
        if kotlinBuiltins.contains(content) {
            return .function
        }
        
        // Check if it's a type (starts with uppercase)
        if content.first?.isUppercase == true {
            return .type
        }
        
        return .identifier
    }
    
    // MARK: - Kotlin Language Definitions
    
    private let kotlinKeywords: Set<String> = [
        "as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if",
        "in", "interface", "is", "null", "object", "package", "return", "super", "this",
        "throw", "true", "try", "typealias", "typeof", "val", "var", "when", "while",
        "by", "catch", "constructor", "delegate", "dynamic", "field", "file", "finally",
        "get", "import", "init", "param", "property", "receiver", "set", "setparam",
        "where", "actual", "abstract", "annotation", "companion", "const", "crossinline",
        "expect", "external", "final", "infix", "inline", "inner", "internal", "lateinit",
        "noinline", "open", "operator", "out", "override", "private", "protected", "public",
        "reified", "sealed", "suspend", "tailrec", "vararg", "enum"
    ]
    
    private let kotlinModifiers: Set<String> = [
        "data", "abstract", "final", "open", "override", "private", "protected", "public",
        "internal", "inner", "sealed", "enum", "annotation", "companion", "inline",
        "noinline", "crossinline", "reified", "external", "suspend", "tailrec", "operator",
        "infix", "lateinit", "const", "actual", "expect"
    ]
    
    private let kotlinTypes: Set<String> = [
        "Any", "Nothing", "Unit", "Boolean", "Byte", "Short", "Int", "Long", "Float", "Double",
        "Char", "String", "Array", "List", "MutableList", "Set", "MutableSet", "Map", "MutableMap",
        "Collection", "Iterable", "Iterator", "Sequence", "Pair", "Triple", "Result", "Throwable",
        "Exception", "RuntimeException", "Error", "AssertionError", "OutOfMemoryError",
        "StackOverflowError", "ClassCastException", "IllegalArgumentException", "IllegalStateException",
        "IndexOutOfBoundsException", "KotlinNullPointerException", "NoSuchElementException",
        "NumberFormatException", "UnsupportedOperationException"
    ]
    
    private let kotlinBuiltins: Set<String> = [
        "println", "print", "readLine", "TODO", "require", "requireNotNull", "check", "checkNotNull",
        "error", "assert", "let", "run", "with", "apply", "also", "takeIf", "takeUnless", "repeat",
        "lazy", "lazyOf", "emptyList", "listOf", "mutableListOf", "emptySet", "setOf", "mutableSetOf",
        "emptyMap", "mapOf", "mutableMapOf", "arrayOf", "intArrayOf", "doubleArrayOf", "booleanArrayOf",
        "charArrayOf", "longArrayOf", "floatArrayOf", "shortArrayOf", "byteArrayOf", "emptyArray",
        "withContext", "async", "launch", "runBlocking", "delay", "yield", "isActive", "ensureActive"
    ]
} 