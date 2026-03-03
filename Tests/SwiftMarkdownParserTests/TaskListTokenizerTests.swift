import Testing
@testable import SwiftMarkdownParser

/// Test-driven development tests for task list tokenization
///
/// These tests define the expected behavior for task list marker detection
/// at the tokenizer level, ensuring proper lexical analysis of task list syntax.
@Suite struct TaskListTokenizerTests {

    // MARK: - Basic Task List Marker Tests

    @Test func tokenizer_detectsCheckedTaskListMarker() async throws {
        let input = "- [x] Completed task"
        let tokenizer = MarkdownTokenizer(input)
        let tokens = tokenizer.tokenize()

        // Expected tokens: listMarker, whitespace, taskListMarker, whitespace, text, whitespace, text, eof
        #expect(tokens.count == 8)
        #expect(tokens[0].type == .listMarker)
        #expect(tokens[0].content == "-")
        #expect(tokens[1].type == .whitespace)
        #expect(tokens[2].type == .taskListMarker)
        #expect(tokens[2].content == "[x]")
        #expect(tokens[3].type == .whitespace)
        #expect(tokens[4].type == .text)
        #expect(tokens[4].content == "Completed")
        #expect(tokens[5].type == .whitespace)
        #expect(tokens[6].type == .text)
        #expect(tokens[6].content == "task")
        #expect(tokens[7].type == .eof)
    }

    @Test func tokenizer_detectsUncheckedTaskListMarker() async throws {
        let input = "- [ ] Incomplete task"
        let tokenizer = MarkdownTokenizer(input)
        let tokens = tokenizer.tokenize()

        // Expected tokens: listMarker, whitespace, taskListMarker, whitespace, text, whitespace, text, eof
        #expect(tokens.count == 8)
        #expect(tokens[0].type == .listMarker)
        #expect(tokens[0].content == "-")
        #expect(tokens[1].type == .whitespace)
        #expect(tokens[2].type == .taskListMarker)
        #expect(tokens[2].content == "[ ]")
        #expect(tokens[3].type == .whitespace)
        #expect(tokens[4].type == .text)
        #expect(tokens[4].content == "Incomplete")
        #expect(tokens[5].type == .whitespace)
        #expect(tokens[6].type == .text)
        #expect(tokens[6].content == "task")
        #expect(tokens[7].type == .eof)
    }

    @Test func tokenizer_detectsTaskListMarkerWithDifferentListMarkers() async throws {
        let testCases = [
            ("- [x] With dash", "-"),
            ("+ [x] With plus", "+"),
            ("* [x] With asterisk", "*"),
            ("1. [x] With number", "1.")
        ]

        for (input, expectedListMarker) in testCases {
            let tokenizer = MarkdownTokenizer(input)
            let tokens = tokenizer.tokenize()

            #expect(tokens.count >= 4, "Should have at least 4 tokens for: \(input)")
            #expect(tokens[0].type == .listMarker, "First token should be list marker for: \(input)")
            #expect(tokens[0].content == expectedListMarker, "List marker content should match for: \(input)")

            // Find the task list marker token
            let taskListToken = tokens.first { $0.type == .taskListMarker }
            #expect(taskListToken != nil, "Should find task list marker for: \(input)")
            #expect(taskListToken?.content == "[x]", "Task list marker should be [x] for: \(input)")
        }
    }

    // MARK: - Task List Marker Variations

    @Test func tokenizer_detectsTaskListMarkerVariations() async throws {
        let testCases = [
            ("- [x] Checked with x", "[x]"),
            ("- [X] Checked with X", "[X]"),
            ("- [ ] Unchecked with space", "[ ]"),
            ("- [o] Checked with o", "[o]"),
            ("- [O] Checked with O", "[O]"),
            ("- [v] Checked with v", "[v]"),
            ("- [V] Checked with V", "[V]")
        ]

        for (input, expectedMarker) in testCases {
            let tokenizer = MarkdownTokenizer(input)
            let tokens = tokenizer.tokenize()

            let taskListToken = tokens.first { $0.type == .taskListMarker }
            #expect(taskListToken != nil, "Should detect task list marker for: \(input)")
            #expect(taskListToken?.content == expectedMarker, "Task list marker should match for: \(input)")
        }
    }

