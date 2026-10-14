/// Inline parser for converting tokens into inline AST nodes
///
/// This parser handles inline elements like emphasis, strong emphasis,
/// links, images, code spans, and other inline formatting.
import Foundation

// MARK: - Inline Parser

/// Parser for inline markdown elements
final class InlineParser {

    private let tokenStream: TokenStream
    private let budget: ParsingBudget
    private let linkReferences: [String: LinkReference]
    private let maximumNestingDepth: Int
    private var nestingDepth = 0

    init(
        tokenStream: TokenStream,
        budget: ParsingBudget,
        linkReferences: [String: LinkReference],
        maximumNestingDepth: Int
    ) {
        self.tokenStream = tokenStream
        self.budget = budget
        self.linkReferences = linkReferences
        self.maximumNestingDepth = maximumNestingDepth
    }

    /// Parse inline content from a text string
    func parseInlineContent(
        _ text: String,
        startingAt location: SourceLocation = SourceLocation(line: 1, column: 1, offset: 0)
    ) throws -> [any ASTNode] {
        let inlineTokenizer = MarkdownTokenizer(
            MarkdownSourceText(text, startingAt: location, budget: budget),
            budget: budget
        )
        let inlineTokenStream = TokenStream(inlineTokenizer.tokenize(), budget: budget)

        // Create a single parser instance for the entire text
        let tempParser = InlineParser(
            tokenStream: inlineTokenStream,
            budget: budget,
            linkReferences: linkReferences,
            maximumNestingDepth: maximumNestingDepth
        )

        var nodes: [any ASTNode] = []

        // Protection mechanisms
        var lastTokenPosition = -1
        var stuckPositionCount = 0
        let maxStuckPositions = 50 // Prevent infinite loops from position not advancing (increased threshold)

        while !inlineTokenStream.isAtEnd {
            // Position-based protection (detect if parser is stuck)
            let currentPosition = inlineTokenStream.currentPosition
            if currentPosition == lastTokenPosition {
                stuckPositionCount += 1
                if stuckPositionCount >= maxStuckPositions {
                    throw MarkdownParsingError.internalInvariant(
                        message: "Inline content parser made no progress at token \(currentPosition).",
                        location: inlineTokenStream.current.location
                    )
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
    private func parseInline() throws -> [any ASTNode] {
        nestingDepth += 1
        defer { nestingDepth -= 1 }
        guard nestingDepth <= maximumNestingDepth else {
            throw MarkdownParsingError.resourceLimitExceeded(
                resource: .nestingDepth,
                limit: maximumNestingDepth,
                actual: nestingDepth
            )
        }

        let token = tokenStream.current
        switch token.type {
        case .newline:
            return [parseLineBreak(isHard: false, startingAt: token.location)]
        case .whitespace where tokenStream.peek().type == .newline:
            // Spaces before a line ending are not content; two or more make
            // the break hard
            tokenStream.advance()
            let isHard = token.content.filter { $0 == " " }.count >= 2
            return [parseLineBreak(isHard: isHard, startingAt: token.location)]
        case .text, .whitespace:
            return [parseText()]
        case .asterisk:
            // Handle emphasis and strong emphasis with *
            if let emphasisNode = try parseEmphasisOrStrong(delimiter: "*") {
                return [emphasisNode]
            } else {
                return [parseText()]
            }
        case .underscore:
            // Handle emphasis and strong emphasis with _
            if let emphasisNode = try parseEmphasisOrStrong(delimiter: "_") {
                return [emphasisNode]
            } else {
                return [parseText()]
            }
        case .backtick:
            // Handle code spans
            if let codeSpan = try parseCodeSpan() {
                return [codeSpan]
            } else {
                return [parseText()]
            }
        case .leftBracket:
            // Handle links
            if let link = try parseLinkOrImage() {
                return [link]
            } else {
                return [parseText()]
            }
        case .exclamation:
            // Handle images
            if let image = try parseImage() {
                return [image]
            } else {
                return [parseText()]
            }
        case .tilde:
            // Handle strikethrough
            if let strikethrough = try parseStrikethrough() {
                return [strikethrough]
            } else {
                return [parseText()]
            }
        case .htmlTag:
            // Handle HTML tags - treat as text content when inside code spans or other contexts
            return [parseText()]
        case .autolink:
            // Handle autolinks
            if let autolink = parseAutolink() {
                return [autolink]
            } else {
                return [parseText()]
            }
        case .dollarSign:
            // Handle inline math
            if let inlineMath = try parseInlineMath() {
                return [inlineMath]
            } else {
                return [parseText()]
            }
        case .backslash:
            // A backslash before a line ending is a hard break
            if token.content.count == 2, token.content.last.map(MarkdownSourceText.isLineEnding) == true {
                return [parseLineBreak(isHard: true, startingAt: token.location)]
            }
            // Handle escaped characters
            if let escaped = parseEscapedCharacter() {
                return [escaped]
            } else {
                return [parseText()]
            }
        default:
            // For other tokens, treat as text
            return [parseText()]
        }
    }

    // MARK: - Text and Whitespace

    private func parseText() -> AST.TextNode {
        let token = tokenStream.consume()
        return AST.TextNode(content: token.content, sourceLocation: token.location)
    }

    /// Consumes the token ending a line (a line ending, or a backslash
    /// followed by one) and the indentation of the next line, which is not
    /// paragraph content.
    private func parseLineBreak(isHard: Bool, startingAt start: SourceLocation) -> any ASTNode {
        tokenStream.advance()
        let range = tokenStream.range(startingAt: start)
        skipLineIndentation()
        if isHard {
            return AST.LineBreakNode(isHard: true, sourceLocation: range)
        }
        return AST.SoftBreakNode(sourceLocation: range)
    }

    private func skipLineIndentation() {
        while tokenStream.check(.whitespace) || tokenStream.check(.indentedCodeBlock) {
            tokenStream.advance()
        }
    }

    // MARK: - Emphasis and Strong Emphasis

    private func parseEmphasisOrStrong(delimiter: String) throws -> (any ASTNode)? {
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
        var content: [any ASTNode] = []

        while !tokenStream.isAtEnd {
            // Stop at newlines - emphasis shouldn't span line boundaries
            if tokenStream.current.type == .newline ||
                (tokenStream.current.type == .whitespace && tokenStream.peek().type == .newline) {
                break
            }

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

                // Handle triple asterisks for bold+italic (***text***)
                if delimiterCount >= 3 && closingCount >= 3 {
                    // Put back extra delimiters
                    let extraDelimiters = closingCount - 3
                    if extraDelimiters > 0 {
                        tokenStream.setPosition(tokenStream.currentPosition - 1)
                    }

                    // Create nested strong and emphasis nodes
                    let emphasisNode = AST.EmphasisNode(
                        children: content,
                        sourceLocation: tokenStream.range(startingAt: startLocation)
                    )

                    return AST.StrongEmphasisNode(
                        children: [emphasisNode],
                        sourceLocation: tokenStream.range(startingAt: startLocation)
                    )
                }

                // Strong emphasis (2 delimiters)
                if delimiterCount >= 2 && closingCount >= 2 {
                    // Put back extra delimiters
                    let extraDelimiters = closingCount - 2
                    if extraDelimiters > 0 {
                        tokenStream.setPosition(tokenStream.currentPosition - 1)
                    }

                    return AST.StrongEmphasisNode(
                        children: content,
                        sourceLocation: tokenStream.range(startingAt: startLocation)
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
                        sourceLocation: tokenStream.range(startingAt: startLocation)
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
        let startPosition = tokenStream.currentPosition
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

            // A line ending is a space; the next line's indentation is not content
            if token.type == .newline {
                content += " "
                tokenStream.advance()
                skipLineIndentation()
                continue
            }

            // Accept any token type inside code spans - they should all be treated as literal content
            content += token.content
            tokenStream.advance()
        }

        guard foundClosing else {
            // No closing backticks, backtrack and treat as regular text
            tokenStream.setPosition(startPosition)
            return nil
        }

        // Trim one space from each end if present
        if content.hasPrefix(" ") && content.hasSuffix(" ") && content.count > 2 {
            content = String(content.dropFirst().dropLast())
        }

        return AST.CodeSpanNode(
            content: content,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    // MARK: - Inline Math

    private func parseInlineMath() throws -> AST.InlineMathNode? {
        let startPosition = tokenStream.currentPosition
        let startLocation = tokenStream.current.location

        // Must be a single $, not $$
        guard tokenStream.current.content == "$" else {
            return nil
        }

        // Consume opening $
        tokenStream.advance()

        // Reject if next token is whitespace (space after opening $ = not math)
        if tokenStream.current.type == .whitespace {
            tokenStream.setPosition(startPosition)
            return nil
        }

        var content = ""
        var foundClosing = false

        while !tokenStream.isAtEnd {
            let token = tokenStream.current

            // Inline math cannot span lines
            if token.type == .newline {
                break
            }

            // Check for closing $
            if token.type == .dollarSign && token.content == "$" {
                tokenStream.advance()
                foundClosing = true
                break
            }

            content += token.content
            tokenStream.advance()
        }

        guard foundClosing else {
            tokenStream.setPosition(startPosition)
            return nil
        }

        // Reject if content is empty
        guard !content.isEmpty else {
            tokenStream.setPosition(startPosition)
            return nil
        }

        // Reject if content ends with space
        if content.hasSuffix(" ") {
            tokenStream.setPosition(startPosition)
            return nil
        }

        return AST.InlineMathNode(
            content: content,
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    // MARK: - Links and Images

    private func parseLinkOrImage(startingAt explicitStart: SourceLocation? = nil) throws -> (any ASTNode)? {
        let startLocation = explicitStart ?? tokenStream.current.location
        let linkStartPosition = tokenStream.currentPosition

        // Check if this is an image (preceded by !)
        let isImage = tokenStream.currentPosition > 0 &&
                     tokenStream.peek(-1).type == .exclamation

        guard tokenStream.match(.leftBracket) else { return parseText() }

        let afterBracketPosition = tokenStream.currentPosition

        // Scan ahead to find the matching ] tracking bracket depth
        var bracketDepth = 1
        var rightBracketPosition: Int?
        while !tokenStream.isAtEnd {
            let token = tokenStream.current
            if token.type == .newline || token.type == .eof {
                break
            }
            if token.type == .leftBracket {
                bracketDepth += 1
            } else if token.type == .rightBracket {
                bracketDepth -= 1
                if bracketDepth == 0 {
                    rightBracketPosition = tokenStream.currentPosition
                    break
                }
            }
            tokenStream.advance()
        }

        // If no matching ] found, restore and treat [ as text
        guard let rbPos = rightBracketPosition else {
            tokenStream.setPosition(linkStartPosition)
            return parseText()
        }

        // Restore to after [ and parse link text with bounded loop
        tokenStream.setPosition(afterBracketPosition)

        var linkText: [any ASTNode] = []

        while !tokenStream.isAtEnd && tokenStream.currentPosition < rbPos {
            let posBeforeInline = tokenStream.currentPosition
            let inlineNodes = try parseInline()

            // If parseInline() consumed past the ] boundary, backtrack and consume as text
            if tokenStream.currentPosition > rbPos {
                tokenStream.setPosition(posBeforeInline)
                linkText.append(parseText())
                continue
            }

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

            return AST.TextNode(
                content: "[\(linkTextContent)",
                sourceLocation: tokenStream.range(startingAt: startLocation)
            )
        }

        // Check for inline link: [text](url "title")
        if tokenStream.check(.leftParen) {
            if let link = try parseInlineLink(
                linkText: linkText,
                isImage: isImage,
                startLocation: startLocation
            ) {
                return link
            }
            tokenStream.setPosition(linkStartPosition)
            return parseText()
        }

        // Check for reference link: [text][ref] or [text][]
        if tokenStream.check(.leftBracket) {
            if let link = try parseReferenceLink(
                linkText: linkText,
                isImage: isImage,
                startLocation: startLocation
            ) {
                return link
            }
            tokenStream.setPosition(linkStartPosition)
            return parseText()
        }

        // Shortcut reference link: [ref]
        let refLabel = linkText.compactMap { node in
            if let textNode = node as? AST.TextNode {
                return textNode.content
            }
            return nil
        }.joined()

        if let reference = linkReferences[ReferenceDefinitionResolver.normalizeLabel(refLabel)] {
            if isImage {
                return AST.ImageNode(
                    url: reference.url,
                    altText: refLabel,
                    title: reference.title,
                    sourceLocation: tokenStream.range(startingAt: startLocation)
                )
            } else {
                return AST.LinkNode(
                    url: reference.url,
                    title: reference.title,
                    children: linkText,
                    sourceLocation: tokenStream.range(startingAt: startLocation)
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

        return AST.TextNode(
            content: "[\(linkTextContent)]",
            sourceLocation: tokenStream.range(startingAt: startLocation)
        )
    }

    private func parseImage() throws -> (any ASTNode)? {
        let startPosition = tokenStream.currentPosition
        let startLocation = tokenStream.current.location
        guard tokenStream.match(.exclamation) else { return parseText() }
        guard let image = try parseLinkOrImage(startingAt: startLocation) else {
            tokenStream.setPosition(startPosition)
            return parseText()
        }
        return image
    }

    private func parseInlineLink(linkText: [any ASTNode], isImage: Bool, startLocation: SourceLocation) throws -> (any ASTNode)? {
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
                sourceLocation: tokenStream.range(startingAt: startLocation)
            )
        } else {
            return AST.LinkNode(
                url: url,
                title: title,
                children: linkText,
                sourceLocation: tokenStream.range(startingAt: startLocation)
            )
        }
    }

    private func parseReferenceLink(linkText: [any ASTNode], isImage: Bool, startLocation: SourceLocation) throws -> (any ASTNode)? {
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

        guard let reference = linkReferences[ReferenceDefinitionResolver.normalizeLabel(refLabel)] else {
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
                sourceLocation: tokenStream.range(startingAt: startLocation)
            )
        } else {
            return AST.LinkNode(
                url: reference.url,
                title: reference.title,
                children: linkText,
                sourceLocation: tokenStream.range(startingAt: startLocation)
            )
        }
    }

    // MARK: - Other Inline Elements

    private func parseEscapedCharacter() -> (any ASTNode)? {
        let token = tokenStream.consume()

        // Remove the backslash and return the escaped character
        // A backslash with nothing after it is literal
        let escapedContent = token.content.count > 1 ? String(token.content.dropFirst()) : "\\"
        return AST.TextNode(content: escapedContent, sourceLocation: token.location)
    }

    private func parseAutolink() -> AST.AutolinkNode? {
        let token = tokenStream.consume()
        let displayText = token.content.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        let url: String
        if displayText.contains("@") && !displayText.contains("://") {
            url = "mailto:" + displayText
        } else if displayText.hasPrefix("www.") {
            url = "https://" + displayText
        } else {
            url = displayText
        }

        return AST.AutolinkNode(url: url, text: displayText, sourceLocation: token.location)
    }

    private func parseStrikethrough() throws -> (any ASTNode)? {
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

        var content: [any ASTNode] = []
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
            return AST.StrikethroughNode(
                content: content,
                sourceLocation: tokenStream.range(startingAt: startLocation)
            )
        } else {
            // No closing delimiter found, backtrack and treat as text
            tokenStream.setPosition(startPosition)
            return nil
        }
    }

}
