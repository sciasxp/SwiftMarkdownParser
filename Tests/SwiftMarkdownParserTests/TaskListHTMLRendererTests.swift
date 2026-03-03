import Testing
@testable import SwiftMarkdownParser

/// Test-driven development tests for task list HTML rendering
///
/// These tests define the expected behavior for task list HTML rendering,
/// ensuring proper HTML output with accessibility and semantic markup.
@Suite struct TaskListHTMLRendererTests {

    let parser: SwiftMarkdownParser

    init() async throws {
        let configuration = SwiftMarkdownParser.Configuration(
            enableGFMExtensions: true,
            strictMode: false,
            maxNestingDepth: 100,
            trackSourceLocations: true,
            maxParsingTime: 30.0
        )
        parser = SwiftMarkdownParser(configuration: configuration)
    }

    // MARK: - Basic HTML Rendering

    @Test func htmlRenderer_rendersCheckedTaskListItem() async throws {
        let markdown = "- [x] Completed task"
        let html = try await parser.parseToHTML(markdown)

        // Should contain proper task list HTML structure
        #expect(html.contains("<ul"), "Should contain unordered list")
        #expect(html.contains("</ul>"), "Should close unordered list")
        #expect(html.contains("<li"), "Should contain list item")
        #expect(html.contains("</li>"), "Should close list item")

        // Should contain checkbox input
        #expect(html.contains("<input"), "Should contain input element")
        #expect(html.contains("type=\"checkbox\""), "Should be checkbox type")
        #expect(html.contains("checked"), "Should be checked")
        #expect(html.contains("disabled"), "Should be disabled")

        // Should contain task content
        #expect(html.contains("Completed task"), "Should contain task text")

        // Should have proper accessibility
        #expect(html.contains("aria-label") || html.contains("aria-labelledby"), "Should have accessibility labels")
    }

    @Test func htmlRenderer_rendersUncheckedTaskListItem() async throws {
        let markdown = "- [ ] Incomplete task"
        let html = try await parser.parseToHTML(markdown)

        // Should contain proper task list HTML structure
        #expect(html.contains("<ul"), "Should contain unordered list")
        #expect(html.contains("<li"), "Should contain list item")

        // Should contain checkbox input
        #expect(html.contains("<input"), "Should contain input element")
        #expect(html.contains("type=\"checkbox\""), "Should be checkbox type")
        #expect(!html.contains(" checked"), "Should not be checked")
        #expect(html.contains("disabled"), "Should be disabled")

        // Should contain task content
        #expect(html.contains("Incomplete task"), "Should contain task text")
    }

    @Test func htmlRenderer_rendersTaskListWithVariousCheckMarkers() async throws {
        let testCases = [
            ("- [x] Checked with x", true),
            ("- [X] Checked with X", true),
            ("- [ ] Unchecked with space", false),
            ("- [o] Checked with o", true),
            ("- [O] Checked with O", true),
            ("- [v] Checked with v", true),
            ("- [V] Checked with V", true)
        ]

        for (markdown, expectedChecked) in testCases {
            let html = try await parser.parseToHTML(markdown)

            // Should contain checkbox
            #expect(html.contains("type=\"checkbox\""), "Should contain checkbox for: \(markdown)")

            if expectedChecked {
                #expect(html.contains(" checked"), "Should be checked for: \(markdown)")
            } else {
                #expect(!html.contains(" checked"), "Should not be checked for: \(markdown)")
            }
        }
    }

    // MARK: - Multiple Task Lists

    @Test func htmlRenderer_rendersMultipleTaskListItems() async throws {
        let markdown = """
        - [x] First task
        - [ ] Second task
        - [X] Third task
        """

        let html = try await parser.parseToHTML(markdown)

        // Should contain one list with multiple items
        #expect(html.contains("<ul"), "Should contain unordered list")

        // Count list items
        let listItemCount = html.components(separatedBy: "<li").count - 1
        #expect(listItemCount == 3, "Should have 3 list items")

        // Count checkboxes
        let checkboxCount = html.components(separatedBy: "type=\"checkbox\"").count - 1
        #expect(checkboxCount == 3, "Should have 3 checkboxes")

        // Count checked boxes
        let checkedCount = html.components(separatedBy: " checked").count - 1
        #expect(checkedCount == 2, "Should have 2 checked boxes")

        // Should contain all task texts
        #expect(html.contains("First task"), "Should contain first task text")
        #expect(html.contains("Second task"), "Should contain second task text")
        #expect(html.contains("Third task"), "Should contain third task text")
    }

    // MARK: - Mixed Lists

