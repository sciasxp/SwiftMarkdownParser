import SwiftUI

struct NativeAdaptiveLabelContentMetrics {
    let standard: NativeAdaptiveLabelContentGeometry.Metrics
    let accessibility: NativeAdaptiveLabelContentGeometry.Metrics

    init(
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat,
        minimumContentWidth: CGFloat,
        standardPrefersVertical: Bool,
        accessibilityPrefersVertical: Bool,
        alignment: NativeAdaptiveLabelContentGeometry.Alignment
    ) {
        standard = .init(
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing,
            minimumContentWidth: minimumContentWidth,
            prefersVertical: standardPrefersVertical,
            alignment: alignment
        )
        accessibility = .init(
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing,
            minimumContentWidth: minimumContentWidth,
            prefersVertical: accessibilityPrefersVertical,
            alignment: alignment
        )
    }
}

/// Owns the adaptive geometry of one role-bearing native label/content pair.
@available(iOS 17.0, macOS 14.0, *)
struct NativeAdaptiveLabelContent<Label: View, Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    private let standardMetrics: NativeAdaptiveLabelContentGeometry.Metrics
    private let accessibilityMetrics: NativeAdaptiveLabelContentGeometry.Metrics
    private let label: Label
    private let content: Content

    init(
        metrics: NativeAdaptiveLabelContentMetrics,
        @ViewBuilder label: () -> Label,
        @ViewBuilder content: () -> Content
    ) {
        self.standardMetrics = metrics.standard
        self.accessibilityMetrics = metrics.accessibility
        self.label = label()
        self.content = content()
    }

    var body: some View {
        NativeAdaptiveLabelContentLayout(
            metrics: dynamicTypeSize.isAccessibilitySize
                ? accessibilityMetrics
                : standardMetrics,
            layoutDirection: layoutDirection
        ) {
            label
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Pure geometry used by the label/content layout and its focused tests.
struct NativeAdaptiveLabelContentGeometry {
    enum Axis: Equatable {
        case horizontal
        case vertical
    }

    enum Alignment: Equatable {
        case top
        case firstBaseline
    }

    struct Metrics: Equatable {
        let horizontalSpacing: CGFloat
        let verticalSpacing: CGFloat
        let minimumContentWidth: CGFloat
        let prefersVertical: Bool
        let alignment: Alignment

        var normalized: Self {
            Self(
                horizontalSpacing: Self.finiteNonnegative(horizontalSpacing),
                verticalSpacing: Self.finiteNonnegative(verticalSpacing),
                minimumContentWidth: Self.finiteNonnegative(minimumContentWidth),
                prefersVertical: prefersVertical,
                alignment: alignment
            )
        }

        private static func finiteNonnegative(_ value: CGFloat) -> CGFloat {
            value.isFinite ? max(0, value) : 0
        }
    }

    struct Measurement: Equatable {
        let size: CGSize
        let firstBaseline: CGFloat?
    }

    struct Plan: Equatable {
        let axis: Axis
        let size: CGSize
        let labelFrame: CGRect
        let contentFrame: CGRect
    }

    static func normalizedWidth(_ width: CGFloat?) -> CGFloat? {
        guard let width, width.isFinite else { return nil }
        return max(0, width)
    }

    static func axis(
        availableWidth: CGFloat?,
        intrinsicLabelWidth: CGFloat,
        metrics: Metrics
    ) -> Axis {
        let metrics = metrics.normalized
        guard !metrics.prefersVertical else { return .vertical }
        guard let width = normalizedWidth(availableWidth) else { return .horizontal }
        let labelWidth = intrinsicLabelWidth.isFinite ? max(0, intrinsicLabelWidth) : 0
        return width >= labelWidth + metrics.horizontalSpacing + metrics.minimumContentWidth
            ? .horizontal
            : .vertical
    }

    static func plan(
        axis: Axis,
        availableWidth: CGFloat?,
        label: Measurement,
        content: Measurement,
        metrics: Metrics,
        layoutDirection: LayoutDirection
    ) -> Plan {
        let metrics = metrics.normalized
        let width = normalizedWidth(availableWidth)
        let label = normalized(label, maximumWidth: width)
        let content = normalized(content, maximumWidth: width)

        switch axis {
        case .horizontal:
            return horizontalPlan(
                availableWidth: width,
                label: label,
                content: content,
                metrics: metrics,
                layoutDirection: layoutDirection
            )
        case .vertical:
            return verticalPlan(
                availableWidth: width,
                label: label,
                content: content,
                metrics: metrics,
                layoutDirection: layoutDirection
            )
        }
    }

    private static func horizontalPlan(
        availableWidth: CGFloat?,
        label: Measurement,
        content: Measurement,
        metrics: Metrics,
        layoutDirection: LayoutDirection
    ) -> Plan {
        let maximumContentWidth = availableWidth.map {
            max(0, $0 - label.size.width - metrics.horizontalSpacing)
        }
        let content = normalized(content, maximumWidth: maximumContentWidth)
        let intrinsicWidth = label.size.width + metrics.horizontalSpacing + content.size.width
        let width = availableWidth ?? intrinsicWidth
        let baseline = baselineOffsets(label: label, content: content, alignment: metrics.alignment)
        let labelY = baseline.label
        let contentY = baseline.content
        let height = max(labelY + label.size.height, contentY + content.size.height)

        let labelX: CGFloat
        let contentX: CGFloat
        switch layoutDirection {
        case .leftToRight:
            labelX = 0
            contentX = label.size.width + metrics.horizontalSpacing
        case .rightToLeft:
            labelX = max(0, width - label.size.width)
            contentX = max(0, labelX - metrics.horizontalSpacing - content.size.width)
        @unknown default:
            labelX = 0
            contentX = label.size.width + metrics.horizontalSpacing
        }

        return Plan(
            axis: .horizontal,
            size: CGSize(width: width, height: height),
            labelFrame: CGRect(origin: CGPoint(x: labelX, y: labelY), size: label.size),
            contentFrame: CGRect(origin: CGPoint(x: contentX, y: contentY), size: content.size)
        )
    }

    private static func verticalPlan(
        availableWidth: CGFloat?,
        label: Measurement,
        content: Measurement,
        metrics: Metrics,
        layoutDirection: LayoutDirection
    ) -> Plan {
        let width = availableWidth ?? max(label.size.width, content.size.width)
        let labelX = leadingOrigin(itemWidth: label.size.width, width: width, direction: layoutDirection)
        let contentX = leadingOrigin(itemWidth: content.size.width, width: width, direction: layoutDirection)
        let contentY = label.size.height + metrics.verticalSpacing

        return Plan(
            axis: .vertical,
            size: CGSize(width: width, height: contentY + content.size.height),
            labelFrame: CGRect(origin: CGPoint(x: labelX, y: 0), size: label.size),
            contentFrame: CGRect(origin: CGPoint(x: contentX, y: contentY), size: content.size)
        )
    }

    private static func normalized(
        _ measurement: Measurement,
        maximumWidth: CGFloat?
    ) -> Measurement {
        let rawWidth = measurement.size.width.isFinite ? max(0, measurement.size.width) : 0
        let width = maximumWidth.map { min(rawWidth, $0) } ?? rawWidth
        let height = measurement.size.height.isFinite ? max(0, measurement.size.height) : 0
        let baseline = measurement.firstBaseline.flatMap { value -> CGFloat? in
            guard value.isFinite else { return nil }
            return min(max(0, value), height)
        }
        return Measurement(size: CGSize(width: width, height: height), firstBaseline: baseline)
    }

    private static func baselineOffsets(
        label: Measurement,
        content: Measurement,
        alignment: Alignment
    ) -> (label: CGFloat, content: CGFloat) {
        guard alignment == .firstBaseline,
              let labelBaseline = label.firstBaseline,
              let contentBaseline = content.firstBaseline else {
            return (0, 0)
        }
        let sharedBaseline = max(labelBaseline, contentBaseline)
        return (sharedBaseline - labelBaseline, sharedBaseline - contentBaseline)
    }

    private static func leadingOrigin(
        itemWidth: CGFloat,
        width: CGFloat,
        direction: LayoutDirection
    ) -> CGFloat {
        switch direction {
        case .leftToRight:
            return 0
        case .rightToLeft:
            return max(0, width - itemWidth)
        @unknown default:
            return 0
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
private struct NativeAdaptiveLabelContentLayout: Layout {
    struct CacheKey: Equatable {
        let width: CGFloat?
        let metrics: NativeAdaptiveLabelContentGeometry.Metrics
        let layoutDirection: LayoutDirection
    }

    struct Cache {
        var key: CacheKey?
        var plan: NativeAdaptiveLabelContentGeometry.Plan?
    }

    let metrics: NativeAdaptiveLabelContentGeometry.Metrics
    let layoutDirection: LayoutDirection

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = Cache()
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        let width = NativeAdaptiveLabelContentGeometry.normalizedWidth(proposal.width)
        let plan = makePlan(width: width, subviews: subviews)
        cache = Cache(key: cacheKey(width: width), plan: plan)
        return plan.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        let width = NativeAdaptiveLabelContentGeometry.normalizedWidth(bounds.width)
        let key = cacheKey(width: width)
        let plan: NativeAdaptiveLabelContentGeometry.Plan
        if cache.key == key, let cached = cache.plan {
            plan = cached
        } else {
            plan = makePlan(width: width, subviews: subviews)
            cache = Cache(key: key, plan: plan)
        }

        subviews[0].place(
            at: CGPoint(
                x: bounds.minX + plan.labelFrame.minX,
                y: bounds.minY + plan.labelFrame.minY
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(plan.labelFrame.size)
        )
        subviews[1].place(
            at: CGPoint(
                x: bounds.minX + plan.contentFrame.minX,
                y: bounds.minY + plan.contentFrame.minY
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(plan.contentFrame.size)
        )
    }

    private func makePlan(
        width: CGFloat?,
        subviews: Subviews
    ) -> NativeAdaptiveLabelContentGeometry.Plan {
        precondition(
            subviews.count == 2,
            "NativeAdaptiveLabelContent requires one label and one content view"
        )

        let intrinsicLabel = measurement(of: subviews[0], width: nil)
        let axis = NativeAdaptiveLabelContentGeometry.axis(
            availableWidth: width,
            intrinsicLabelWidth: intrinsicLabel.size.width,
            metrics: metrics
        )

        let label: NativeAdaptiveLabelContentGeometry.Measurement
        let content: NativeAdaptiveLabelContentGeometry.Measurement
        switch axis {
        case .horizontal:
            label = measurement(of: subviews[0], width: width.map { min($0, intrinsicLabel.size.width) })
            let contentWidth = width.map {
                max(0, $0 - label.size.width - metrics.normalized.horizontalSpacing)
            }
            content = measurement(of: subviews[1], width: contentWidth)
        case .vertical:
            label = measurement(of: subviews[0], width: width)
            content = measurement(of: subviews[1], width: width)
        }

        return NativeAdaptiveLabelContentGeometry.plan(
            axis: axis,
            availableWidth: width,
            label: label,
            content: content,
            metrics: metrics,
            layoutDirection: layoutDirection
        )
    }

    private func measurement(
        of subview: LayoutSubview,
        width: CGFloat?
    ) -> NativeAdaptiveLabelContentGeometry.Measurement {
        let dimensions = subview.dimensions(in: ProposedViewSize(width: width, height: nil))
        return NativeAdaptiveLabelContentGeometry.Measurement(
            size: CGSize(width: dimensions.width, height: dimensions.height),
            firstBaseline: dimensions[explicit: VerticalAlignment.firstTextBaseline]
        )
    }

    private func cacheKey(width: CGFloat?) -> CacheKey {
        CacheKey(width: width, metrics: metrics.normalized, layoutDirection: layoutDirection)
    }
}
