/// Public semantic token and theme types used by syntax highlighting.

public import SwiftUI

// MARK: - Syntax Token

/// Represents a highlighted segment of code
public struct SyntaxToken: Sendable, Equatable {
    /// The text content of this token
    public let content: String

    /// The type of syntax element this token represents
    public let tokenType: SyntaxTokenType

    /// The range of this token in the original source code
    public let range: Range<String.Index>

    public init(content: String, tokenType: SyntaxTokenType, range: Range<String.Index>) {
        self.content = content
        self.tokenType = tokenType
        self.range = range
    }
}

// MARK: - Token Types

/// Types of syntax elements that can be highlighted
public enum SyntaxTokenType: String, CaseIterable, Sendable {
    // Basic language elements
    case keyword        // if, else, for, while, function, class, etc.
    case string         // "string", 'string', `template`, """multiline"""
    case comment        // // line comment, /* block comment */, # shell comment
    case number         // 42, 3.14, 0x1F, 0b101, BigInt
    case identifier     // variable_name, function_name
    case `operator`     // +, -, *, /, =, ==, !=, &&, ||, ??, etc.
    case punctuation    // (, ), [, ], {, }, :, ;, ,, .
    case plain          // default text

    // Language-specific elements
    case type           // String, Int, Array<T>, interface names
    case function       // function definitions and calls
    case variable       // variables and parameters
    case constant       // true, false, null, nil, None, const values
    case builtin        // console.log, print, len, range, etc.
    case attribute      // @decorator, @available, @JvmStatic
    case generic        // <T>, <K, V>, generics and type parameters
    case namespace      // module, package, import statements
    case property       // object.property, this.field
    case method         // object.method(), class methods
    case parameter      // function parameters
    case label          // parameter labels in Swift
    case escape         // \n, \t, \", escape sequences
    case interpolation  // ${variable}, \(expression) in strings
    case regex          // /pattern/flags, regular expressions
    case template       // template literals, string interpolation
    case annotation     // TypeScript/Java annotations
    case modifier       // public, private, static, final, etc.
}

// MARK: - Syntax Highlighting Theme

/// Color theme for syntax highlighting
@available(iOS 17.0, macOS 14.0, *)
public struct SyntaxHighlightingTheme: Sendable, Equatable {
    /// Theme name
    public let name: String

    /// Background color for code blocks
    public let backgroundColor: Color

    /// Default text color
    public let textColor: Color

    /// Colors for different token types
    public let tokenColors: [SyntaxTokenType: Color]

    public init(name: String, backgroundColor: Color, textColor: Color, tokenColors: [SyntaxTokenType: Color]) {
        self.name = name
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.tokenColors = tokenColors
    }
}

// MARK: - Built-in Themes

@available(iOS 17.0, macOS 14.0, *)
public extension SyntaxHighlightingTheme {

    /// GitHub-style light theme
    static let github = SyntaxHighlightingTheme(
        name: "GitHub",
        backgroundColor: Color(red: 0.97, green: 0.97, blue: 0.98),
        textColor: Color(red: 0.15, green: 0.15, blue: 0.15),
        tokenColors: [
            .keyword: Color(red: 0.82, green: 0.10, blue: 0.26),           // #d73a49
            .string: Color(red: 0.03, green: 0.52, blue: 0.11),            // #032f62
            .comment: Color(red: 0.40, green: 0.40, blue: 0.40),           // #6a737d
            .number: Color(red: 0.00, green: 0.31, blue: 0.69),            // #005cc5
            .function: Color(red: 0.39, green: 0.18, blue: 0.64),          // #6f42c1
            .builtin: Color(red: 0.00, green: 0.31, blue: 0.69),           // #005cc5
            .type: Color(red: 0.39, green: 0.18, blue: 0.64),              // #6f42c1
            .variable: Color(red: 0.15, green: 0.15, blue: 0.15),          // #24292e
            .operator: Color(red: 0.82, green: 0.10, blue: 0.26),          // #d73a49
            .constant: Color(red: 0.00, green: 0.31, blue: 0.69),          // #005cc5
            .attribute: Color(red: 0.00, green: 0.31, blue: 0.69),         // #005cc5
            .generic: Color(red: 0.39, green: 0.18, blue: 0.64),           // #6f42c1
            .method: Color(red: 0.39, green: 0.18, blue: 0.64),            // #6f42c1
            .property: Color(red: 0.00, green: 0.31, blue: 0.69),          // #005cc5
            .parameter: Color(red: 0.15, green: 0.15, blue: 0.15),         // #24292e
            .modifier: Color(red: 0.82, green: 0.10, blue: 0.26),          // #d73a49
            .template: Color(red: 0.03, green: 0.52, blue: 0.11),          // #032f62
            .interpolation: Color(red: 0.82, green: 0.10, blue: 0.26),     // #d73a49
            .regex: Color(red: 0.03, green: 0.52, blue: 0.11),             // #032f62
            .escape: Color(red: 0.82, green: 0.10, blue: 0.26)             // #d73a49
        ]
    )