    @Test func htmlRenderer_rendersMixedTaskListAndRegularList() async throws {
        let markdown = """
        - Regular item
        - [x] Task item
        - Another regular item
        """

        let html = try await parser.parseToHTML(markdown)

        // Should contain one list
        #expect(html.contains("<ul"), "Should contain unordered list")

        // Should have 3 list items
        let listItemCount = html.components(separatedBy: "<li").count - 1
        #expect(listItemCount == 3, "Should have 3 list items")

        // Should have only 1 checkbox (for the task item)
        let checkboxCount = html.components(separatedBy: "type=\"checkbox\"").count - 1
        #expect(checkboxCount == 1, "Should have 1 checkbox")

        // Should contain all texts
        #expect(html.contains("Regular item"), "Should contain regular item text")
        #expect(html.contains("Task item"), "Should contain task item text")
        #expect(html.contains("Another regular item"), "Should contain another regular item text")
    }

    // MARK: - Nested Task Lists

    @Test func htmlRenderer_rendersNestedTaskLists() async throws {
        let markdown = """
        - [x] Parent task
          - [x] Child task 1
          - [ ] Child task 2
        """

        let html = try await parser.parseToHTML(markdown)

        // Should contain list structure
        #expect(html.contains("<ul"), "Should contain unordered list")

        // Should have checkboxes for all tasks
        let checkboxCount = html.components(separatedBy: "type=\"checkbox\"").count - 1
        #expect(checkboxCount >= 3, "Should have at least 3 checkboxes")

        // Should contain all task texts
        #expect(html.contains("Parent task"), "Should contain parent task text")
        #expect(html.contains("Child task 1"), "Should contain child task 1 text")
        #expect(html.contains("Child task 2"), "Should contain child task 2 text")
    }

    // MARK: - Task Lists with Complex Content

    @Test func htmlRenderer_rendersTaskListWithInlineFormatting() async throws {
        let markdown = "- [x] Task with **bold** and *italic* text"
        let html = try await parser.parseToHTML(markdown)

        // Should contain checkbox
        #expect(html.contains("type=\"checkbox\""), "Should contain checkbox")
        #expect(html.contains(" checked"), "Should be checked")

        // Should contain inline formatting
        #expect(html.contains("<strong>") || html.contains("<b>"), "Should contain bold formatting")
        #expect(html.contains("<em>") || html.contains("<i>"), "Should contain italic formatting")

        // Should contain the text content
        #expect(html.contains("Task with"), "Should contain task text")
        #expect(html.contains("bold"), "Should contain bold text")
        #expect(html.contains("italic"), "Should contain italic text")
    }

    @Test func htmlRenderer_rendersTaskListWithLinks() async throws {
        let markdown = "- [x] Task with [a link](https://example.com)"
        let html = try await parser.parseToHTML(markdown)

        // Should contain checkbox
        #expect(html.contains("type=\"checkbox\""), "Should contain checkbox")

        // Should contain link
        #expect(html.contains("<a href=\"https://example.com\""), "Should contain link")
        #expect(html.contains("a link"), "Should contain link text")

        // Should contain task text
        #expect(html.contains("Task with"), "Should contain task text")
    }

    // MARK: - HTML Structure and Semantics

    @Test func htmlRenderer_usesSemanticHTMLStructure() async throws {
        let markdown = "- [x] Semantic task"
        let html = try await parser.parseToHTML(markdown)

        // Should use proper list structure
        #expect(html.contains("<ul"), "Should use unordered list")
        #expect(html.contains("<li"), "Should use list items")

        // Should use proper form elements
        #expect(html.contains("<input"), "Should use input element")
        #expect(html.contains("type=\"checkbox\""), "Should use checkbox type")

        // Should have proper nesting (checkbox inside list item)
        let ulIndex = html.firstIndex(of: "<")!
        let inputIndex = html.range(of: "<input")!.lowerBound
        #expect(ulIndex < inputIndex, "List should come before input")
    }

    @Test func htmlRenderer_includesAccessibilityAttributes() async throws {
        let markdown = "- [x] Accessible task"
        let html = try await parser.parseToHTML(markdown)

        // Should have accessibility attributes
        let hasAriaLabel = html.contains("aria-label")
        let hasAriaLabelledBy = html.contains("aria-labelledby")
        let hasAriaChecked = html.contains("aria-checked")

        #expect(hasAriaLabel || hasAriaLabelledBy || hasAriaChecked,
                "Should have accessibility attributes")

