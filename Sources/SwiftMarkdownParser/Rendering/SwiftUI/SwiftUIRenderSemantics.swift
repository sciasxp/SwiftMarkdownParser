/// Output-specific semantic decisions that are not part of Native Inline Projection.
enum SwiftUIRenderSemantics {
    struct CodeRun: Equatable, Sendable {
        let text: String
        let tokenType: SyntaxTokenType?
    }

    static func orderedListMarker(startNumber: Int?, index: Int) -> String {
        let start = startNumber ?? 1
        return "\(start + index)."
    }

    /// Fills the gaps between semantic tokens so the rendered text exactly matches the source.
    static func codeRuns(source: String, tokens: [SyntaxToken]) -> [CodeRun] {
        var result: [CodeRun] = []
        var cursor = source.startIndex

        for token in tokens {
            if cursor < token.range.lowerBound {
                result.append(CodeRun(text: String(source[cursor..<token.range.lowerBound]), tokenType: nil))
            }
            result.append(CodeRun(text: token.content, tokenType: token.tokenType))
            cursor = token.range.upperBound
        }

        if cursor < source.endIndex {
            result.append(CodeRun(text: String(source[cursor...]), tokenType: nil))
        }

        return result
    }
}
