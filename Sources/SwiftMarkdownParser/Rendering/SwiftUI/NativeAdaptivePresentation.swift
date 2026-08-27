import SwiftUI

/// Owns container-aware presentation decisions for native SwiftUI output.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
struct NativeAdaptivePresentation {
    private let style: SwiftUIStyleConfiguration
    private let semantics: NativePresentationSemantics
    private let materializer: NativeViewMaterializer

    init(
        options: SwiftUIRenderOptions,
        semantics: NativePresentationSemantics,
        materializer: NativeViewMaterializer
    ) {
        self.style = options.styleConfiguration
        self.semantics = semantics
        self.materializer = materializer
    }

    /// Presents one semantic block while hiding width and Dynamic Type adaptation from callers.
    func present(_ block: Block) -> NativeMaterializedView {
        switch block {
        case let .document(children):
            materializer.materialize(NativeAdaptiveDocument(children: children, style: style))
        case let .content(children):
            materializer.materialize(NativeAdaptiveContentGroup(
                children: children,
                spacing: style.listItemContentSpacing
            ))
        case let .blockQuote(children):
            materializer.materialize(NativeAdaptiveBlockQuote(children: children, style: style))
        case let .list(items):
            materializer.materialize(NativeAdaptiveList(items: items, style: style))
        case let .footnote(identifier, children):
            materializer.materialize(NativeAdaptiveFootnote(
                identifier: identifier,
                children: children,
                style: style,
                semantics: semantics
            ))
        case let .task(isChecked, content):
            materializer.materialize(NativeAdaptiveTask(
                isChecked: isChecked,
                content: content,
                style: style,
                semantics: semantics
            ))
        case let .table(table):
            materializer.materialize(NativeAdaptiveTable(
                table: table,
                style: style,
                semantics: semantics
            ))
        case let .mermaidFallback(diagramType, source):
            materializer.materialize(NativeAdaptiveMermaidFallback(
                diagramType: diagramType,
                source: source,
                style: style,
                semantics: semantics
            ))
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
extension NativeAdaptivePresentation {
    enum Block {
        case document([NativeMaterializedView])
        case content([NativeMaterializedView])
        case blockQuote([NativeMaterializedView])
        case list([ListItem])
        case footnote(identifier: String, children: [NativeMaterializedView])
        case task(isChecked: Bool, content: NativeInlineContent)
        case table(Table)
        case mermaidFallback(diagramType: String?, source: String)
    }

    struct ListItem: Identifiable {
        enum Marker {
            case bullet
            case ordered(String)
        }

        let marker: Marker?
        let content: NativeMaterializedView

        var id: NativeViewIdentity { content.id }
    }

    struct Table {
        let columns: [Column]
        let rows: [Row]

        struct Column: Identifiable {
            let id: NativeViewIdentity
            let alignment: GFMTableAlignment
            let header: NativeInlineContent?
        }

        struct Row: Identifiable {
            let id: NativeViewIdentity
            let cells: [Cell]
        }

        struct Cell: Identifiable {
            let content: NativeInlineContent
            let columnIndex: Int

            var id: NativeViewIdentity { content.id }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveDocument: View {
    let children: [NativeMaterializedView]
    let style: SwiftUIStyleConfiguration

    var body: some View {
        LazyVStack(alignment: .leading, spacing: style.documentSpacing) {
            ForEach(children) { child in
                child
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveContentGroup: View {
    let children: [NativeMaterializedView]
    let spacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(children) { child in
                child
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveBlockQuote: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let children: [NativeMaterializedView]
    let style: SwiftUIStyleConfiguration

    var body: some View {
        HStack(alignment: .top, spacing: horizontalSpacing) {
            Rectangle()
                .fill(style.blockQuoteBorderColor)
                .frame(width: style.blockQuoteBorderWidth)

            VStack(alignment: .leading, spacing: style.blockQuoteContentSpacing) {
                ForEach(children) { child in
                    child
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, horizontalPadding)
        .padding(.vertical, style.blockQuoteVerticalPadding)
        .background(style.blockQuoteBackgroundColor)
        .compositingGroup()
        .clipShape(.rect(cornerRadius: style.blockQuoteCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    private var horizontalSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? style.blockQuoteSpacing * 0.5 : style.blockQuoteSpacing
    }

    private var horizontalPadding: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? style.blockQuotePadding * 0.5 : style.blockQuotePadding
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveList: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let items: [NativeAdaptivePresentation.ListItem]
    let style: SwiftUIStyleConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: style.listItemSpacing) {
            ForEach(items) { item in
                if let marker = item.marker {
                    NativeAdaptiveLabelContent(role: .listMarker, style: style) {
                        markerView(marker)
                    } content: {
                        item.content.frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    item.content.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, listIndentation)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func markerView(_ marker: NativeAdaptivePresentation.ListItem.Marker) -> some View {
        Group {
            switch marker {
            case .bullet:
                Text(verbatim: "•")
                    .frame(width: style.listMarkerWidth, alignment: .center)
            case let .ordered(value):
                Text(value)
                    .frame(minWidth: style.listMarkerWidth, alignment: .trailing)
            }
        }
        .font(style.bodyFont)
        .foregroundStyle(style.listMarkerColor)
    }

    private var listIndentation: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? style.listIndentation * 0.5 : style.listIndentation
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveFootnote: View {
    let identifier: String
    let children: [NativeMaterializedView]
    let style: SwiftUIStyleConfiguration
    let semantics: NativePresentationSemantics

    init(
        identifier: String,
        children: [NativeMaterializedView],
        style: SwiftUIStyleConfiguration,
        semantics: NativePresentationSemantics
    ) {
        self.identifier = identifier
        self.children = children
        self.style = style
        self.semantics = semantics
    }

    var body: some View {
        NativeAdaptiveLabelContent(role: .footnoteIdentifier, style: style) {
            Text(verbatim: "[\(identifier)]")
                .font(style.bodyFont)
                .foregroundStyle(style.textColor.opacity(0.65))
                .accessibilityHidden(true)
        } content: {
            VStack(alignment: .leading, spacing: style.listItemContentSpacing) {
                ForEach(children) { child in
                    child
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(semantics.localized(.footnote(identifier: identifier))))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveTask: View {
    let isChecked: Bool
    let content: NativeInlineContent
    let style: SwiftUIStyleConfiguration
    let semantics: NativePresentationSemantics

    var body: some View {
        NativeAdaptiveLabelContent(role: .taskStatus, style: style) {
            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isChecked ? style.taskListCheckedColor : style.taskListUncheckedColor)
                .font(style.taskListCheckboxFont.weight(isChecked ? .bold : .regular))
                .accessibilityHidden(true)
        } content: {
            content
                .font(style.bodyFont)
                .foregroundStyle(style.textColor)
                .opacity(isChecked ? 0.7 : 1.0)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, style.taskListContentSpacing * 0.5)
        .background(
            isChecked
                ? RoundedRectangle(cornerRadius: style.codeCornerRadius)
                    .fill(style.taskListCheckedColor.opacity(0.08))
                : nil
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(semantics.localized(.task(
            isCompleted: isChecked,
            content: content.accessibilityText
        ))))
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveTable: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let table: NativeAdaptivePresentation.Table
    let style: SwiftUIStyleConfiguration
    let semantics: NativePresentationSemantics

    var body: some View {
        Group {
            if table.rows.isEmpty {
                grid
            } else if dynamicTypeSize.isAccessibilitySize {
                stackedRows
            } else {
                ViewThatFits(in: .horizontal) {
                    grid.fixedSize(horizontal: true, vertical: false)
                    stackedRows
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(semantics.localized(.table)))
    }

    private var grid: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            if hasHeader {
                GridRow(alignment: .top) {
                    ForEach(table.columns) { column in
                        NativeAdaptiveTableHeaderCell(
                            column: column,
                            style: style,
                            semantics: semantics
                        )
                    }
                }
            }

            ForEach(table.rows) { row in
                GridRow(alignment: .top) {
                    ForEach(row.cells) { cell in
                        NativeAdaptiveTableValueCell(
                            cell: cell,
                            column: column(for: cell),
                            style: style
                        )
                    }
                }
            }
        }
        .background(style.tableBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: style.tableCornerRadius)
                .stroke(style.tableBorderColor, lineWidth: style.tableBorderWidth)
        )
        .compositingGroup()
        .clipShape(.rect(cornerRadius: style.tableCornerRadius))
    }

    private var stackedRows: some View {
        VStack(alignment: .leading, spacing: style.listItemSpacing) {
            ForEach(table.rows) { row in
                VStack(alignment: .leading, spacing: style.tableCellPadding) {
                    ForEach(row.cells) { cell in
                        NativeAdaptiveTableField(
                            cell: cell,
                            column: column(for: cell),
                            style: style,
                            semantics: semantics
                        )
                    }
                }
                .padding(style.tableCellPadding)
                .background(style.tableCellBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: style.tableCornerRadius)
                        .stroke(style.tableBorderColor, lineWidth: style.tableBorderWidth)
                )
            }
        }
    }

    private var hasHeader: Bool {
        table.columns.contains { $0.header != nil }
    }

    private func column(
        for cell: NativeAdaptivePresentation.Table.Cell
    ) -> NativeAdaptivePresentation.Table.Column {
        precondition(cell.columnIndex < table.columns.count, "Projected table cell has no column")
        return table.columns[cell.columnIndex]
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveTableHeaderCell: View {
    let column: NativeAdaptivePresentation.Table.Column
    let style: SwiftUIStyleConfiguration
    let semantics: NativePresentationSemantics

    var body: some View {
        Group {
            if let header = column.header {
                header
                    .accessibilityLabel(Text(semantics.localized(.tableHeader(
                        content: header.accessibilityText
                    ))))
                    .accessibilityAddTraits(.isHeader)
            } else {
                Color.clear.accessibilityHidden(true)
            }
        }
        .font(style.tableHeaderFont)
        .foregroundStyle(style.tableHeaderTextColor)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity, alignment: nativeTableAlignment(column.alignment))
        .padding(style.tableCellPadding)
        .background(style.tableHeaderBackgroundColor)
        .overlay(
            Rectangle()
                .stroke(style.tableBorderColor, lineWidth: style.tableBorderWidth)
        )
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveTableValueCell: View {
    let cell: NativeAdaptivePresentation.Table.Cell
    let column: NativeAdaptivePresentation.Table.Column
    let style: SwiftUIStyleConfiguration

    var body: some View {
        cell.content
            .font(style.tableBodyFont)
            .foregroundStyle(style.tableBodyTextColor)
            .frame(maxWidth: .infinity, alignment: nativeTableAlignment(column.alignment))
            .padding(style.tableCellPadding)
            .background(style.tableCellBackgroundColor)
            .overlay(
                Rectangle()
                    .stroke(style.tableBorderColor, lineWidth: style.tableBorderWidth)
            )
            .accessibilityLabel(cell.content.accessibilityText)
            .accessibilityAddTraits(.isStaticText)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveTableField: View {
    let cell: NativeAdaptivePresentation.Table.Cell
    let column: NativeAdaptivePresentation.Table.Column
    let style: SwiftUIStyleConfiguration
    let semantics: NativePresentationSemantics

    var body: some View {
        Group {
            if let header = column.header {
                NativeAdaptiveLabelContent(role: .tableField, style: style) {
                    header
                        .font(style.tableHeaderFont)
                        .foregroundStyle(style.tableHeaderTextColor)
                        .fontWeight(.semibold)
                        .accessibilityLabel(Text(semantics.localized(.tableHeader(
                            content: header.accessibilityText
                        ))))
                        .accessibilityAddTraits(.isHeader)
                } content: {
                    value
                }
            } else {
                value
            }
        }
    }

    private var value: some View {
        cell.content
            .font(style.tableBodyFont)
            .foregroundStyle(style.tableBodyTextColor)
            .frame(maxWidth: .infinity, alignment: nativeTableAlignment(column.alignment))
            .accessibilityLabel(cell.content.accessibilityText)
    }
}

private func nativeTableAlignment(_ alignment: GFMTableAlignment) -> Alignment {
    switch alignment {
    case .left, .none:
        .leading
    case .center:
        .center
    case .right:
        .trailing
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveMermaidFallback: View {
    let diagramType: String?
    let source: String
    let style: SwiftUIStyleConfiguration
    let semantics: NativePresentationSemantics

    var body: some View {
        VStack(alignment: .leading, spacing: style.listItemSpacing) {
            NativeAdaptiveLabelContent(role: .mermaidTitle, style: style) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
            } content: {
                VStack(alignment: .leading, spacing: style.listItemContentSpacing) {
                    Text(semantics.localized(.mermaidTitle))
                        .font(style.codeFont.bold())
                        .foregroundStyle(style.textColor)

                    if let diagramType {
                        Text(verbatim: "(\(diagramType))")
                            .font(style.codeFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, style.codeBlockPadding)
            .padding(.top, style.codeBlockPadding)

            Text(source)
                .font(style.codeFont)
                .foregroundStyle(style.codeTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, style.codeBlockPadding)
                .padding(.bottom, style.codeBlockPadding)
        }
        .background(style.codeBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: style.codeCornerRadius)
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
        )
        .compositingGroup()
        .clipShape(.rect(cornerRadius: style.codeCornerRadius))
        .accessibilityLabel(Text(semantics.localized(.mermaidDiagram(type: diagramType))))
        .accessibilityValue(source)
        .accessibilityAddTraits(.isStaticText)
    }
}
