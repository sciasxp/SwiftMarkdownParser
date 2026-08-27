import SwiftUI

/// Stable identity allocated once while native output is materialized outside a view body.
struct NativeViewIdentity: Hashable, Comparable, Sendable {
    let ordinal: UInt64

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.ordinal < rhs.ordinal
    }
}

/// One unary, type-erased native view whose identity outlives every body evaluation.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
struct NativeMaterializedView: Identifiable, View {
    let id: NativeViewIdentity
    fileprivate let content: AnyView

    var body: some View {
        content
    }
}

/// Owns native view identity, type erasure, and identity-preserving transformations.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class NativeViewMaterializer {
    private var nextOrdinal: UInt64 = 0

    func identity() -> NativeViewIdentity {
        precondition(nextOrdinal < UInt64.max, "Native view identity space exhausted")
        defer { nextOrdinal += 1 }
        return NativeViewIdentity(ordinal: nextOrdinal)
    }

    func materialize<Content: View>(_ content: Content) -> NativeMaterializedView {
        NativeMaterializedView(id: identity(), content: AnyView(content))
    }

    func transform<Content: View>(
        _ materialized: NativeMaterializedView,
        @ViewBuilder _ transform: (NativeMaterializedView) -> Content
    ) -> NativeMaterializedView {
        NativeMaterializedView(
            id: materialized.id,
            content: AnyView(transform(materialized))
        )
    }
}
