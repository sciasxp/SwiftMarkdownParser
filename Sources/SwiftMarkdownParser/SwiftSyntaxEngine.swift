/// Swift syntax highlighting engine
/// 
/// This engine provides comprehensive syntax highlighting for Swift 6
/// with support for modern features like async/await, property wrappers,
/// result builders, string interpolation, and structured concurrency.

import Foundation

/// Swift syntax highlighting engine implementation
public struct SwiftSyntaxEngine: SyntaxHighlightingEngine {
    
    // MARK: - Keywords
    
    private static let keywords: Set<String> = [
        // Core keywords
        "associatedtype", "break", "case", "catch", "class", "continue", "default",
        "defer", "do", "else", "enum", "extension", "fallthrough", "false", "for",
        "func", "guard", "if", "import", "in", "init", "inout", "internal", "is",
        "let", "nil", "operator", "private", "protocol", "public", "repeat", "return",
        "self", "Self", "static", "struct", "subscript", "super", "switch", "throw",
        "throws", "true", "try", "typealias", "var", "where", "while",
        
        // Swift 5.5+ async/await
        "async", "await", "actor", "nonisolated", "isolated",
        
        // Swift 6 features
        "consuming", "borrowing", "sending", "distributed",
        
        // Access control
        "open", "fileprivate", "package",
        
        // Attributes and modifiers
        "final", "lazy", "optional", "required", "weak", "unowned", "mutating",
        "nonmutating", "override", "convenience", "dynamic", "indirect",
        
        // Pattern matching
        "as", "some", "any"
    ]
    
    private static let builtinTypes: Set<String> = [
        // Basic types
        "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
        "Float", "Double", "Bool", "String", "Character", "Void",
        
        // Collection types
        "Array", "Set", "Dictionary", "Optional",
        
        // Foundation types
        "Data", "Date", "URL", "UUID", "NSString", "NSArray", "NSDictionary",
        
        // SwiftUI types
        "View", "State", "Binding", "ObservableObject", "Published", "Environment",
        "EnvironmentObject", "Color", "Text", "Image", "Button", "VStack", "HStack",
        "ZStack", "NavigationView", "List", "Form",
        
        // Concurrency types
        "Task", "TaskGroup", "AsyncSequence", "AsyncIterator", "Sendable",
        
        // Result and error types
        "Result", "Error", "Never"
    ]
    
    private static let builtinFunctions: Set<String> = [
        "print", "debugPrint", "dump", "assert", "assertionFailure", "precondition",
        "preconditionFailure", "fatalError", "min", "max", "abs", "stride", "zip",
        "sequence", "repeatElement", "enumerated", "reversed", "sorted",
        "filter", "reduce", "compactMap", "flatMap", "forEach", "first", "last",
        "contains", "allSatisfy", "isEmpty", "randomElement", "shuffled"
    ]
    
    private static let constants: Set<String> = [
        "true", "false", "nil"
    ]
    
    private static let modifiers: Set<String> = [
        "public", "private", "internal", "fileprivate", "open", "package",
        "static", "class", "final", "override", "required", "convenience",
        "lazy", "weak", "unowned", "mutating", "nonmutating", "dynamic",
        "indirect", "consuming", "borrowing", "sending"
    ]
    
    private static let attributeNames: Set<String> = [
        // Property wrappers
        "State", "Binding", "ObservedObject", "StateObject", "EnvironmentObject",
        "Environment", "Published", "AppStorage", "SceneStorage", "UserDefault",
        
        // Compiler attributes
        "available", "objc", "objcMembers", "discardableResult", "warn_unqualified_access",
        "autoclosure", "escaping", "noescape", "inline", "usableFromInline",
        "inlinable", "frozen", "unknown", "main", "testable", "IBAction", "IBOutlet",
        "IBDesignable", "IBInspectable", "NSManaged", "GKInspectable",
        
        // Result builders
        "resultBuilder", "ViewBuilder", "SceneBuilder", "ToolbarContentBuilder",
        "CommandsBuilder", "WidgetBundleBuilder"
    ]
    
