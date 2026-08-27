import Testing
@testable import SwiftMarkdownParser

@Suite("HTML document assembly")
struct HTMLDocumentAssemblyTests {
    @Test("Places host styles, scripts, and addressable regions in one pass")
    func structuredDocumentAssembly() async throws {
        let startMarker = "<host-region-start></host-region-start>"
        let endMarker = "<host-region-end></host-region-end>"
        let markdown = """
        \(startMarker)

        # Addressable

        \(endMarker)
        """
        let document = try SwiftMarkdownParser().parse(markdown)
        let assembly = HTMLDocumentAssembly(
            metadata: HTMLDocumentMetadata(title: "Host Presentation", language: "pt-BR"),
            styles: [".host-presentation { color: rebeccapurple; }"],
            scripts: ["window.hostPresentationReady = true;"],
            regions: [
                HTMLDocumentRegion(
                    id: "host-region-\"1",
                    startMarker: startMarker,
                    endMarker: endMarker
                )
            ]
        )

        let renderer = HTMLRenderer(options: HTMLRenderOptions(sanitizeHTML: false))
        let html = try await renderer.renderDocument(document, assembly: assembly)

        #expect(html.contains("<title>Host Presentation</title>"))
        #expect(html.contains("<style>\n.host-presentation { color: rebeccapurple; }\n</style>"))
        #expect(html.contains("<div id=\"host-region-&quot;1\"><h1>Addressable</h1>\n</div>"))
        #expect(html.contains("<script>\nwindow.hostPresentationReady = true;\n</script>"))
        #expect(!html.contains(startMarker))
        #expect(!html.contains(endMarker))
    }

    @Test("Rejects missing or ambiguous region markers")
    func invalidDocumentRegions() async throws {
        let marker = "<host-region></host-region>"
        let document = try SwiftMarkdownParser().parse("\(marker)\n\n\(marker)")
        let assembly = HTMLDocumentAssembly(
            regions: [
                HTMLDocumentRegion(
                    id: "ambiguous",
                    startMarker: marker,
                    endMarker: "<missing-region></missing-region>"
                )
            ]
        )

        await #expect(throws: HTMLRenderingError.self) {
            try await HTMLRenderer().renderDocument(document, assembly: assembly)
        }
    }
}
