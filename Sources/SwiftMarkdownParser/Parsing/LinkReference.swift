/// A normalized link reference discovered while constructing a Markdown document.
public struct LinkReference: Sendable, Equatable {
    public let url: String
    public let title: String?
    public let sourceLocation: SourceLocation?

    public init(url: String, title: String? = nil, sourceLocation: SourceLocation? = nil) {
        self.url = url
        self.title = title
        self.sourceLocation = sourceLocation
    }
}
