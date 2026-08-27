import Foundation

/// Structured host input consumed while assembling a complete HTML document.
public struct HTMLDocumentAssembly: Sendable, Equatable {
    public let metadata: HTMLDocumentMetadata
    public let styles: [String]
    public let scripts: [String]
    public let regions: [HTMLDocumentRegion]

    public init(
        metadata: HTMLDocumentMetadata = .init(),
        styles: [String] = [],
        scripts: [String] = [],
        regions: [HTMLDocumentRegion] = []
    ) {
        self.metadata = metadata
        self.styles = styles
        self.scripts = scripts
        self.regions = regions
    }
}

/// Replaces a pair of rendered marker elements with one addressable document region.
public struct HTMLDocumentRegion: Sendable, Equatable {
    public let id: String
    public let startMarker: String
    public let endMarker: String

    public init(id: String, startMarker: String, endMarker: String) {
        self.id = id
        self.startMarker = startMarker
        self.endMarker = endMarker
    }
}

struct HTMLDocumentHostAssembler {
    struct Content {
        let language: String
        let title: String
        let body: String
        let styles: String
        let scripts: String
    }

    let assembly: HTMLDocumentAssembly

    func assemble(body: String) throws -> Content {
        Content(
            language: RendererUtils.escapeHTMLAttribute(assembly.metadata.language),
            title: RendererUtils.escapeHTML(assembly.metadata.title),
            body: try projectRegions(into: body),
            styles: assembly.styles.map { "<style>\n\($0)\n</style>" }.joined(separator: "\n"),
            scripts: assembly.scripts.map { "<script>\n\($0)\n</script>" }.joined(separator: "\n")
        )
    }

    private func projectRegions(into body: String) throws -> String {
        var projectedBody = body
        for region in assembly.regions {
            guard region.id.isEmpty == false,
                  region.startMarker.isEmpty == false,
                  region.endMarker.isEmpty == false,
                  let startRange = uniqueRange(of: region.startMarker, in: projectedBody),
                  let endRange = uniqueRange(of: region.endMarker, in: projectedBody),
                  startRange.upperBound <= endRange.lowerBound else {
                throw HTMLRenderingError.invalidDocumentRegion(region.id)
            }

            projectedBody.replaceSubrange(endRange, with: "</div>")
            let id = RendererUtils.escapeHTMLAttribute(region.id)
            projectedBody.replaceSubrange(startRange, with: "<div id=\"\(id)\">")
        }
        return projectedBody
    }

    private func uniqueRange(of marker: String, in source: String) -> Range<String.Index>? {
        guard let range = source.range(of: marker),
              source.range(of: marker, range: range.upperBound..<source.endIndex) == nil else {
            return nil
        }
        return range
    }
}
