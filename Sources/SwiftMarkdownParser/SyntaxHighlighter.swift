import Foundation

/// Internal adapter seam implemented by each built-in language highlighter.
protocol SyntaxHighlightingEngine: Sendable {
    func highlight(_ code: String, language: String) async throws -> [SyntaxToken]
    func supportedLanguages() -> Set<String>
}

enum SyntaxHighlightingError: Error, LocalizedError, Sendable {
    case unsupportedLanguage(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedLanguage(let language):
            return "Unsupported language: \(language)"
        }
    }
}

/// Selects a built-in language adapter, applies best-effort fallback, and
/// reuses valid semantic tokens through a bounded in-memory cache.
///
/// Unsupported languages and adapter failures return `nil`, allowing output
/// renderers to preserve the original code as plain escaped text.
public actor SyntaxHighlighter {
    private static let defaultCacheCapacity = 128

    private struct Adapter: Sendable {
        let engine: any SyntaxHighlightingEngine
    }

    private struct CacheKey: Hashable, Sendable {
        let language: String
        let code: String
    }

    /// Cached ranges use character offsets because `String.Index` values only
    /// belong to the source string instance that created them.
    private struct CachedToken: Sendable {
        let content: String
        let tokenType: SyntaxTokenType
        let lowerOffset: Int
        let upperOffset: Int
    }

    private let adaptersByLanguage: [String: Adapter]
    private let cacheCapacity: Int
    private var cache: [CacheKey: [CachedToken]] = [:]
    private var lastAccessByKey: [CacheKey: UInt64] = [:]
    private var accessSequence: UInt64 = 0

    public init() {
        let engines: [any SyntaxHighlightingEngine] = [
            JavaScriptSyntaxEngine(),
            TypeScriptSyntaxEngine(),
            SwiftSyntaxEngine(),
            KotlinSyntaxEngine(),
            PythonSyntaxEngine(),
            BashSyntaxEngine(),
        ]
        self.adaptersByLanguage = Self.makeAdapters(from: engines)
        self.cacheCapacity = Self.defaultCacheCapacity
    }

    init(
        engines: [any SyntaxHighlightingEngine],
        cacheCapacity: Int = SyntaxHighlighter.defaultCacheCapacity
    ) {
        self.adaptersByLanguage = Self.makeAdapters(from: engines)
        self.cacheCapacity = max(0, cacheCapacity)
    }

    /// The normalized language identifiers accepted by the installed adapters.
    public var supportedLanguages: Set<String> {
        Set(adaptersByLanguage.keys)
    }

    /// Returns sorted, non-overlapping tokens whose ranges belong to `code`.
    /// Returns `nil` when the language is unsupported or highlighting fails.
    public func highlight(_ code: String, language: String) async -> [SyntaxToken]? {
        let normalizedLanguage = Self.normalize(language)
        guard let adapter = adaptersByLanguage[normalizedLanguage] else {
            return nil
        }

        let key = CacheKey(language: normalizedLanguage, code: code)
        if let cachedTokens = cachedTokens(for: key, source: code) {
            return cachedTokens
        }

        do {
            let tokens = try await adapter.engine.highlight(code, language: normalizedLanguage)
            guard Self.tokensAreValid(tokens, for: code) else {
                return nil
            }

            store(tokens, for: key, source: code)
            return tokens
        } catch {
            return nil
        }
    }

    private static func makeAdapters(
        from engines: [any SyntaxHighlightingEngine]
    ) -> [String: Adapter] {
        var adapters: [String: Adapter] = [:]

        for engine in engines {
            for language in engine.supportedLanguages() {
                let normalizedLanguage = normalize(language)
                precondition(
                    !normalizedLanguage.isEmpty,
                    "Syntax highlighting adapters must declare a language."
                )
                precondition(
                    adapters[normalizedLanguage] == nil,
                    "Duplicate syntax highlighting adapter for \(normalizedLanguage)."
                )
                adapters[normalizedLanguage] = Adapter(engine: engine)
            }
        }

        return adapters
    }

    private static func normalize(_ language: String) -> String {
        language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func tokensAreValid(_ tokens: [SyntaxToken], for source: String) -> Bool {
        var previousUpperBound = source.startIndex

        for token in tokens {
            guard
                token.range.lowerBound >= previousUpperBound,
                token.range.upperBound >= token.range.lowerBound,
                token.range.upperBound <= source.endIndex,
                source[token.range] == token.content
            else {
                return false
            }
            previousUpperBound = token.range.upperBound
        }

        return true
    }

    private func cachedTokens(for key: CacheKey, source: String) -> [SyntaxToken]? {
        guard let cachedTokens = cache[key] else {
            return nil
        }

        guard let tokens = Self.materialize(cachedTokens, in: source) else {
            cache.removeValue(forKey: key)
            lastAccessByKey.removeValue(forKey: key)
            return nil
        }

        touch(key)
        return tokens
    }

    private func store(_ tokens: [SyntaxToken], for key: CacheKey, source: String) {
        guard cacheCapacity > 0 else {
            return
        }

        cache[key] = Self.cachedRepresentation(of: tokens, in: source)
        touch(key)

        while cache.count > cacheCapacity,
              let oldestKey = lastAccessByKey.min(by: { $0.value < $1.value })?.key {
            cache.removeValue(forKey: oldestKey)
            lastAccessByKey.removeValue(forKey: oldestKey)
        }
    }

    private func touch(_ key: CacheKey) {
        accessSequence += 1
        lastAccessByKey[key] = accessSequence
    }

    private static func cachedRepresentation(
        of tokens: [SyntaxToken],
        in source: String
    ) -> [CachedToken] {
        var result: [CachedToken] = []
        result.reserveCapacity(tokens.count)
        var cursor = source.startIndex
        var cursorOffset = 0

        for token in tokens {
            let lowerOffset = cursorOffset
                + source.distance(from: cursor, to: token.range.lowerBound)
            let upperOffset = lowerOffset
                + source.distance(from: token.range.lowerBound, to: token.range.upperBound)
            result.append(CachedToken(
                content: token.content,
                tokenType: token.tokenType,
                lowerOffset: lowerOffset,
                upperOffset: upperOffset
            ))
            cursor = token.range.upperBound
            cursorOffset = upperOffset
        }

        return result
    }

    private static func materialize(
        _ cachedTokens: [CachedToken],
        in source: String
    ) -> [SyntaxToken]? {
        var result: [SyntaxToken] = []
        result.reserveCapacity(cachedTokens.count)
        var cursor = source.startIndex
        var cursorOffset = 0

        for token in cachedTokens {
            guard
                token.lowerOffset >= cursorOffset,
                token.upperOffset >= token.lowerOffset,
                let lowerBound = source.index(
                    cursor,
                    offsetBy: token.lowerOffset - cursorOffset,
                    limitedBy: source.endIndex
                ),
                let upperBound = source.index(
                    lowerBound,
                    offsetBy: token.upperOffset - token.lowerOffset,
                    limitedBy: source.endIndex
                )
            else {
                return nil
            }

            result.append(SyntaxToken(
                content: token.content,
                tokenType: token.tokenType,
                range: lowerBound..<upperBound
            ))
            cursor = upperBound
            cursorOffset = token.upperOffset
        }

        return result
    }
}
