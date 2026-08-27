import SwiftUI

/// Owns container-aware presentation decisions for native SwiftUI output.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
struct NativeAdaptivePresentation {
    private let style: SwiftUIStyleConfiguration

    init(options: SwiftUIRenderOptions) {
        self.style = options.styleConfiguration
    }

    /// Presents one semantic block while hiding width and Dynamic Type adaptation from callers.
    func present(_ block: Block) -> AnyView {
        switch block {
        case let .document(children):
            AnyView(NativeAdaptiveDocument(children: children, style: style))
        case let .content(children):
            AnyView(NativeAdaptiveContentGroup(children: children, spacing: style.listItemContentSpacing))
        case let .blockQuote(children):
            AnyView(NativeAdaptiveBlockQuote(children: children, style: style))
        case let .list(items):
            AnyView(NativeAdaptiveList(items: items, style: style))
        case let .footnote(identifier, children):
            AnyView(NativeAdaptiveFootnote(identifier: identifier, children: children, style: style))
        case let .task(isChecked, content):
            AnyView(NativeAdaptiveTask(isChecked: isChecked, content: content, style: style))
        case let .table(table):
            AnyView(NativeAdaptiveTable(table: table, style: style))
        case let .mermaidFallback(diagramType, source):
            AnyView(NativeAdaptiveMermaidFallback(
                diagramType: diagramType,
                source: source,
                style: style
            ))
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
extension NativeAdaptivePresentation {
    enum Block {
        case document([AnyView])
        case content([AnyView])
        case blockQuote([AnyView])
        case list([ListItem])
        case footnote(identifier: String, children: [AnyView])
        case task(isChecked: Bool, content: NativeInlineContent)
        case table(Table)
        case mermaidFallback(diagramType: String?, source: String)
    }

    struct ListItem: Identifiable {
        enum Marker {
            case bullet
            case ordered(String)
        }

        let id = UUID()
        let marker: Marker?
        let content: AnyView
    }

    struct Table {
        let rows: [Row]

        struct Row: Identifiable {
            let id = UUID()
            let isHeader: Bool
            let cells: [Cell]
        }

        struct Cell: Identifiable {
            let id = UUID()
            let content: NativeInlineContent
            let alignment: GFMTableAlignment
            let columnIndex: Int
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveDocument: View {
    private let children: [NativeAdaptiveViewItem]
    let style: SwiftUIStyleConfiguration

    init(children: [AnyView], style: SwiftUIStyleConfiguration) {
        self.children = children.map(NativeAdaptiveViewItem.init)
        self.style = style
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: style.documentSpacing) {
            ForEach(children) { child in
                child.content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveContentGroup: View {
    private let children: [NativeAdaptiveViewItem]
    let spacing: CGFloat

    init(children: [AnyView], spacing: CGFloat) {
        self.children = children.map(NativeAdaptiveViewItem.init)
        self.spacing = spacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(children) { child in
                child.content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveBlockQuote: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let children: [NativeAdaptiveViewItem]
    let style: SwiftUIStyleConfiguration

    init(children: [AnyView], style: SwiftUIStyleConfiguration) {
        self.children = children.map(NativeAdaptiveViewItem.init)
        self.style = style
    }

    var body: some View {
        HStack(alignment: .top, spacing: horizontalSpacing) {
            Rectangle()
                .fill(style.blockQuoteBorderColor)
                .frame(width: style.blockQuoteBorderWidth)

            VStack(alignment: .leading, spacing: style.blockQuoteContentSpacing) {
                ForEach(children) { child in
                    child.content
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
                    NativeAdaptiveLabelLayout(
                        horizontalSpacing: style.listMarkerSpacing,
                        verticalSpacing: style.listItemContentSpacing,
                        minimumContentWidth: minimumContentWidth
                    ) {
                        markerView(marker)
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
                Text("•")
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

    private var minimumContentWidth: CGFloat {
        max(style.listMarkerWidth * 4, style.listMarkerSpacing * 8)
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveFootnote: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let identifier: String
    private let children: [NativeAdaptiveViewItem]
    let style: SwiftUIStyleConfiguration

    init(identifier: String, children: [AnyView], style: SwiftUIStyleConfiguration) {
        self.identifier = identifier
        self.children = children.map(NativeAdaptiveViewItem.init)
        self.style = style
    }

    var body: some View {
        NativeAdaptiveLabelLayout(
            horizontalSpacing: style.listMarkerSpacing,
            verticalSpacing: style.listItemContentSpacing,
            minimumContentWidth: max(style.listMarkerWidth * 4, style.listMarkerSpacing * 8),
            prefersVertical: dynamicTypeSize.isAccessibilitySize
        ) {
            Text("[\(identifier)]")
                .font(style.bodyFont)
                .foregroundStyle(style.textColor.opacity(0.65))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: style.listItemContentSpacing) {
                ForEach(children) { child in
                    child.content
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Footnote \(identifier)")
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveTask: View {
    let isChecked: Bool
    let content: NativeInlineContent
    let style: SwiftUIStyleConfiguration

    var body: some View {
        NativeAdaptiveLabelLayout(
            horizontalSpacing: style.taskListSpacing,
            verticalSpacing: style.taskListContentSpacing,
            minimumContentWidth: max(style.listMarkerWidth * 4, style.taskListSpacing * 8)
        ) {
            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isChecked ? style.taskListCheckedColor : style.taskListUncheckedColor)
                .font(style.taskListCheckboxFont.weight(isChecked ? .bold : .regular))
                .accessibilityHidden(true)

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
        .accessibilityLabel(
            "\(isChecked ? "Completed task" : "Incomplete task"): \(content.accessibilityText)"
        )
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveTable: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let table: NativeAdaptivePresentation.Table
    let style: SwiftUIStyleConfiguration

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize, hasBodyRows {
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
        .accessibilityLabel("Table")
    }

    private var grid: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(table.rows) { row in
                GridRow(alignment: .top) {
                    ForEach(row.cells) { cell in
                        tableCell(cell, isHeader: row.isHeader)
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
            ForEach(rowsForStackedPresentation) { row in
                VStack(alignment: .leading, spacing: style.tableCellPadding) {
                    ForEach(row.cells) { cell in
                        VStack(alignment: .leading, spacing: style.tableCellPadding * 0.5) {
                            if let header = headerContent(at: cell.columnIndex) {
                                header
                                    .font(style.tableHeaderFont)
                                    .foregroundStyle(style.tableHeaderTextColor)
                                    .fontWeight(.semibold)
                                    .accessibilityAddTraits(.isHeader)
                            }

                            cell.content
                                .font(style.tableBodyFont)
                                .foregroundStyle(style.tableBodyTextColor)
                                .frame(maxWidth: .infinity, alignment: alignment(for: cell.alignment))
                                .accessibilityLabel(cell.content.accessibilityText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func tableCell(
        _ cell: NativeAdaptivePresentation.Table.Cell,
        isHeader: Bool
    ) -> some View {
        cell.content
            .font(isHeader ? style.tableHeaderFont : style.tableBodyFont)
            .foregroundStyle(isHeader ? style.tableHeaderTextColor : style.tableBodyTextColor)
            .fontWeight(isHeader ? .bold : .regular)
            .frame(maxWidth: .infinity, alignment: alignment(for: cell.alignment))
            .padding(style.tableCellPadding)
            .background(isHeader ? style.tableHeaderBackgroundColor : style.tableCellBackgroundColor)
            .overlay(
                Rectangle()
                    .stroke(style.tableBorderColor, lineWidth: style.tableBorderWidth)
            )
            .accessibilityLabel(
                isHeader ? "Header: \(cell.content.accessibilityText)" : cell.content.accessibilityText
            )
            .accessibilityAddTraits(isHeader ? .isHeader : .isStaticText)
    }

    private func headerContent(at index: Int) -> NativeInlineContent? {
        guard let headerRow, index < headerRow.cells.count else { return nil }
        return headerRow.cells[index].content
    }

    private func alignment(for alignment: GFMTableAlignment) -> Alignment {
        switch alignment {
        case .left, .none:
            .leading
        case .center:
            .center
        case .right:
            .trailing
        }
    }

    private var headerRow: NativeAdaptivePresentation.Table.Row? {
        table.rows.first(where: \.isHeader)
    }

    private var rowsForStackedPresentation: [NativeAdaptivePresentation.Table.Row] {
        let bodyRows = table.rows.filter { !$0.isHeader }
        return bodyRows.isEmpty ? table.rows : bodyRows
    }

    private var hasBodyRows: Bool {
        table.rows.contains { !$0.isHeader }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveMermaidFallback: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let diagramType: String?
    let source: String
    let style: SwiftUIStyleConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: style.listItemSpacing) {
            NativeAdaptiveLabelLayout(
                horizontalSpacing: style.listMarkerSpacing,
                verticalSpacing: style.listItemContentSpacing,
                minimumContentWidth: max(style.listMarkerWidth * 4, style.listMarkerSpacing * 8),
                prefersVertical: dynamicTypeSize.isAccessibilitySize
            ) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: style.listItemContentSpacing) {
                    Text("Mermaid Diagram")
                        .font(style.codeFont.bold())
                        .foregroundStyle(style.textColor)

                    if let diagramType {
                        Text("(\(diagramType))")
                            .font(style.codeFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, style.codeBlockPadding)
            .padding(.top, style.codeBlockPadding)

            ScrollView(.horizontal) {
                Text(source)
                    .font(style.codeFont)
                    .foregroundStyle(style.codeTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, style.codeBlockPadding)
                    .padding(.bottom, style.codeBlockPadding)
            }
        }
        .background(style.codeBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: style.codeCornerRadius)
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
        )
        .compositingGroup()
        .clipShape(.rect(cornerRadius: style.codeCornerRadius))
        .accessibilityLabel("Mermaid diagram: \(diagramType ?? "unknown type")")
        .accessibilityValue(source)
        .accessibilityAddTraits(.isStaticText)
    }
}

private struct NativeAdaptiveViewItem: Identifiable {
    let id = UUID()
    let content: AnyView

    init(_ content: AnyView) {
        self.content = content
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveLabelLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let minimumContentWidth: CGFloat
    var prefersVertical = false

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let labelSize = subviews[0].sizeThatFits(.unspecified)
        let axis = axis(for: proposal.width, labelWidth: labelSize.width)

        switch axis {
        case .horizontal:
            let contentWidth = proposal.width.map { max(0, $0 - labelSize.width - horizontalSpacing) }
            let contentSize = subviews[1].sizeThatFits(ProposedViewSize(width: contentWidth, height: proposal.height))
            return CGSize(
                width: proposal.width ?? labelSize.width + horizontalSpacing + contentSize.width,
                height: max(labelSize.height, contentSize.height)
            )
        case .vertical:
            let contentSize = subviews[1].sizeThatFits(ProposedViewSize(width: proposal.width, height: proposal.height))
            return CGSize(
                width: proposal.width ?? max(labelSize.width, contentSize.width),
                height: labelSize.height + verticalSpacing + contentSize.height
            )
        }
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }
        let labelSize = subviews[0].sizeThatFits(.unspecified)
        let axis = axis(for: bounds.width, labelWidth: labelSize.width)

        switch axis {
        case .horizontal:
            subviews[0].place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(labelSize)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX + labelSize.width + horizontalSpacing, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(
                    width: max(0, bounds.width - labelSize.width - horizontalSpacing),
                    height: nil
                )
            )
        case .vertical:
            subviews[0].place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(labelSize)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + labelSize.height + verticalSpacing),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: nil)
            )
        }
    }

    private func axis(for width: CGFloat?, labelWidth: CGFloat) -> Axis {
        guard !prefersVertical, let width, width.isFinite else { return prefersVertical ? .vertical : .horizontal }
        return width >= labelWidth + horizontalSpacing + minimumContentWidth ? .horizontal : .vertical
    }
}
