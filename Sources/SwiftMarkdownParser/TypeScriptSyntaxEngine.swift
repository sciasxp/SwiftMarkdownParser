/// TypeScript syntax highlighting engine
/// 
/// This engine provides comprehensive syntax highlighting for TypeScript
/// with support for type annotations, generics, interfaces, decorators,
/// and all modern JavaScript features.

import Foundation

/// TypeScript syntax highlighting engine implementation
public struct TypeScriptSyntaxEngine: SyntaxHighlightingEngine {
    
    // MARK: - Keywords
    
    private static let keywords: Set<String> = [
        // JavaScript keywords
        "break", "case", "catch", "class", "const", "continue", "debugger", "default",
        "delete", "do", "else", "export", "extends", "finally", "for", "function",
        "if", "import", "in", "instanceof", "new", "return", "super", "switch",
        "this", "throw", "try", "typeof", "var", "void", "while", "with",
        "let", "async", "await", "yield", "from", "of", "static", "get", "set",
        
        // TypeScript-specific keywords
        "abstract", "as", "asserts", "declare", "implements", "interface", "is",
        "keyof", "namespace", "never", "readonly", "require", "type", "unique",
        "unknown", "infer", "out", "override", "satisfies"
    ]
    
    private static let builtinTypes: Set<String> = [
        // JavaScript built-ins
        "Array", "Object", "String", "Number", "Boolean", "Date", "RegExp", "Error",
        "Math", "JSON", "console", "window", "document", "Promise", "Symbol", "Map",
        "Set", "WeakMap", "WeakSet", "Proxy", "Reflect", "ArrayBuffer", "DataView",
        "Int8Array", "Uint8Array", "Uint8ClampedArray", "Int16Array", "Uint16Array",
        "Int32Array", "Uint32Array", "Float32Array", "Float64Array", "BigInt64Array",
        "BigUint64Array", "Generator", "GeneratorFunction", "AsyncFunction", "AsyncGenerator",
        "AsyncGeneratorFunction", "Intl", "WebAssembly",
        
        // TypeScript built-in types
        "string", "number", "boolean", "object", "bigint", "symbol", "undefined",
        "null", "void", "never", "unknown", "any", "Function", "Record", "Partial",
        "Required", "Readonly", "Pick", "Omit", "Exclude", "Extract", "NonNullable",
        "Parameters", "ConstructorParameters", "ReturnType", "InstanceType",
        "ThisParameterType", "OmitThisParameter", "ThisType", "Uppercase", "Lowercase",
        "Capitalize", "Uncapitalize", "Template", "Awaited"
    ]
    
    private static let builtinFunctions: Set<String> = [
        "console.log", "console.error", "console.warn", "console.info", "console.debug",
        "setTimeout", "setInterval", "clearTimeout", "clearInterval", "fetch",
        "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
        "encodeURIComponent", "decodeURIComponent", "escape", "unescape", "eval",
        "require", "module.exports", "exports"
    ]
    
    private static let constants: Set<String> = [
        "true", "false", "null", "undefined", "NaN", "Infinity"
    ]
    
    private static let modifiers: Set<String> = [
        "public", "private", "protected", "static", "readonly", "abstract", "override"
    ]
    
    // MARK: - JSX Elements (for TSX)
    
    private static let commonJSXElements: Set<String> = [
        "div", "span", "p", "a", "img", "button", "input", "form", "label", "select",
        "option", "textarea", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li",
        "table", "tr", "td", "th", "thead", "tbody", "tfoot", "section", "article",
        "header", "footer", "nav", "main", "aside", "canvas", "svg", "video", "audio",
        "source", "track", "embed", "object", "param", "iframe", "script", "style",
        "link", "meta", "title", "head", "body", "html"
    ]
    
