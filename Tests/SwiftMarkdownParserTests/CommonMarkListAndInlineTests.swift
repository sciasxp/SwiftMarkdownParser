import Testing
@testable import SwiftMarkdownParser

/// CommonMark 0.30 behavior of a literal `!`, list nesting at the item's
/// content column, and tight versus loose lists, checked from Markdown source
/// through the default HTML fragment.
@Suite struct CommonMarkListAndInlineTests {

    private func html(_ markdown: String) async throws -> String {
        let document = try SwiftMarkdownParser().parse(markdown)
        return try await HTMLRenderer().renderFragment(document)
    }

    // MARK: - Literal exclamation mark

    @Test(arguments: [
        ("Start writing!", "<p>Start writing!</p>\n"),
        ("a ! b", "<p>a ! b</p>\n"),
        ("Wow!!", "<p>Wow!!</p>\n"),
        ("!", "<p>!</p>\n"),
        ("Hi! [link](https://example.com)", "<p>Hi! <a href=\"https://example.com\">link</a></p>\n"),
        ("![alt](x.png)", "<p><img alt=\"alt\" src=\"x.png\" /></p>\n")
    ])
    func exclamation_notStartingImage_isKeptAsText(markdown: String, expected: String) async throws {
        #expect(try await html(markdown) == expected)
    }

    @Test func exclamation_endingListItem_isKeptAsText() async throws {
        #expect(try await html("- Go!\n") == "<ul>\n<li>Go!</li>\n</ul>\n")
    }

    @Test func exclamation_beforeBracketsThatAreNotAnImage_isKeptAsText() async throws {
        #expect(try await html("Hey![not a link]") == "<p>Hey![not a link]</p>\n")
    }

    // MARK: - Nesting at the content column

    @Test func orderedList_bulletsIndentedToContentColumn_nestInsideItem() async throws {
        let expected = "<ol>\n<li>One\n<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n</li>\n<li>Two</li>\n</ol>\n"
        #expect(try await html("1. One\n   - a\n   - b\n2. Two\n") == expected)
    }

    @Test func bulletList_bulletsIndentedToContentColumn_nestInsideItem() async throws {
        let expected = "<ul>\n<li>One\n<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n</li>\n<li>Two</li>\n</ul>\n"
        #expect(try await html("- One\n  - a\n  - b\n- Two\n") == expected)
    }

    @Test func orderedList_bulletsIndentedFourSpaces_stillNestInsideItem() async throws {
        let expected = "<ol>\n<li>One\n<ul>\n<li>a</li>\n</ul>\n</li>\n<li>Two</li>\n</ol>\n"
        #expect(try await html("1. One\n    - a\n2. Two\n") == expected)
    }

    @Test func bulletList_bulletsIndentedFourSpaces_stillNestInsideItem() async throws {
        let expected = "<ul>\n<li>One\n<ul>\n<li>a</li>\n</ul>\n</li>\n<li>Two</li>\n</ul>\n"
        #expect(try await html("- One\n    - a\n- Two\n") == expected)
    }

    @Test func bulletList_markerBelowContentColumn_staysSibling() async throws {
        let expected = "<ul>\n<li>One</li>\n<li>a</li>\n</ul>\n"
        #expect(try await html("- One\n - a\n") == expected)
    }

    @Test func looseOrderedList_nestedBullets_nestInsideEachItem() async throws {
        let markdown = "1. **Getting Started**\n   - Install the app\n\n"
            + "2. **Advanced Features**\n   - Custom themes\n"
        let expected = "<ol>\n<li><p><strong>Getting Started</strong></p>\n"
            + "<ul>\n<li>Install the app</li>\n</ul>\n</li>\n"
            + "<li><p><strong>Advanced Features</strong></p>\n<ul>\n<li>Custom themes</li>\n</ul>\n</li>\n</ol>\n"
        #expect(try await html(markdown) == expected)
    }

    @Test func nestedList_threeLevels_nestAtEachContentColumn() async throws {
        let expected = "<ul>\n<li>a\n<ul>\n<li>b\n<ul>\n<li>c</li>\n</ul>\n</li>\n</ul>\n</li>\n<li>d</li>\n</ul>\n"
        #expect(try await html("- a\n  - b\n    - c\n- d\n") == expected)
    }

    @Test func nestedList_unindentedBlockAfterBlankLine_endsOuterList() async throws {
        let expected = "<ol>\n<li>One\n<ul>\n<li>a</li>\n</ul>\n</li>\n</ol>\n<h3>Next</h3>\n"
        #expect(try await html("1. One\n   - a\n\n### Next\n") == expected)
    }

    // MARK: - Tight and loose lists

    @Test func tightList_items_renderWithoutParagraphs() async throws {
        #expect(try await html("- a\n- b\n") == "<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n")
    }

    @Test func looseList_blankLineBetweenItems_rendersParagraphs() async throws {
        #expect(try await html("- a\n\n- b\n") == "<ul>\n<li><p>a</p>\n</li>\n<li><p>b</p>\n</li>\n</ul>\n")
    }

    @Test func looseList_blankLineBetweenBlocksOfItem_rendersParagraphs() async throws {
        let expected = "<ul>\n<li><p>a</p>\n<p>c</p>\n</li>\n<li><p>b</p>\n</li>\n</ul>\n"
        #expect(try await html("- a\n\n  c\n- b\n") == expected)
    }

    @Test func tightList_trailingBlankLine_staysTight() async throws {
        #expect(try await html("- a\n- b\n\nafter\n") == "<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n<p>after</p>\n")
    }

    @Test func listTightness_isRecordedOnListNode() throws {
        let tight = try SwiftMarkdownParser().parse("- a\n- b\n")
        let loose = try SwiftMarkdownParser().parse("- a\n\n- b\n")
        #expect((tight.children.first as? AST.ListNode)?.isTight == true)
        #expect((loose.children.first as? AST.ListNode)?.isTight == false)
    }
}
