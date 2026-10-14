public import Foundation

/// The single error family produced while constructing a Markdown document.
public enum MarkdownParsingError: Error, LocalizedError, Sendable, Equatable {
    public enum Resource: String, Sendable, Equatable {
        case work
        case nestingDepth
    }

    case sourceTooLarge(limit: Int, actual: Int)
    case resourceLimitExceeded(resource: Resource, limit: Int, actual: Int)
    case internalInvariant(message: String, location: SourceLocation?)

    public var errorDescription: String? {
        switch self {
        case let .sourceTooLarge(limit, actual):
            return "Markdown source contains \(actual) characters; the limit is \(limit)."
        case let .resourceLimitExceeded(resource, limit, actual):
            return "Markdown parsing exceeded the \(resource.rawValue) limit of \(limit) (actual: \(actual))."
        case let .internalInvariant(message, location):
            if let location {
                return "Markdown parser invariant failed at line \(location.line), column \(location.column): \(message)"
            }
            return "Markdown parser invariant failed: \(message)"
        }
    }
}

/// Constructs renderer-independent Markdown documents.
public final class SwiftMarkdownParser: Sendable {
    /// Deterministic resource policy applied independently to every parse.
    public struct ResourceLimits: Sendable, Equatable {
        public let maximumSourceLength: Int
        public let maximumNestingDepth: Int
        public let maximumWork: Int

        public init(
            maximumSourceLength: Int = 2_000_000,
            maximumNestingDepth: Int = 100,
            maximumWork: Int = 25_000_000
        ) {
            precondition(maximumSourceLength > 0, "maximumSourceLength must be positive")
            precondition(maximumNestingDepth > 0, "maximumNestingDepth must be positive")
            precondition(maximumWork > 0, "maximumWork must be positive")
            self.maximumSourceLength = maximumSourceLength
            self.maximumNestingDepth = maximumNestingDepth
            self.maximumWork = maximumWork
        }

        public static let `default` = ResourceLimits()
    }

    private let resourceLimits: ResourceLimits

    /// Creates a parser with deterministic limits for each parse call.
    public init(resourceLimits: ResourceLimits = .default) {
        self.resourceLimits = resourceLimits
    }

    /// Parses Markdown into a validated renderer-independent document.
    public func parse(_ markdown: String) throws -> AST.DocumentNode {
        let sourceLength = markdown.count
        guard sourceLength <= resourceLimits.maximumSourceLength else {
            throw MarkdownParsingError.sourceTooLarge(
                limit: resourceLimits.maximumSourceLength,
                actual: sourceLength
            )
        }

        // Building the line table charges one unit per character; that is the
        // parse's up-front cost for the source.
        let budget = ParsingBudget(maximumWork: resourceLimits.maximumWork)
        let sourceText = MarkdownSourceText(markdown, budget: budget)
        let referenceResolution = ReferenceDefinitionResolver.resolve(in: sourceText)
        let tokenizer = MarkdownTokenizer(
            referenceResolution.sourceForParsing,
            budget: budget
        )
        let tokenStream = TokenStream(tokenizer.tokenize(), budget: budget)
        let blockParser = BlockParser(
            tokenStream: tokenStream,
            limits: resourceLimits,
            budget: budget,
            sourceText: referenceResolution.sourceForParsing,
            linkReferences: referenceResolution.references
        )

        let document = try blockParser.parseDocument()
        try budget.validate()
        try MarkdownDocumentValidator.validate(document, sourceLength: sourceLength)
        return document
    }
}
