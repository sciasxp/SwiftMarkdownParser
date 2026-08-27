import Testing
@testable import SwiftMarkdownParser

@Suite("Syntax highlighting module")
struct SyntaxHighlighterTests {
    @Test("Publishes only identifiers backed by built-in adapters")
    func supportedLanguagesAreTruthful() async {
        let highlighter = SyntaxHighlighter()

        let languages = await highlighter.supportedLanguages

        #expect(languages == [
            "bash", "javascript", "js", "jsx", "kotlin", "kt", "py", "python",
            "sh", "shell", "swift", "ts", "tsx", "typescript", "zsh",
        ])
    }

    @Test(
        "Routes every built-in language identifier",
        arguments: [
            "bash", "javascript", "js", "jsx", "kotlin", "kt", "py", "python",
            "sh", "shell", "swift", "ts", "tsx", "typescript", "zsh",
        ]
    )
    func routesBuiltInLanguage(_ language: String) async {
        let highlighter = SyntaxHighlighter()

        let tokens = await highlighter.highlight("value = 1", language: language)

        #expect(tokens != nil)
    }

    @Test("Normalizes caller language identifiers")
    func normalizesLanguage() async {
        let counter = InvocationCounter()
        let highlighter = SyntaxHighlighter(
            engines: [FixtureSyntaxEngine(counter: counter)],
            cacheCapacity: 1
        )

        let tokens = await highlighter.highlight("source", language: "  FiXtUrE\n")

        #expect(tokens?.map(\.content) == ["source"])
    }

    @Test("Returns nil for unsupported languages without invoking adapters")
    func unsupportedLanguageFallsBack() async {
        let counter = InvocationCounter()
        let highlighter = SyntaxHighlighter(engines: [FixtureSyntaxEngine(counter: counter)])

        let tokens = await highlighter.highlight("source", language: "unknown")
        let invocationCount = await counter.value

        #expect(tokens == nil)
        #expect(invocationCount == 0)
    }

    @Test("Converts adapter failures into plain-output fallback")
    func adapterFailureFallsBack() async {
        let highlighter = SyntaxHighlighter(
            engines: [FixtureSyntaxEngine(outcome: .failure)]
        )

        let tokens = await highlighter.highlight("source", language: "fixture")

        #expect(tokens == nil)
    }

    @Test("Rejects overlapping semantic tokens")
    func invalidTokensFallBack() async {
        let highlighter = SyntaxHighlighter(
            engines: [FixtureSyntaxEngine(outcome: .overlappingTokens)]
        )

        let tokens = await highlighter.highlight("source", language: "fixture")

        #expect(tokens == nil)
    }

    @Test("Reuses cached work and rebinds ranges to an equal source string")
    func cacheHitUsesCurrentStringIndices() async throws {
        let counter = InvocationCounter()
        let highlighter = SyntaxHighlighter(
            engines: [FixtureSyntaxEngine(counter: counter)],
            cacheCapacity: 2
        )
        let firstSource = "let café = 1"
        let secondSource = String(decoding: Array(firstSource.utf8), as: UTF8.self)

        _ = await highlighter.highlight(firstSource, language: "fixture")
        let cachedResult = await highlighter.highlight(secondSource, language: "fixture")
        let tokens = try #require(cachedResult)
        let token = try #require(tokens.first)
        let invocationCount = await counter.value

        #expect(String(secondSource[token.range]) == "let café = 1")
        #expect(invocationCount == 1)
    }

    @Test("Rebinds separated cached tokens across Unicode source gaps")
    func cacheHitRebindsSeparatedUnicodeTokens() async throws {
        let counter = InvocationCounter()
        let highlighter = SyntaxHighlighter(
            engines: [FixtureSyntaxEngine(outcome: .separatedTokens, counter: counter)],
            cacheCapacity: 2
        )
        let firstSource = "let 🐼 = café + 1"
        let secondSource = String(decoding: Array(firstSource.utf8), as: UTF8.self)

        _ = await highlighter.highlight(firstSource, language: "fixture")
        let tokens = try #require(await highlighter.highlight(secondSource, language: "fixture"))
        let invocationCount = await counter.value

        #expect(tokens.map(\.content) == ["let", "café", "1"])
        #expect(tokens.allSatisfy { String(secondSource[$0.range]) == $0.content })
        #expect(invocationCount == 1)
    }

    @Test("Evicts the least recently used entry at capacity")
    func cacheEvictsLeastRecentlyUsedEntry() async {
        let counter = InvocationCounter()
        let highlighter = SyntaxHighlighter(
            engines: [FixtureSyntaxEngine(counter: counter)],
            cacheCapacity: 2
        )

        _ = await highlighter.highlight("first", language: "fixture")
        _ = await highlighter.highlight("second", language: "fixture")
        _ = await highlighter.highlight("first", language: "fixture")
        _ = await highlighter.highlight("third", language: "fixture")
        _ = await highlighter.highlight("first", language: "fixture")
        _ = await highlighter.highlight("second", language: "fixture")
        let invocationCount = await counter.value

        #expect(invocationCount == 4)
    }
}

private actor InvocationCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private struct FixtureSyntaxEngine: SyntaxHighlightingEngine {
    enum Outcome: Sendable {
        case highlighted
        case failure
        case overlappingTokens
        case separatedTokens
    }

    let outcome: Outcome
    let counter: InvocationCounter?

    init(
        outcome: Outcome = .highlighted,
        counter: InvocationCounter? = nil
    ) {
        self.outcome = outcome
        self.counter = counter
    }

    func supportedLanguages() -> Set<String> {
        ["fixture", "fx"]
    }

    func highlight(_ code: String, language: String) async throws -> [SyntaxToken] {
        await counter?.increment()

        switch outcome {
        case .highlighted:
            guard !code.isEmpty else { return [] }
            return [SyntaxToken(
                content: code,
                tokenType: .keyword,
                range: code.startIndex..<code.endIndex
            )]
        case .failure:
            throw FixtureError.failed
        case .overlappingTokens:
            let token = SyntaxToken(
                content: code,
                tokenType: .keyword,
                range: code.startIndex..<code.endIndex
            )
            return [token, token]
        case .separatedTokens:
            return ["let", "café", "1"].compactMap { content in
                code.range(of: content).map { range in
                    SyntaxToken(content: content, tokenType: .keyword, range: range)
                }
            }
        }
    }
}

private enum FixtureError: Error {
    case failed
}
