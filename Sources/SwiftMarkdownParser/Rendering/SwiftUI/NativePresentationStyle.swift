import SwiftUI

/// Immutable, role-oriented presentation meaning materialized once for native output.
@available(iOS 17.0, macOS 14.0, *)
struct NativePresentationStyle {
    struct Document {
        let font: Font
        let textColor: Color
        let spacing: CGFloat
    }

    struct Inline {
        let codeFont: Font
        let codeTextColor: Color
        let strikethroughColor: Color
        let linkColor: Color
        let lineSpacing: CGFloat
    }

    struct Paragraph {
        let font: Font
        let textColor: Color
        let bottomSpacing: CGFloat
    }

    struct Heading {
        let font: Font
        let textColor: Color
        let bottomSpacing: CGFloat
    }

    struct CodeBlock {
        let font: Font
        let textColor: Color
        let titleTextColor: Color
        let backgroundColor: Color
        let blockPadding: CGFloat
        let spanPadding: CGFloat
        let cornerRadius: CGFloat
        let verticalSpacing: CGFloat
        let contentSpacing: CGFloat
        let titleMetrics: NativeAdaptiveLabelContentMetrics
    }

    struct Quote {
        let borderColor: Color
        let backgroundColor: Color
        let spacing: CGFloat
        let contentSpacing: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let borderWidth: CGFloat
        let cornerRadius: CGFloat

        func horizontalSpacing(accessibilitySize: Bool) -> CGFloat {
            accessibilitySize ? spacing * 0.5 : spacing
        }

        func padding(accessibilitySize: Bool) -> CGFloat {
            accessibilitySize ? horizontalPadding * 0.5 : horizontalPadding
        }
    }

    struct List {
        let font: Font
        let textColor: Color
        let markerColor: Color
        let itemSpacing: CGFloat
        let contentSpacing: CGFloat
        let indentation: CGFloat
        let markerWidth: CGFloat
        let markerMetrics: NativeAdaptiveLabelContentMetrics
        let footnoteMetrics: NativeAdaptiveLabelContentMetrics

        func indentation(accessibilitySize: Bool) -> CGFloat {
            accessibilitySize ? indentation * 0.5 : indentation
        }
    }

    struct Task {
        let font: Font
        let textColor: Color
        let checkboxFont: Font
        let checkedColor: Color
        let uncheckedColor: Color
        let contentSpacing: CGFloat
        let backgroundCornerRadius: CGFloat
        let statusMetrics: NativeAdaptiveLabelContentMetrics
    }

    struct Table {
        let headerFont: Font
        let bodyFont: Font
        let borderColor: Color
        let backgroundColor: Color
        let headerBackgroundColor: Color
        let cellBackgroundColor: Color
        let headerTextColor: Color
        let bodyTextColor: Color
        let rowSpacing: CGFloat
        let cellPadding: CGFloat
        let borderWidth: CGFloat
        let cornerRadius: CGFloat
        let fieldMetrics: NativeAdaptiveLabelContentMetrics
    }

    struct Image {
        let maximumWidth: CGFloat
        let cornerRadius: CGFloat
        let placeholderHeight: CGFloat
    }

    struct ThematicBreak {
        let color: Color
        let verticalSpacing: CGFloat
    }

    let document: Document
    let inline: Inline
    let paragraph: Paragraph
    let codeBlock: CodeBlock
    let quote: Quote
    let list: List
    let task: Task
    let table: Table
    let image: Image
    let thematicBreak: ThematicBreak

    private let headings: [Int: Heading]
    private let fallbackHeading: Heading