    private static let jsxAttributes: Set<String> = [
        "className", "htmlFor", "onClick", "onChange", "onSubmit", "onFocus", "onBlur",
        "onMouseOver", "onMouseOut", "onKeyDown", "onKeyUp", "onKeyPress", "style",
        "id", "key", "ref", "dangerouslySetInnerHTML", "defaultValue", "defaultChecked",
        "autoFocus", "disabled", "readOnly", "required", "placeholder", "value",
        "checked", "selected", "multiple", "size", "rows", "cols", "wrap", "accept",
        "action", "method", "encType", "target", "rel", "href", "src", "alt", "title",
        "width", "height", "type", "name", "role", "aria-label", "aria-describedby",
        "tabIndex", "contentEditable", "draggable", "hidden", "lang", "dir", "translate"
    ]
    
    // MARK: - Public Interface
    
    public init() {}
    
    public func highlight(_ code: String, language: String) async throws -> [SyntaxToken] {
        guard supportedLanguages().contains(language.lowercased()) else {
            throw SyntaxHighlightingError.unsupportedLanguage(language)
        }
        
        let isTSX = language.lowercased() == "tsx"
        return try await tokenize(code, isTSX: isTSX)
    }
    
    public func supportedLanguages() -> Set<String> {
        return Set(["typescript", "ts", "tsx"])
    }
    
    // MARK: - Tokenization
    