    /// Xcode-style light theme
    static let xcode = SyntaxHighlightingTheme(
        name: "Xcode",
        backgroundColor: Color(red: 1.0, green: 1.0, blue: 1.0),
        textColor: Color(red: 0.0, green: 0.0, blue: 0.0),
        tokenColors: [
            .keyword: Color(red: 0.67, green: 0.18, blue: 0.55),           // #aa0d91
            .string: Color(red: 0.77, green: 0.10, blue: 0.09),            // #c41a16
            .comment: Color(red: 0.00, green: 0.52, blue: 0.00),           // #008400
            .number: Color(red: 0.15, green: 0.00, blue: 0.81),            // #2600d0
            .function: Color(red: 0.24, green: 0.40, blue: 0.72),          // #3d65cc
            .builtin: Color(red: 0.24, green: 0.40, blue: 0.72),           // #3d65cc
            .type: Color(red: 0.24, green: 0.40, blue: 0.72),              // #3d65cc
            .variable: Color(red: 0.00, green: 0.00, blue: 0.00),          // #000000
            .operator: Color(red: 0.67, green: 0.18, blue: 0.55),          // #aa0d91
            .constant: Color(red: 0.67, green: 0.18, blue: 0.55),          // #aa0d91
            .attribute: Color(red: 0.40, green: 0.40, blue: 0.40),         // #666666
            .generic: Color(red: 0.24, green: 0.40, blue: 0.72),           // #3d65cc
            .method: Color(red: 0.24, green: 0.40, blue: 0.72),            // #3d65cc
            .property: Color(red: 0.24, green: 0.40, blue: 0.72),          // #3d65cc
            .parameter: Color(red: 0.00, green: 0.00, blue: 0.00),         // #000000
            .modifier: Color(red: 0.67, green: 0.18, blue: 0.55),          // #aa0d91
            .template: Color(red: 0.77, green: 0.10, blue: 0.09),          // #c41a16
            .interpolation: Color(red: 0.67, green: 0.18, blue: 0.55),     // #aa0d91
            .regex: Color(red: 0.77, green: 0.10, blue: 0.09),             // #c41a16
            .escape: Color(red: 0.67, green: 0.18, blue: 0.55)             // #aa0d91
        ]
    )

    /// VS Code dark theme
    static let vsCodeDark = SyntaxHighlightingTheme(
        name: "VS Code Dark",
        backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.12),
        textColor: Color(red: 0.86, green: 0.86, blue: 0.86),
        tokenColors: [
            .keyword: Color(red: 0.31, green: 0.59, blue: 0.84),           // #4fc3f7
            .string: Color(red: 0.81, green: 0.56, blue: 0.45),            // #ce9178
            .comment: Color(red: 0.38, green: 0.67, blue: 0.38),           // #6a9955
            .number: Color(red: 0.71, green: 0.82, blue: 0.65),            // #b5cea8
            .function: Color(red: 0.86, green: 0.86, blue: 0.44),          // #dcdcaa
            .builtin: Color(red: 0.31, green: 0.59, blue: 0.84),           // #4fc3f7
            .type: Color(red: 0.29, green: 0.78, blue: 0.64),              // #4ac7a8
            .variable: Color(red: 0.60, green: 0.73, blue: 0.85),          // #9cdcfe
            .operator: Color(red: 0.86, green: 0.86, blue: 0.86),          // #d4d4d4
            .constant: Color(red: 0.31, green: 0.59, blue: 0.84),          // #4fc3f7
            .attribute: Color(red: 0.92, green: 0.79, blue: 0.55),         // #ebc774
            .generic: Color(red: 0.29, green: 0.78, blue: 0.64),           // #4ac7a8
            .method: Color(red: 0.86, green: 0.86, blue: 0.44),            // #dcdcaa
            .property: Color(red: 0.60, green: 0.73, blue: 0.85),          // #9cdcfe
            .parameter: Color(red: 0.60, green: 0.73, blue: 0.85),         // #9cdcfe
            .modifier: Color(red: 0.31, green: 0.59, blue: 0.84),          // #4fc3f7
            .template: Color(red: 0.81, green: 0.56, blue: 0.45),          // #ce9178
            .interpolation: Color(red: 0.86, green: 0.86, blue: 0.44),     // #dcdcaa
            .regex: Color(red: 0.81, green: 0.56, blue: 0.45),             // #ce9178
            .escape: Color(red: 0.86, green: 0.86, blue: 0.44)             // #dcdcaa
        ]
    )
}