    // MARK: - Edge Cases

    @Test func tokenizer_ignoresInvalidTaskListMarkers() async throws {
        let testCases = [
            "- [xx] Not a task list",  // Too many characters
            "- [] Empty brackets",     // Empty brackets
            "- [  ] Multiple spaces",  // Multiple spaces
            "- [ab] Invalid chars",    // Invalid characters
            "-[x] No space before",    // No space before brackets
            "- [x]No space after",     // No space after brackets (should still tokenize but differently)
        ]

        for input in testCases {
            let tokenizer = MarkdownTokenizer(input)
            let tokens = tokenizer.tokenize()

            // These should NOT produce taskListMarker tokens
            let hasTaskListMarker = tokens.contains { $0.type == .taskListMarker }
            #expect(!hasTaskListMarker, "Should not detect task list marker for invalid input: \(input)")
        }
    }

    @Test func tokenizer_handlesTaskListMarkerInMiddleOfLine() async throws {
        let input = "Some text [x] in middle"
        let tokenizer = MarkdownTokenizer(input)
        let tokens = tokenizer.tokenize()

        // Should not detect task list marker in middle of line
        let hasTaskListMarker = tokens.contains { $0.type == .taskListMarker }
        #expect(!hasTaskListMarker, "Should not detect task list marker in middle of line")
    }

    @Test func tokenizer_handlesMultipleTaskListItems() async throws {
        let input = """
        - [x] First task
        - [ ] Second task
        - [X] Third task
        """
        let tokenizer = MarkdownTokenizer(input)
        let tokens = tokenizer.tokenize()

        let taskListTokens = tokens.filter { $0.type == .taskListMarker }
        #expect(taskListTokens.count == 3, "Should detect 3 task list markers")
        #expect(taskListTokens[0].content == "[x]")
        #expect(taskListTokens[1].content == "[ ]")
        #expect(taskListTokens[2].content == "[X]")
    }

    // MARK: - Indentation Tests

    @Test func tokenizer_handlesIndentedTaskLists() async throws {
        let testCases = [
            ("  - [x] Indented 2 spaces", true),
            ("    - [x] Indented 4 spaces", true),
            ("      - [x] Indented 6 spaces", true),
            ("\t- [x] Indented with tab", true)
        ]

        for (input, shouldDetect) in testCases {
            let tokenizer = MarkdownTokenizer(input)
            let tokens = tokenizer.tokenize()

            let hasTaskListMarker = tokens.contains { $0.type == .taskListMarker }
            if shouldDetect {
                #expect(hasTaskListMarker, "Should detect task list marker for indented input: \(input)")
            } else {
                #expect(!hasTaskListMarker, "Should not detect task list marker for: \(input)")
            }
        }
    }

    // MARK: - Source Location Tests

    @Test func tokenizer_providesCorrectSourceLocations() async throws {
        let input = "- [x] Task"
        let tokenizer = MarkdownTokenizer(input)
        let tokens = tokenizer.tokenize()

        let taskListToken = tokens.first { $0.type == .taskListMarker }
        #expect(taskListToken != nil)
        #expect(taskListToken?.location.line == 1)
        #expect(taskListToken?.location.column == 3) // After "- "
        #expect(taskListToken?.location.offset == 2) // After "- "
    }

    @Test func tokenizer_providesCorrectLengthForTaskListMarkers() async throws {
        let testCases = [
            ("[x]", 3),
            ("[ ]", 3),
            ("[X]", 3),
            ("[o]", 3)
        ]

        for (markerContent, expectedLength) in testCases {
            let input = "- \(markerContent) Task"
            let tokenizer = MarkdownTokenizer(input)
            let tokens = tokenizer.tokenize()

            let taskListToken = tokens.first { $0.type == .taskListMarker }
            #expect(taskListToken != nil)
            #expect(taskListToken?.length == expectedLength, "Length should match for marker: \(markerContent)")
            #expect(taskListToken?.content == markerContent, "Content should match for marker: \(markerContent)")
        }
    }
}