    // MARK: - Public Interface
    
    public init() {}
    
    public func highlight(_ code: String, language: String) async throws -> [SyntaxToken] {
        guard supportedLanguages().contains(language.lowercased()) else {
            throw SyntaxHighlightingError.unsupportedLanguage(language)
        }
        
        return try await tokenize(code)
    }
    
    public func supportedLanguages() -> Set<String> {
        return Set(["swift"])
    }
    
    // MARK: - Tokenization
    
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
            
            // Attributes
            if char == "@" {
                if let token = try parseAttribute(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Strings
            if char == "\"" {
                if let stringTokens = try parseString(code, startIndex: currentIndex) {
                    tokens.append(contentsOf: stringTokens)
                    currentIndex = stringTokens.last?.range.upperBound ?? code.index(after: currentIndex)
                    continue
                }
            }
            
            // Multi-line strings
            if char == "\"" && code.distance(from: currentIndex, to: code.endIndex) >= 3 {
                if let tripleQuoteEnd = code.index(currentIndex, offsetBy: 3, limitedBy: code.endIndex) {
                    let firstThree = String(code[currentIndex..<tripleQuoteEnd])
                    if firstThree == "\"\"\"" {
                        if let token = try parseMultilineString(code, startIndex: currentIndex) {
                            tokens.append(token)
                            currentIndex = token.range.upperBound
                            continue
                        }
                    }
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
            
            // Closure parameters ($0, $1, etc.)
            if char == "$" {
                let nextIndex = code.index(after: currentIndex)
                if nextIndex < code.endIndex && code[nextIndex].isNumber {
                    if let token = try parseClosureParameter(code, startIndex: currentIndex) {
                        tokens.append(token)
                        currentIndex = token.range.upperBound
                        continue
                    }
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
        while endIndex < code.endIndex {
            if code[endIndex] == "*" {
                let nextEndIndex = code.index(after: endIndex)
                if nextEndIndex < code.endIndex && code[nextEndIndex] == "/" {
                    endIndex = code.index(after: nextEndIndex)
                    break
                }
            }
            endIndex = code.index(after: endIndex)
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .comment, range: startIndex..<endIndex)
    }
    
    private func parseAttribute(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex] == "@" else { return nil }
        
        var endIndex = code.index(after: startIndex)
        
        // Parse attribute name
        while endIndex < code.endIndex {
            let char = code[endIndex]
            if char.isLetter || char.isNumber || char == "_" {
                endIndex = code.index(after: endIndex)
            } else {
                break
            }
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .attribute, range: startIndex..<endIndex)
    }
    
    private func parseString(_ code: String, startIndex: String.Index) throws -> [SyntaxToken]? {
        guard startIndex < code.endIndex && code[startIndex] == "\"" else { return nil }
        
        var tokens: [SyntaxToken] = []
        var currentIndex = code.index(after: startIndex)
        var stringStart = startIndex
        var escaped = false
        
        while currentIndex < code.endIndex {
            let char = code[currentIndex]
            
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
                // Check for string interpolation
                let nextIndex = code.index(after: currentIndex)
                if nextIndex < code.endIndex && code[nextIndex] == "(" {
                    // String part before interpolation
                    if stringStart < currentIndex {
                        let stringContent = String(code[stringStart..<currentIndex])
                        tokens.append(SyntaxToken(content: stringContent, tokenType: .string, range: stringStart..<currentIndex))
                    }
                    
                    // Parse interpolation
                    let interpolationStart = currentIndex
                    currentIndex = code.index(after: nextIndex) // Skip \(
                    
                    var parenCount = 1
                    var interpolationEnd = currentIndex
                    
                    while interpolationEnd < code.endIndex && parenCount > 0 {
                        let char = code[interpolationEnd]
                        if char == "(" {
                            parenCount += 1
                        } else if char == ")" {
                            parenCount -= 1
                        }
                        interpolationEnd = code.index(after: interpolationEnd)
                    }
                    
                    let interpolationContent = String(code[interpolationStart..<interpolationEnd])
                    tokens.append(SyntaxToken(content: interpolationContent, tokenType: .interpolation, range: interpolationStart..<interpolationEnd))
                    
                    currentIndex = interpolationEnd
                    stringStart = currentIndex
                    continue
                }
            } else if char == "\"" {
                // End of string
                let endIndex = code.index(after: currentIndex)
                let stringContent = String(code[stringStart..<endIndex])
                tokens.append(SyntaxToken(content: stringContent, tokenType: .string, range: stringStart..<endIndex))
                return tokens
            }
            
            currentIndex = code.index(after: currentIndex)
        }
        
        // Unclosed string
        let content = String(code[stringStart..<currentIndex])
        tokens.append(SyntaxToken(content: content, tokenType: .string, range: stringStart..<currentIndex))
        return tokens
    }
    
    private func parseMultilineString(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard let tripleQuoteEnd = code.index(startIndex, offsetBy: 3, limitedBy: code.endIndex) else { return nil }
        let tripleQuote = String(code[startIndex..<tripleQuoteEnd])
        guard tripleQuote == "\"\"\"" else { return nil }
        
        var endIndex = tripleQuoteEnd
        // Iterate until we find a terminating triple quote or reach the end of the input.
        // By not imposing a look-ahead constraint, we guarantee that an unclosed
        // multi-line string token spans the entire remainder of the source.
        while endIndex < code.endIndex {
            if code[endIndex...].hasPrefix("\"\"\"") {
                endIndex = code.index(endIndex, offsetBy: 3)
                break
            }
            endIndex = code.index(after: endIndex)
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .string, range: startIndex..<endIndex)
    }
    
    private func parseNumber(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex].isNumber else { return nil }
        
        var endIndex = startIndex
        var hasDecimal = false
        var hasExponent = false
        
        // Handle hexadecimal, binary, and octal literals
        if code[startIndex] == "0" {
            let nextIndex = code.index(after: endIndex)
            if nextIndex < code.endIndex {
                let nextChar = code[nextIndex]
                if nextChar == "x" || nextChar == "X" {
                    // Hexadecimal
                    endIndex = code.index(after: nextIndex)
                    while endIndex < code.endIndex {
                        let char = code[endIndex]
                        if char.isHexDigit {
                            endIndex = code.index(after: endIndex)
                        } else {
                            break
                        }
                    }
                    let content = String(code[startIndex..<endIndex])
                    return SyntaxToken(content: content, tokenType: .number, range: startIndex..<endIndex)
                } else if nextChar == "b" || nextChar == "B" {
                    // Binary
                    endIndex = code.index(after: nextIndex)
                    while endIndex < code.endIndex {
                        let char = code[endIndex]
                        if char == "0" || char == "1" {
                            endIndex = code.index(after: endIndex)
                        } else {
                            break
                        }
                    }
                    let content = String(code[startIndex..<endIndex])
                    return SyntaxToken(content: content, tokenType: .number, range: startIndex..<endIndex)
                } else if nextChar == "o" || nextChar == "O" {
                    // Octal
                    endIndex = code.index(after: nextIndex)
                    while endIndex < code.endIndex {
                        let char = code[endIndex]
                        if char.isNumber && char <= "7" {
                            endIndex = code.index(after: endIndex)
                        } else {
                            break
                        }
                    }
                    let content = String(code[startIndex..<endIndex])
                    return SyntaxToken(content: content, tokenType: .number, range: startIndex..<endIndex)
                }
            }
        }
        
        // Regular decimal number
        while endIndex < code.endIndex {
            let char = code[endIndex]
            
            if char.isNumber {
                // Continue
            } else if char == "." && !hasDecimal && !hasExponent {
                hasDecimal = true
            } else if (char == "e" || char == "E") && !hasExponent {
                hasExponent = true
                // Check for optional + or - after exponent
                let nextIndex = code.index(after: endIndex)
                if nextIndex < code.endIndex && (code[nextIndex] == "+" || code[nextIndex] == "-") {
                    endIndex = nextIndex
                }
            } else {
                break
            }
            
            endIndex = code.index(after: endIndex)
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .number, range: startIndex..<endIndex)
    }
    
    private func parseClosureParameter(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex] == "$" else { return nil }
        
        var endIndex = code.index(after: startIndex)
        while endIndex < code.endIndex && code[endIndex].isNumber {
            endIndex = code.index(after: endIndex)
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .parameter, range: startIndex..<endIndex)
    }
    
    private func parseIdentifier(_ code: String, startIndex: String.Index, previousToken: SyntaxToken?) throws -> SyntaxToken? {
        guard startIndex < code.endIndex else { return nil }
        
        let firstChar = code[startIndex]
        guard firstChar.isLetter || firstChar == "_" else { return nil }
        
        var endIndex = startIndex
        while endIndex < code.endIndex {
            let char = code[endIndex]
            if char.isLetter || char.isNumber || char == "_" {
                endIndex = code.index(after: endIndex)
            } else {
                break
            }
        }
        
        let content = String(code[startIndex..<endIndex])
        let tokenType = classifyIdentifier(content, previousToken: previousToken)
        
        return SyntaxToken(content: content, tokenType: tokenType, range: startIndex..<endIndex)
    }
    
    private func parseOperatorOrPunctuation(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex else { return nil }
        
        let char = code[startIndex]
        let endIndex = code.index(after: startIndex)
        
        // Multi-character operators
        let twoCharOps = ["==", "!=", "<=", ">=", "&&", "||", "++", "--", "+=", "-=", "*=", "/=", "%=", "**", "??", "?.", "->", "...", "..<"]
        let threeCharOps = ["===", "!==", ">>>", "**=", "??=", "&&=", "||="]
        
        // Check for three-character operators
        if let threeCharEnd = code.index(startIndex, offsetBy: 3, limitedBy: code.endIndex) {
            let threeCharStr = String(code[startIndex..<threeCharEnd])
            if threeCharOps.contains(threeCharStr) {
                return SyntaxToken(content: threeCharStr, tokenType: .`operator`, range: startIndex..<threeCharEnd)
            }
        }
        
        // Check for two-character operators
        if let twoCharEnd = code.index(startIndex, offsetBy: 2, limitedBy: code.endIndex) {
            let twoCharStr = String(code[startIndex..<twoCharEnd])
            if twoCharOps.contains(twoCharStr) {
                return SyntaxToken(content: twoCharStr, tokenType: .`operator`, range: startIndex..<twoCharEnd)
            }
        }
        
        // Single character operators and punctuation
        let operators = Set("+-*/%=<>!&|^~?:")
        let punctuation = Set("()[]{},.;")
        
        let content = String(char)
        let tokenType: SyntaxTokenType = operators.contains(char) ? .`operator` : (punctuation.contains(char) ? .punctuation : .plain)
        
        return SyntaxToken(content: content, tokenType: tokenType, range: startIndex..<endIndex)
    }
    
    private func classifyIdentifier(_ content: String, previousToken: SyntaxToken?) -> SyntaxTokenType {
        // Check for modifiers first (they are more specific than keywords)
        if Self.modifiers.contains(content) {
            return .modifier
        }
        
        // Check for built-in types
        if Self.builtinTypes.contains(content) {
            return .type
        }
        
        if Self.keywords.contains(content) {
            return .keyword
        }
        
        if Self.constants.contains(content) {
            return .constant
        }
        
        // Check if this is a method call (preceded by a dot)
        if let prev = previousToken, prev.content == "." {
            return .method
        }
        
        if Self.builtinFunctions.contains(content) {
            return .builtin
        }
        
        // Check for method calls (contains parentheses nearby)
        if content.hasSuffix("()") {
            return .method
        }
        
        // Check for common patterns
        if content.first?.isUppercase == true {
            return .type // Likely a type, protocol, or class
        }
        
        return .identifier
    }
}

extension Character {
    var isHexDigit: Bool {
        return self.isNumber || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
} 