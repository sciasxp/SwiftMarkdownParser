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

    @Test(arguments: [
        "javascript:\u{301}alert(1)",
        "data:\u{200D}text/html,x",
        "file:\u{301}///etc/passwd",
        "javascript:\u{200C}alert(1)",
        "javascript:\u{FE0F}alert(1)",
        "javascript:\u{FE00}alert(1)",
        "javascript:\u{20E3}alert(1)",
        "javascript:\u{338}alert(1)",
        "javascript:\u{E0101}alert(1)",
        "vbscript:\u{301}msgbox(1)",
        "javascript\u{301}:alert(1)",
        "java\u{200D}script:alert(1)"
    ])
    func resolve_markOrJoinerAroundSchemeColon_returnsNil(destination: String) {
        #expect(MarkdownDestination.resolve(destination, relativeTo: nil) == nil)
        #expect(MarkdownDestination.resolve(destination, relativeTo: webBase) == nil)
        #expect(MarkdownDestination.resolve(destination, relativeTo: fileBase) == nil)
    }

    @Test func resolve_tabsAndNewlinesInsideAllowedURL_removesThem() {
        let url = MarkdownDestination.resolve(" https://exam\tple.com/a\nb\r\nc ", relativeTo: nil)

        #expect(url?.absoluteString == "https://example.com/abc")
    }

    @Test(arguments: ["", "   ", "\t\n", "\u{00}"])
    func resolve_emptyWithoutBase_returnsEmptyReference(destination: String) {
        let url = MarkdownDestination.resolve(destination, relativeTo: nil)

        #expect(url?.absoluteString == "")
        #expect(url?.scheme == nil)
    }

    @Test func resolve_emptyWithBase_returnsBaseWithoutFragment() {
        let base = URL(string: "https://example.com/docs/guide.html?x=1#frag")!

        #expect(
            MarkdownDestination.resolve("", relativeTo: base)?.absoluteString
                == "https://example.com/docs/guide.html?x=1"
        )
        #expect(MarkdownDestination.resolve(" ", relativeTo: fileBase)?.absoluteString == "file:///Users/reader/docs/")
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

    @Test(arguments: protocolRelativeDestinations + ["///evil.com/a.png"])
    func resolve_protocolRelativeWithoutBase_returnsNil(destination: String) {
        #expect(MarkdownDestination.resolve(destination, relativeTo: nil) == nil)
    }

    @Test(arguments: ["\\\\evil.com/a.png", "/\\evil.com/a.png", "/    /evil.com/a.png"])
    func resolve_slashLookalikeWithoutBase_keepsPathWithoutHost(destination: String) {
        let url = MarkdownDestination.resolve(destination, relativeTo: nil)

        #expect(url?.host == nil)
        #expect(url?.absoluteString.hasPrefix("//") == false)
    }

    @Test(arguments: protocolRelativeDestinations + [
        "//evil.com/share", "//localhost/etc/passwd", "//:80/x", "//:80", "//"
    ])
    func resolve_protocolRelativeWithFileBase_returnsNil(destination: String) {
        #expect(MarkdownDestination.resolve(destination, relativeTo: fileBase) == nil)
    }

    @Test func resolve_absolutePathReferenceWithFileBase_keepsLocalFile() {
        #expect(MarkdownDestination.resolve("///etc/hosts", relativeTo: fileBase)?.absoluteString == "file:///etc/hosts")
    }

    @Test func resolve_relativeWithFileShareBase_keepsBaseHost() {
        let shareBase = URL(string: "file://server/share/")!

        #expect(
            MarkdownDestination.resolve("img.png", relativeTo: shareBase)?.absoluteString
                == "file://server/share/img.png"
        )
    }

    @Test(arguments: ["//cdn.example/logo.png", "\u{00A0}//cdn.example/logo.png", "/\t/cdn.example/logo.png"])
    func resolve_protocolRelativeWithWebBase_keepsBaseScheme(destination: String) {
        #expect(
            MarkdownDestination.resolve(destination, relativeTo: webBase)?.absoluteString
                == "https://cdn.example/logo.png"
        )
    }

    @Test func resolve_charactersInvalidInURL_percentEncodes() {
        #expect(MarkdownDestination.resolve("my page.html", relativeTo: nil)?.absoluteString == "my%20page.html")
    }
}

/// Destinations that are protocol-relative once normalized, including those
/// whose two slashes are only joined by trimming or by removing TAB, LF, or CR.
let protocolRelativeDestinations = [
    "//evil.com/a.png",
    "//evil.com",
    " //evil.com/a.png ",
    "\u{00A0}//evil.com/a.png",
    "\u{200B}//evil.com/a.png",
    "\u{3000}//evil.com/a.png",
    "\u{2028}//evil.com/a.png",
    "\u{01}//evil.com/a.png",
    "/\t/evil.com/a.png",
    "/\n/evil.com/a.png",
    "/\r\n/evil.com/a.png"
]