    private func tokenize(_ code: String, isTSX: Bool) async throws -> [SyntaxToken] {
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
            
            // Decorators
            if char == "@" {
                if let token = try parseDecorator(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Strings
            if char == "\"" || char == "'" {
                if let token = try parseString(code, startIndex: currentIndex, delimiter: char) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Template literals
            if char == "`" {
                if let templateTokens = try parseTemplateLiteral(code, startIndex: currentIndex) {
                    tokens.append(contentsOf: templateTokens)
                    currentIndex = templateTokens.last?.range.upperBound ?? code.index(after: currentIndex)
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
            
            // Generics and type annotations
            if char == "<" {
                if let genericTokens = try parseGenericOrJSX(code, startIndex: currentIndex, isTSX: isTSX) {
                    tokens.append(contentsOf: genericTokens)
                    currentIndex = genericTokens.last?.range.upperBound ?? code.index(after: currentIndex)
                    continue
                }
            }
            
            // Identifiers and keywords
            if char.isLetter || char == "_" || char == "$" {
                if let token = try parseIdentifier(code, startIndex: currentIndex, isTSX: isTSX) {
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
        while endIndex < code.index(before: code.endIndex) {
            if code[endIndex] == "*" && code[code.index(after: endIndex)] == "/" {
                endIndex = code.index(after: code.index(after: endIndex))
                break
            }
            endIndex = code.index(after: endIndex)
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .comment, range: startIndex..<endIndex)
    }
    
    private func parseDecorator(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex] == "@" else { return nil }
        
        var endIndex = code.index(after: startIndex)
        
        // Parse decorator name
        while endIndex < code.endIndex {
            let char = code[endIndex]
            if char.isLetter || char.isNumber || char == "_" || char == "$" {
                endIndex = code.index(after: endIndex)
            } else {
                break
            }
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .attribute, range: startIndex..<endIndex)
    }
    
    private func parseString(_ code: String, startIndex: String.Index, delimiter: Character) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex] == delimiter else { return nil }
        
        var endIndex = code.index(after: startIndex)
        var escaped = false
        
        while endIndex < code.endIndex {
            let char = code[endIndex]
            
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == delimiter {
                endIndex = code.index(after: endIndex)
                break
            }
            
            endIndex = code.index(after: endIndex)
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .string, range: startIndex..<endIndex)
    }
    
    private func parseTemplateLiteral(_ code: String, startIndex: String.Index) throws -> [SyntaxToken]? {
        guard startIndex < code.endIndex && code[startIndex] == "`" else { return nil }
        
        var tokens: [SyntaxToken] = []
        var currentIndex = startIndex
        var templateStart = currentIndex
        
        currentIndex = code.index(after: currentIndex)
        
        while currentIndex < code.endIndex {
            let char = code[currentIndex]
            
            if char == "`" {
                // End of template literal
                let endIndex = code.index(after: currentIndex)
                let content = String(code[templateStart..<endIndex])
                tokens.append(SyntaxToken(content: content, tokenType: .template, range: templateStart..<endIndex))
                return tokens
            } else if char == "$" && currentIndex < code.index(before: code.endIndex) {
                let nextChar = code[code.index(after: currentIndex)]
                if nextChar == "{" {
                    // Template literal part before interpolation
                    if templateStart < currentIndex {
                        let content = String(code[templateStart..<currentIndex])
                        tokens.append(SyntaxToken(content: content, tokenType: .template, range: templateStart..<currentIndex))
                    }
                    
                    // Parse interpolation
                    let interpolationStart = currentIndex
                    currentIndex = code.index(after: code.index(after: currentIndex)) // Skip ${
                    
                    var braceCount = 1
                    var interpolationEnd = currentIndex
                    
                    while interpolationEnd < code.endIndex && braceCount > 0 {
                        let char = code[interpolationEnd]
                        if char == "{" {
                            braceCount += 1
                        } else if char == "}" {
                            braceCount -= 1
                        }
                        interpolationEnd = code.index(after: interpolationEnd)
                    }
                    
                    let interpolationContent = String(code[interpolationStart..<interpolationEnd])
                    tokens.append(SyntaxToken(content: interpolationContent, tokenType: .interpolation, range: interpolationStart..<interpolationEnd))
                    
                    currentIndex = interpolationEnd
                    templateStart = currentIndex
                    continue
                }
            }
            
            currentIndex = code.index(after: currentIndex)
        }
        
        // Unclosed template literal
        let content = String(code[templateStart..<currentIndex])
        tokens.append(SyntaxToken(content: content, tokenType: .template, range: templateStart..<currentIndex))
        return tokens
    }
    
    private func parseNumber(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex].isNumber else { return nil }
        
        var endIndex = startIndex
        var hasDecimal = false
        var hasExponent = false
        
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
            } else if char == "n" && endIndex == code.index(before: code.endIndex) {
                // BigInt suffix
                endIndex = code.index(after: endIndex)
                break
            } else {
                break
            }
            
            endIndex = code.index(after: endIndex)
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .number, range: startIndex..<endIndex)
    }
    
    private func parseGenericOrJSX(_ code: String, startIndex: String.Index, isTSX: Bool) throws -> [SyntaxToken]? {
        guard startIndex < code.endIndex && code[startIndex] == "<" else { return nil }
        
        // Try to determine if this is a generic or JSX
        var isGeneric = false
        var tempIndex = code.index(after: startIndex)
        
        // Look ahead to see if this looks like a generic
        while tempIndex < code.endIndex {
            let char = code[tempIndex]
            
            if char.isWhitespace {
                tempIndex = code.index(after: tempIndex)
                continue
            }
            
            if char.isLetter || char == "_" {
                // Could be generic type parameter or JSX element
                var identifierEnd = tempIndex
                while identifierEnd < code.endIndex {
                    let identChar = code[identifierEnd]
                    if identChar.isLetter || identChar.isNumber || identChar == "_" {
                        identifierEnd = code.index(after: identifierEnd)
                    } else {
                        break
                    }
                }
                
                // Skip whitespace after identifier
                while identifierEnd < code.endIndex && code[identifierEnd].isWhitespace {
                    identifierEnd = code.index(after: identifierEnd)
                }
                
                if identifierEnd < code.endIndex {
                    let nextChar = code[identifierEnd]
                    if nextChar == "," || nextChar == ">" || nextChar == "=" {
                        isGeneric = true
                    }
                    // Check for "extends" keyword
                    if let extendsEnd = code.index(identifierEnd, offsetBy: 7, limitedBy: code.endIndex) {
                        let extendsStr = String(code[identifierEnd..<extendsEnd])
                        if extendsStr == "extends" {
                            isGeneric = true
                        }
                    }
                }
                break
            }
            
            break
        }
        
        if isGeneric {
            return try parseGeneric(code, startIndex: startIndex)
        } else if isTSX {
            return try parseJSXElement(code, startIndex: startIndex)
        }
        
        return nil
    }
    
    private func parseGeneric(_ code: String, startIndex: String.Index) throws -> [SyntaxToken]? {
        guard startIndex < code.endIndex && code[startIndex] == "<" else { return nil }
        
        var tokens: [SyntaxToken] = []
        var currentIndex = startIndex
        
        // Parse opening <
        let openEnd = code.index(after: currentIndex)
        tokens.append(SyntaxToken(content: "<", tokenType: .punctuation, range: currentIndex..<openEnd))
        currentIndex = openEnd
        
        // Parse generic content
        var angleCount = 1
        
        while currentIndex < code.endIndex && angleCount > 0 {
            let char = code[currentIndex]
            
            if char == "<" {
                angleCount += 1
            } else if char == ">" {
                angleCount -= 1
            }
            
            // Parse identifiers within generics
            if char.isLetter || char == "_" {
                if let identifier = try parseIdentifier(code, startIndex: currentIndex, isTSX: false) {
                    let content = identifier.content
                    let tokenType: SyntaxTokenType = Self.builtinTypes.contains(content) ? .type : .generic
                    tokens.append(SyntaxToken(content: content, tokenType: tokenType, range: identifier.range))
                    currentIndex = identifier.range.upperBound
                    continue
                }
            }
            
            currentIndex = code.index(after: currentIndex)
        }
        
        // Parse closing >
        if currentIndex <= code.endIndex {
            let content = String(code[startIndex..<currentIndex])
            if content.hasSuffix(">") {
                let closeStart = code.index(before: currentIndex)
                tokens.append(SyntaxToken(content: ">", tokenType: .punctuation, range: closeStart..<currentIndex))
            }
        }
        
        return tokens
    }
    
    private func parseJSXElement(_ code: String, startIndex: String.Index) throws -> [SyntaxToken]? {
        guard startIndex < code.endIndex && code[startIndex] == "<" else { return nil }
        
        var tokens: [SyntaxToken] = []
        var currentIndex = startIndex
        
        // Parse opening <
        let openBracketEnd = code.index(after: currentIndex)
        tokens.append(SyntaxToken(content: "<", tokenType: .punctuation, range: currentIndex..<openBracketEnd))
        currentIndex = openBracketEnd
        
        // Parse tag name
        if let tagToken = try parseIdentifier(code, startIndex: currentIndex, isTSX: true) {
            let tagContent = tagToken.content
            let tagType: SyntaxTokenType = Self.commonJSXElements.contains(tagContent.lowercased()) ? .type : .identifier
            tokens.append(SyntaxToken(content: tagContent, tokenType: tagType, range: tagToken.range))
            currentIndex = tagToken.range.upperBound
        }
        
        // Parse attributes
        while currentIndex < code.endIndex {
            let char = code[currentIndex]
            
            if char.isWhitespace {
                currentIndex = code.index(after: currentIndex)
                continue
            }
            
            if char == ">" || char == "/" {
                break
            }
            
            // Parse attribute name
            if let attrToken = try parseIdentifier(code, startIndex: currentIndex, isTSX: true) {
                let attrContent = attrToken.content
                let attrType: SyntaxTokenType = Self.jsxAttributes.contains(attrContent) ? .attribute : .identifier
                tokens.append(SyntaxToken(content: attrContent, tokenType: attrType, range: attrToken.range))
                currentIndex = attrToken.range.upperBound
                
                // Skip whitespace
                while currentIndex < code.endIndex && code[currentIndex].isWhitespace {
                    currentIndex = code.index(after: currentIndex)
                }
                
                // Parse = if present
                if currentIndex < code.endIndex && code[currentIndex] == "=" {
                    let equalEnd = code.index(after: currentIndex)
                    tokens.append(SyntaxToken(content: "=", tokenType: .`operator`, range: currentIndex..<equalEnd))
                    currentIndex = equalEnd
                    
                    // Skip whitespace
                    while currentIndex < code.endIndex && code[currentIndex].isWhitespace {
                        currentIndex = code.index(after: currentIndex)
                    }
                    
                    // Parse attribute value
                    if currentIndex < code.endIndex {
                        let valueChar = code[currentIndex]
                        if valueChar == "\"" || valueChar == "'" {
                            if let stringToken = try parseString(code, startIndex: currentIndex, delimiter: valueChar) {
                                tokens.append(stringToken)
                                currentIndex = stringToken.range.upperBound
                            }
                        } else if valueChar == "{" {
                            // JSX expression
                            let exprStart = currentIndex
                            currentIndex = code.index(after: currentIndex)
                            
                            var braceCount = 1
                            while currentIndex < code.endIndex && braceCount > 0 {
                                let char = code[currentIndex]
                                if char == "{" {
                                    braceCount += 1
                                } else if char == "}" {
                                    braceCount -= 1
                                }
                                currentIndex = code.index(after: currentIndex)
                            }
                            
                            let exprContent = String(code[exprStart..<currentIndex])
                            tokens.append(SyntaxToken(content: exprContent, tokenType: .interpolation, range: exprStart..<currentIndex))
                        }
                    }
                }
            } else {
                currentIndex = code.index(after: currentIndex)
            }
        }
        
        // Parse closing > or />
        if currentIndex < code.endIndex {
            let char = code[currentIndex]
            if char == "/" && currentIndex < code.index(before: code.endIndex) {
                let nextChar = code[code.index(after: currentIndex)]
                if nextChar == ">" {
                    let selfCloseEnd = code.index(after: code.index(after: currentIndex))
                    tokens.append(SyntaxToken(content: "/>", tokenType: .punctuation, range: currentIndex..<selfCloseEnd))
                    return tokens
                }
            } else if char == ">" {
                let closeEnd = code.index(after: currentIndex)
                tokens.append(SyntaxToken(content: ">", tokenType: .punctuation, range: currentIndex..<closeEnd))
                return tokens
            }
        }
        
        return tokens
    }
    
    private func parseIdentifier(_ code: String, startIndex: String.Index, isTSX: Bool) throws -> SyntaxToken? {
        guard startIndex < code.endIndex else { return nil }
        
        let firstChar = code[startIndex]
        guard firstChar.isLetter || firstChar == "_" || firstChar == "$" else { return nil }
        
        var endIndex = startIndex
        while endIndex < code.endIndex {
            let char = code[endIndex]
            if char.isLetter || char.isNumber || char == "_" || char == "$" {
                endIndex = code.index(after: endIndex)
            } else {
                break
            }
        }
        
        let content = String(code[startIndex..<endIndex])
        let tokenType = classifyIdentifier(content, isTSX: isTSX)
        
        return SyntaxToken(content: content, tokenType: tokenType, range: startIndex..<endIndex)
    }
    
    private func parseOperatorOrPunctuation(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex else { return nil }
        
        let char = code[startIndex]
        let endIndex = code.index(after: startIndex)
        
        // Multi-character operators
        let twoCharOps = ["==", "!=", "<=", ">=", "&&", "||", "++", "--", "+=", "-=", "*=", "/=", "%=", "**", "=>", "??", "?.", "?:"]
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
    
    private func classifyIdentifier(_ content: String, isTSX: Bool) -> SyntaxTokenType {
        // Check for built-in types first (takes precedence over keywords)
        if Self.builtinTypes.contains(content) {
            return .type
        }
        
        if Self.keywords.contains(content) {
            return .keyword
        }
        
        if Self.constants.contains(content) {
            return .constant
        }
        
        if Self.builtinFunctions.contains(content) {
            return .builtin
        }
        
        if Self.modifiers.contains(content) {
            return .modifier
        }
        
        // Check for common patterns
        if content.hasPrefix("on") && content.count > 2 && content[content.index(content.startIndex, offsetBy: 2)].isUppercase {
            return .method // Event handlers like onClick, onChange
        }
        
        if content.first?.isUppercase == true {
            return .type // Likely a constructor, interface, or component
        }
        
        return .identifier
    }
} 