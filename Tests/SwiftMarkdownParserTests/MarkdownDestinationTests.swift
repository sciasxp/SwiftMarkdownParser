import Foundation
import Testing
@testable import SwiftMarkdownParser

@Suite struct MarkdownDestinationTests {
    private let webBase = URL(string: "https://example.com/docs/guide.html")!
    private let fileBase = URL(fileURLWithPath: "/Users/reader/docs/", isDirectory: true)

    @Test(arguments: [
        "https://example.com/page",
        "http://example.com/page",
        "HTTPS://example.com/page",
        "mailto:reader@example.com"
    ])
    func resolve_allowedScheme_returnsDestination(destination: String) {
        #expect(MarkdownDestination.resolve(destination, relativeTo: nil)?.absoluteString == destination)
    }

    @Test(arguments: ["page.html", "../images/logo.png", "#section", "?query=1", "/root"])
    func resolve_relativeWithoutBase_keepsRelativeReference(destination: String) {
        let url = MarkdownDestination.resolve(destination, relativeTo: nil)

        #expect(url?.absoluteString == destination)
        #expect(url?.scheme == nil)
    }

    @Test(arguments: [
        "javascript:alert(1)",
        "JavaScript:alert(1)",
        "vbscript:msgbox(1)",
        "data:text/html,<script>alert(1)</script>",
        "file:///etc/passwd",
        "ftp://example.com/file",
        "made-up-scheme:value",
        "localhost:5001"
    ])
    func resolve_schemeOutsideAllowlist_returnsNil(destination: String) {
        #expect(MarkdownDestination.resolve(destination, relativeTo: nil) == nil)
        #expect(MarkdownDestination.resolve(destination, relativeTo: webBase) == nil)
    }

    @Test(arguments: [
        "java\tscript:alert(1)",
        "java\nscript:alert(1)",
        "java\rscript:alert(1)",
        "java\r\nscript:alert(1)",
        "\u{01}javascript:alert(1)",
        " \t javascript:alert(1) \n",
        "da\tta:text/html,x",
        "fi\nle:///etc/passwd"
    ])
    func resolve_controlCharactersHidingScheme_returnsNil(destination: String) {
        #expect(MarkdownDestination.resolve(destination, relativeTo: nil) == nil)
        #expect(MarkdownDestination.resolve(destination, relativeTo: webBase) == nil)
    }

    @Test func resolve_tabsAndNewlinesInsideAllowedURL_removesThem() {
        let url = MarkdownDestination.resolve(" https://exam\tple.com/a\nb\r\nc ", relativeTo: nil)

        #expect(url?.absoluteString == "https://example.com/abc")
    }

    @Test(arguments: ["", "   ", "\t\n", "\u{00}"])
    func resolve_emptyAfterNormalization_returnsNil(destination: String) {
        #expect(MarkdownDestination.resolve(destination, relativeTo: nil) == nil)
        #expect(MarkdownDestination.resolve(destination, relativeTo: webBase) == nil)
    }

    @Test func resolve_relativeWithBase_resolvesAgainstBase() {
        #expect(
            MarkdownDestination.resolve("../images/logo.png", relativeTo: webBase)?.absoluteString
                == "https://example.com/images/logo.png"
        )
        #expect(
            MarkdownDestination.resolve("#section", relativeTo: webBase)?.absoluteString
                == "https://example.com/docs/guide.html#section"
        )
    }

    @Test func resolve_absoluteWithBase_ignoresBase() {
        #expect(
            MarkdownDestination.resolve("https://other.example/page", relativeTo: webBase)?.absoluteString
                == "https://other.example/page"
        )
    }

    @Test func resolve_relativeWithFileBase_returnsFileURL() {
        let url = MarkdownDestination.resolve("images/logo.png", relativeTo: fileBase)

        #expect(url?.absoluteString == "file:///Users/reader/docs/images/logo.png")
    }

    @Test func resolve_charactersInvalidInURL_percentEncodes() {
        #expect(MarkdownDestination.resolve("my page.html", relativeTo: nil)?.absoluteString == "my%20page.html")
    }
}