    init(_ configuration: SwiftUIStyleConfiguration) {
        let documentSpacing = Self.metric(configuration.documentSpacing)
        let paragraphSpacing = Self.metric(configuration.paragraphSpacing)
        let lineSpacing = Self.metric(configuration.lineBreakSpacing)
        let quoteSpacing = Self.metric(configuration.blockQuoteSpacing)
        let quoteContentSpacing = Self.metric(configuration.blockQuoteContentSpacing)
        let quotePadding = Self.metric(configuration.blockQuotePadding)
        let quoteVerticalPadding = Self.metric(configuration.blockQuoteVerticalPadding)
        let thematicBreakSpacing = Self.metric(configuration.thematicBreakSpacing)
        let listItemSpacing = Self.metric(configuration.listItemSpacing)
        let listContentSpacing = Self.metric(configuration.listItemContentSpacing)
        let listMarkerSpacing = Self.metric(configuration.listMarkerSpacing)
        let listIndentation = Self.metric(configuration.listIndentation)
        let listMarkerWidth = Self.metric(configuration.listMarkerWidth)
        let codeSpanPadding = Self.metric(configuration.codeSpanPadding)
        let codeBlockPadding = Self.metric(configuration.codeBlockPadding)
        let taskSpacing = Self.metric(configuration.taskListSpacing)
        let taskContentSpacing = Self.metric(configuration.taskListContentSpacing)
        let tableCellPadding = Self.metric(configuration.tableCellPadding)

        document = Document(
            font: configuration.bodyFont,
            textColor: configuration.textColor,
            spacing: documentSpacing
        )
        inline = Inline(
            codeFont: configuration.codeFont,
            codeTextColor: configuration.codeTextColor,
            strikethroughColor: configuration.strikethroughColor,
            linkColor: configuration.linkColor,
            lineSpacing: lineSpacing
        )
        paragraph = Paragraph(
            font: configuration.bodyFont,
            textColor: configuration.textColor,
            bottomSpacing: paragraphSpacing
        )

        let fallback = Heading(
            font: configuration.bodyFont,
            textColor: configuration.headingColor,
            bottomSpacing: Self.metric(configuration.headingSpacing(for: 0))
        )
        fallbackHeading = fallback
        headings = Dictionary(uniqueKeysWithValues: (1...6).map { level in
            (
                level,
                Heading(
                    font: configuration.headingFonts[level] ?? configuration.bodyFont,
                    textColor: configuration.headingColor,
                    bottomSpacing: Self.metric(configuration.headingSpacing(for: level))
                )
            )
        })

        let markerMinimumWidth = max(listMarkerWidth * 4, listMarkerSpacing * 8)
        let taskMinimumWidth = max(listMarkerWidth * 4, taskSpacing * 8)
        let markerMetrics = NativeAdaptiveLabelContentMetrics(
            horizontalSpacing: listMarkerSpacing,
            verticalSpacing: listContentSpacing,
            minimumContentWidth: markerMinimumWidth,
            standardPrefersVertical: false,
            accessibilityPrefersVertical: false,
            alignment: .firstBaseline
        )

        codeBlock = CodeBlock(
            font: configuration.codeFont,
            textColor: configuration.codeTextColor,
            titleTextColor: configuration.textColor,
            backgroundColor: configuration.codeBackgroundColor,
            blockPadding: codeBlockPadding,
            spanPadding: codeSpanPadding,
            cornerRadius: Self.metric(configuration.codeCornerRadius),
            verticalSpacing: listItemSpacing,
            contentSpacing: listContentSpacing,
            titleMetrics: NativeAdaptiveLabelContentMetrics(
                horizontalSpacing: listMarkerSpacing,
                verticalSpacing: listContentSpacing,
                minimumContentWidth: markerMinimumWidth,
                standardPrefersVertical: false,
                accessibilityPrefersVertical: true,
                alignment: .top
            )
        )
        quote = Quote(
            borderColor: configuration.blockQuoteBorderColor,
            backgroundColor: configuration.blockQuoteBackgroundColor,
            spacing: quoteSpacing,
            contentSpacing: quoteContentSpacing,
            horizontalPadding: quotePadding,
            verticalPadding: quoteVerticalPadding,
            borderWidth: Self.metric(configuration.blockQuoteBorderWidth),
            cornerRadius: Self.metric(configuration.blockQuoteCornerRadius)
        )
        list = List(
            font: configuration.bodyFont,
            textColor: configuration.textColor,
            markerColor: configuration.listMarkerColor,
            itemSpacing: listItemSpacing,
            contentSpacing: listContentSpacing,
            indentation: listIndentation,
            markerWidth: listMarkerWidth,
            markerMetrics: markerMetrics,
            footnoteMetrics: NativeAdaptiveLabelContentMetrics(
                horizontalSpacing: listMarkerSpacing,
                verticalSpacing: listContentSpacing,
                minimumContentWidth: markerMinimumWidth,
                standardPrefersVertical: false,
                accessibilityPrefersVertical: true,
                alignment: .firstBaseline
            )
        )
        task = Task(
            font: configuration.bodyFont,
            textColor: configuration.textColor,
            checkboxFont: configuration.taskListCheckboxFont,
            checkedColor: configuration.taskListCheckedColor,
            uncheckedColor: configuration.taskListUncheckedColor,
            contentSpacing: taskContentSpacing,
            backgroundCornerRadius: Self.metric(configuration.codeCornerRadius),
            statusMetrics: NativeAdaptiveLabelContentMetrics(
                horizontalSpacing: taskSpacing,
                verticalSpacing: taskContentSpacing,
                minimumContentWidth: taskMinimumWidth,
                standardPrefersVertical: false,
                accessibilityPrefersVertical: false,
                alignment: .firstBaseline
            )
        )
        table = Table(
            headerFont: configuration.tableHeaderFont,
            bodyFont: configuration.tableBodyFont,
            borderColor: configuration.tableBorderColor,
            backgroundColor: configuration.tableBackgroundColor,
            headerBackgroundColor: configuration.tableHeaderBackgroundColor,
            cellBackgroundColor: configuration.tableCellBackgroundColor,
            headerTextColor: configuration.tableHeaderTextColor,
            bodyTextColor: configuration.tableBodyTextColor,
            rowSpacing: listItemSpacing,
            cellPadding: tableCellPadding,
            borderWidth: Self.metric(configuration.tableBorderWidth),
            cornerRadius: Self.metric(configuration.tableCornerRadius),
            fieldMetrics: NativeAdaptiveLabelContentMetrics(
                horizontalSpacing: tableCellPadding,
                verticalSpacing: tableCellPadding * 0.5,
                minimumContentWidth: 0,
                standardPrefersVertical: true,
                accessibilityPrefersVertical: true,
                alignment: .top
            )
        )
        image = Image(
            maximumWidth: Self.imageMaximumWidth(configuration.imageMaxWidth),
            cornerRadius: Self.metric(configuration.imageCornerRadius),
            placeholderHeight: Self.metric(configuration.imagePlaceholderHeight)
        )
        thematicBreak = ThematicBreak(
            color: configuration.thematicBreakColor,
            verticalSpacing: thematicBreakSpacing
        )
    }

    func heading(level: Int) -> Heading {
        headings[level] ?? fallbackHeading
    }

    private static func metric(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : 0
    }

    private static func imageMaximumWidth(_ value: CGFloat) -> CGFloat {
        if value.isNaN || value == .infinity {
            return .infinity
        }
        return value.isFinite ? max(0, value) : 0
    }
}
