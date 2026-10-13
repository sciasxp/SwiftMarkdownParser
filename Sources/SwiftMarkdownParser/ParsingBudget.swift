/// Per-parse deterministic resource accounting. A budget is never shared
/// between parser calls, so `SwiftMarkdownParser` remains immutable and safe to
/// use concurrently.
final class ParsingBudget {
    private let maximumWork: Int
    private(set) var consumedWork = 0

    init(maximumWork: Int) {
        self.maximumWork = maximumWork
    }

    var isExhausted: Bool {
        consumedWork > maximumWork
    }

    func consumeWork(_ units: Int = 1) {
        guard units > 0 else { return }
        consumedWork = consumedWork > Int.max - units ? Int.max : consumedWork + units
    }

    func validate() throws {
        if isExhausted {
            throw MarkdownParsingError.resourceLimitExceeded(
                resource: .work,
                limit: maximumWork,
                actual: consumedWork
            )
        }
    }
}
