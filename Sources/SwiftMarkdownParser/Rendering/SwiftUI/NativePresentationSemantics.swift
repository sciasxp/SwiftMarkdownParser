import Foundation

/// Owns localized native-output meaning and pure output-specific semantic decisions.
struct NativePresentationSemantics: Sendable {
    enum Message: Sendable {
        case sectionDivider
        case codeBlock(language: String?)
        case footnote(identifier: String)
        case task(isCompleted: Bool, content: String)
        case table
        case tableHeader(content: String)
        case mermaidTitle
        case mermaidDiagram(type: String?)
        case inlineMath(content: String)
        case htmlBlock
        case htmlInline(content: String)
        case loadingImage(alternativeText: String)
        case mathExpression
        case unsupportedNodeType(String)
    }

    struct CodeRun: Equatable, Sendable {
        let text: String
        let tokenType: SyntaxTokenType?
    }

    /// Returns deferred, package-owned localization for one native semantic role.
    func localized(_ message: Message) -> LocalizedStringResource {
        switch message {
        case .sectionDivider:
            LocalizedStringResource(
                "native.accessibility.section_divider",
                defaultValue: "Section divider",
                bundle: #bundle,
                comment: "VoiceOver label for the divider between Markdown sections."
            )
        case let .codeBlock(language):
            if let language {
                LocalizedStringResource(
                    "native.accessibility.code_block.language",
                    defaultValue: "Code block in \(language)",
                    bundle: #bundle,
                    comment: "VoiceOver label for a code block. The value is its programming language."
                )
            } else {
                LocalizedStringResource(
                    "native.accessibility.code_block",
                    defaultValue: "Code block",
                    bundle: #bundle,
                    comment: "VoiceOver label for a code block without a language."
                )
            }
        case let .footnote(identifier):
            LocalizedStringResource(
                "native.accessibility.footnote",
                defaultValue: "Footnote \(identifier)",
                bundle: #bundle,
                comment: "VoiceOver label for a footnote. The value is its Markdown identifier."
            )
        case let .task(isCompleted, content):
            if isCompleted {
                LocalizedStringResource(
                    "native.accessibility.task.completed",
                    defaultValue: "Completed task: \(content)",
                    bundle: #bundle,
                    comment: "VoiceOver label for a completed task. The value is the task text."
                )
            } else {
                LocalizedStringResource(
                    "native.accessibility.task.incomplete",
                    defaultValue: "Incomplete task: \(content)",
                    bundle: #bundle,
                    comment: "VoiceOver label for an incomplete task. The value is the task text."
                )
            }
        case .table:
            LocalizedStringResource(
                "native.accessibility.table",
                defaultValue: "Table",
                bundle: #bundle,
                comment: "VoiceOver label for a Markdown table."
            )
        case let .tableHeader(content):
            LocalizedStringResource(
                "native.accessibility.table_header",
                defaultValue: "Header: \(content)",
                bundle: #bundle,
                comment: "VoiceOver label for a table header. The value is the header text."
            )
        case .mermaidTitle:
            LocalizedStringResource(
                "native.title.mermaid_diagram",
                defaultValue: "Mermaid Diagram",
                bundle: #bundle,
                comment: "Visible title for a Mermaid source fallback."
            )
        case let .mermaidDiagram(type):
            if let type {
                LocalizedStringResource(
                    "native.accessibility.mermaid_diagram.type",
                    defaultValue: "Mermaid diagram: \(type)",
                    bundle: #bundle,
                    comment: "VoiceOver label for a Mermaid diagram. The value is its diagram type."
                )
            } else {
                LocalizedStringResource(
                    "native.accessibility.mermaid_diagram.unknown",
                    defaultValue: "Mermaid diagram: unknown type",
                    bundle: #bundle,
                    comment: "VoiceOver label for a Mermaid diagram whose type is unknown."
                )
            }
        case let .inlineMath(content):
            LocalizedStringResource(
                "native.accessibility.math.inline",
                defaultValue: "Math: \(content)",
                bundle: #bundle,
                comment: "VoiceOver label for inline math. The value is the source expression."
            )
        case .htmlBlock:
            LocalizedStringResource(
                "native.accessibility.html.block",
                defaultValue: "HTML content",
                bundle: #bundle,
                comment: "VoiceOver label for a block of raw HTML source."
            )
        case let .htmlInline(content):
            LocalizedStringResource(
                "native.accessibility.html.inline",
                defaultValue: "HTML: \(content)",
                bundle: #bundle,
                comment: "VoiceOver label for inline raw HTML. The value is the HTML source."
            )
        case let .loadingImage(alternativeText):
            LocalizedStringResource(
                "native.accessibility.image.loading",
                defaultValue: "Loading image: \(alternativeText)",
                bundle: #bundle,
                comment: "VoiceOver loading state for an image. The value is its alternative text."
            )
        case .mathExpression:
            LocalizedStringResource(
                "native.accessibility.math.expression",
                defaultValue: "Math expression",
                bundle: #bundle,
                comment: "VoiceOver label for a displayed math expression."
            )
        case let .unsupportedNodeType(type):
            LocalizedStringResource(
                "native.error.unsupported_node_type",
                defaultValue: "Unsupported AST node type: \(type)",
                bundle: #bundle,
                comment: "Renderer error. The value is the unsupported AST node type."
            )
        }
    }

    func orderedListMarker(startNumber: Int?, index: Int) -> String {
        let start = startNumber ?? 1
        return "\(start + index)."
    }

    /// Fills the gaps between semantic tokens so the rendered text exactly matches the source.
    func codeRuns(source: String, tokens: [SyntaxToken]) -> [CodeRun] {
        var result: [CodeRun] = []
        var cursor = source.startIndex

        for token in tokens {
            if cursor < token.range.lowerBound {
                result.append(CodeRun(text: String(source[cursor..<token.range.lowerBound]), tokenType: nil))
            }
            result.append(CodeRun(text: token.content, tokenType: token.tokenType))
            cursor = token.range.upperBound
        }

        if cursor < source.endIndex {
            result.append(CodeRun(text: String(source[cursor...]), tokenType: nil))
        }

        return result
    }
}
