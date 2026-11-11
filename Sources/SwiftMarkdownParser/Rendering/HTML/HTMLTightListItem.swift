extension HTMLRenderer {
    /// An item of a tight list shows its paragraphs' inline content without
    /// `<p>` wrappers; a line ending separates it from a following block.
    func renderTightListItem(
        _ item: AST.ListItemNode,
        requirements: inout BrowserRequirements
    ) async throws -> String {
        var html = "<li>"
        for (index, child) in item.children.enumerated() {
            guard let paragraph = child as? AST.ParagraphNode else {
                html += try await render(node: child, requirements: &requirements)
                continue
            }
            for inline in paragraph.children {
                html += try await render(node: inline, requirements: &requirements)
            }
            if index < item.children.count - 1 {
                html += "\n"
            }
        }
        return html + "</li>\n"
    }
}