        // Should be disabled for read-only rendering
        #expect(html.contains("disabled"), "Should be disabled for read-only")
    }

    // MARK: - CSS Classes and Styling

    @Test func htmlRenderer_includesTaskListCSSClasses() async throws {
        let markdown = "- [x] Styled task"
        let html = try await parser.parseToHTML(markdown)

        // Should include CSS classes for styling
        let hasTaskListClass = html.contains("class=\"task-list\"") ||
                              html.contains("class=\"task-list-item\"") ||
                              html.contains("class=\"task-list-checkbox\"")

        #expect(hasTaskListClass, "Should include CSS classes for task lists")
    }

    // MARK: - Edge Cases

    @Test func htmlRenderer_handlesEmptyTaskContent() async throws {
        let markdown = "- [x] "
        let html = try await parser.parseToHTML(markdown)

        // Should still render checkbox even with empty content
        #expect(html.contains("type=\"checkbox\""), "Should contain checkbox")
        #expect(html.contains("checked"), "Should be checked")
        #expect(html.contains("<li"), "Should contain list item")
    }

    @Test func htmlRenderer_handlesSpecialCharactersInTaskContent() async throws {
        let markdown = "- [x] Task with <special> & \"quoted\" characters"
        let html = try await parser.parseToHTML(markdown)

        // Should contain checkbox
        #expect(html.contains("type=\"checkbox\""), "Should contain checkbox")

        // Should properly escape HTML characters
        #expect(html.contains("&lt;special&gt;") || html.contains("&lt;"), "Should escape < characters")
        #expect(html.contains("&amp;") || html.contains("&"), "Should handle & characters")
        #expect(html.contains("&quot;") || html.contains("\""), "Should handle quote characters")
    }

    // MARK: - Ordered Lists

    @Test func htmlRenderer_rendersOrderedTaskLists() async throws {
        let markdown = """
        1. [x] First numbered task
        2. [ ] Second numbered task
        """

        let html = try await parser.parseToHTML(markdown)

        // Should use ordered list
        #expect(html.contains("<ol"), "Should contain ordered list")
        #expect(html.contains("</ol>"), "Should close ordered list")

        // Should contain checkboxes
        let checkboxCount = html.components(separatedBy: "type=\"checkbox\"").count - 1
        #expect(checkboxCount == 2, "Should have 2 checkboxes")

        // Should contain task texts
        #expect(html.contains("First numbered task"), "Should contain first task text")
        #expect(html.contains("Second numbered task"), "Should contain second task text")
    }

    // MARK: - HTML Validation

    @Test func htmlRenderer_producesValidHTML() async throws {
        let markdown = """
        - [x] First task
        - [ ] Second task with **bold** text
        - [X] Third task with [link](https://example.com)
        """

        let html = try await parser.parseToHTML(markdown)

        // Basic HTML structure validation
        #expect(html.contains("<ul"), "Should have opening ul tag")
        #expect(html.contains("</ul>"), "Should have closing ul tag")

        // Count opening and closing li tags
        let openingLiCount = html.components(separatedBy: "<li").count - 1
        let closingLiCount = html.components(separatedBy: "</li>").count - 1
        #expect(openingLiCount == closingLiCount, "Should have matching li tags")

        // Ensure proper input tag structure
        let inputTags = html.components(separatedBy: "<input").dropFirst()
        for inputTag in inputTags {
            let endIndex = inputTag.firstIndex(of: ">") ?? inputTag.endIndex
            let inputContent = String(inputTag[..<endIndex])

            #expect(inputContent.contains("type=\"checkbox\""), "Input should have checkbox type")
            #expect(inputContent.contains("disabled"), "Input should be disabled")
        }
    }

    // MARK: - Enhanced Styling Tests

    @Test func htmlRenderer_enhancedCheckedTaskListStyling() async throws {
        let markdown = "- [x] Completed task with enhanced styling"
        let html = try await parser.parseToHTML(markdown)

        // Should contain enhanced CSS classes for checked items
        #expect(html.contains("task-list-item-checked"), "Should contain checked task list item class")
        #expect(html.contains("task-list-checkbox-checked"), "Should contain checked checkbox class")
        #expect(html.contains("task-list-content-checked"), "Should contain checked content class")

        // Should contain enhanced inline styling for checked items
        #expect(html.contains("background-color: rgba(33, 136, 33, 0.08)"), "Should have background color for checked items")
        #expect(html.contains("border-radius: 6px"), "Should have border radius for checked items")
        #expect(html.contains("text-decoration: line-through"), "Should have strikethrough for completed tasks")
        #expect(html.contains("text-decoration-color: #218838"), "Should have green strikethrough color")

        // Should contain enhanced checkbox styling
        #expect(html.contains("transform: scale(1.2)"), "Should have scaled checkbox")
        #expect(html.contains("accent-color: #218838"), "Should have green accent color for checked")
        #expect(html.contains("filter: brightness(1.1)"), "Should have brightness filter for checked")

        // Should have enhanced accessibility
        #expect(html.contains("aria-label=\"Completed task\""), "Should have enhanced accessibility label")
    }

    @Test func htmlRenderer_enhancedUncheckedTaskListStyling() async throws {
        let markdown = "- [ ] Incomplete task with enhanced styling"
        let html = try await parser.parseToHTML(markdown)

        // Should contain enhanced CSS classes for unchecked items
        #expect(html.contains("task-list-item-unchecked"), "Should contain unchecked task list item class")
        #expect(html.contains("task-list-checkbox-unchecked"), "Should contain unchecked checkbox class")
        #expect(html.contains("task-list-content-unchecked"), "Should contain unchecked content class")

        // Should NOT contain styling specific to checked items
        #expect(!html.contains("background-color: rgba(33, 136, 33, 0.08)"), "Should not have background color for unchecked")
        #expect(!html.contains("text-decoration: line-through"), "Should not have strikethrough for incomplete tasks")

        // Should contain basic checkbox styling
        #expect(html.contains("transform: scale(1.2)"), "Should have scaled checkbox")
        #expect(html.contains("accent-color: #6c757d"), "Should have gray accent color for unchecked")
        #expect(!html.contains("filter: brightness(1.1)"), "Should not have brightness filter for unchecked")

        // Should have enhanced accessibility
        #expect(html.contains("aria-label=\"Incomplete task\""), "Should have enhanced accessibility label")
    }

    @Test func htmlRenderer_enhancedTaskListContainerStyling() async throws {
        let markdown = """
        - [x] First task
        - [ ] Second task
        - [x] Third task
        """

        let html = try await parser.parseToHTML(markdown)

        // Should contain task list container class
        #expect(html.contains("class=\"task-list\""), "Should contain task-list class")

        // Should contain enhanced container styling
        #expect(html.contains("list-style: none"), "Should remove default list styling")
        #expect(html.contains("padding-left: 0"), "Should remove default padding")
        #expect(html.contains("margin: 16px 0"), "Should have proper margins")

        // Should have mixed item types with correct classes
        let checkedCount = html.components(separatedBy: "task-list-item-checked").count - 1
        let uncheckedCount = html.components(separatedBy: "task-list-item-unchecked").count - 1
        #expect(checkedCount == 2, "Should have 2 checked items")
        #expect(uncheckedCount == 1, "Should have 1 unchecked item")
    }

    @Test func htmlRenderer_enhancedTaskListWithComplexContent() async throws {
        let markdown = "- [x] Completed task with **bold** and *italic* text"
        let html = try await parser.parseToHTML(markdown)

        // Should contain enhanced styling for checked items
        #expect(html.contains("task-list-item-checked"), "Should contain checked item class")
        #expect(html.contains("task-list-content-checked"), "Should contain checked content class")

        // Should contain inline formatting within the strikethrough styling
        #expect(html.contains("<strong>") || html.contains("<b>"), "Should contain bold formatting")
        #expect(html.contains("<em>") || html.contains("<i>"), "Should contain italic formatting")

        // The content should be wrapped in the styled span
        #expect(html.contains("task-list-content-checked"), "Should wrap content in styled span")
        #expect(html.contains("text-decoration: line-through"), "Should have strikethrough even with complex content")
    }

    @Test func htmlRenderer_enhancedTaskListCustomCSSClass() async throws {
        let context = RenderContext(
            styleConfiguration: StyleConfiguration(
                cssClasses: [
                    .taskListItem: "custom-task-item"
                ]
            )
        )
        let customRenderer = HTMLRenderer(context: context)

        let markdown = "- [x] Custom styled task"
        let ast = try await parser.parseToAST(markdown)
        let html = try await customRenderer.render(document: ast)

        // Should preserve custom CSS class while adding state-specific classes
        #expect(html.contains("custom-task-item"), "Should contain custom CSS class")
        #expect(html.contains("task-list-item-checked"), "Should also contain state-specific class")

        // Should still contain enhanced styling
        #expect(html.contains("background-color: rgba(33, 136, 33, 0.08)"), "Should have enhanced background styling")
        #expect(html.contains("text-decoration: line-through"), "Should have strikethrough styling")
    }

    @Test func htmlRenderer_enhancedTaskListMixedWithRegularList() async throws {
        let markdown = """
        - Regular item
        - [x] Task item
        - Another regular item
        """

        let html = try await parser.parseToHTML(markdown)

        // Should contain task list container styling
        #expect(html.contains("class=\"task-list\""), "Should have task-list class on container")
        #expect(html.contains("list-style: none"), "Should have container styling")

        // Should have one enhanced task item
        #expect(html.contains("task-list-item-checked"), "Should have one checked task item")
        #expect(html.contains("task-list-checkbox-checked"), "Should have enhanced checkbox")

        // Should contain mix of regular and enhanced items
        let listItemCount = html.components(separatedBy: "<li").count - 1
        #expect(listItemCount == 3, "Should have 3 list items total")

        let enhancedItemCount = html.components(separatedBy: "task-list-content-checked").count - 1
        #expect(enhancedItemCount == 1, "Should have 1 enhanced task item")
    }
}
