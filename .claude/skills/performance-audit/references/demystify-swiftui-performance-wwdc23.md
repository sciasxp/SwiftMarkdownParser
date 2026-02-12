# Demystify SwiftUI Performance (WWDC23)

## SwiftUI's Dependency Graph

SwiftUI maintains an **attribute graph** — a directed acyclic graph that maps every view, dynamic property, and environment value to the views that depend on them. When a dependency changes, SwiftUI walks the graph to find affected views, marks them dirty, and schedules re-evaluation. Only dirty subgraphs are re-evaluated; the rest are skipped entirely.

Each view node in the graph has edges to its **inputs**: parent-produced values, `@State`, `@Binding`, `@Environment`, `@Query`, and any `@Observable` model properties read in `body`. Reading a property in `body` creates a dependency edge; not reading it means no edge exists and changes to that property will never invalidate the view.

```
[Environment: colorScheme] ──► [ParentView.body]
[model.title] ──────────────► [ChildView.body]
[model.count] ──────────────► [CounterView.body]
```

If `model.count` changes, only `CounterView` is re-evaluated. `ChildView` is untouched.

## View Identity and Lifetime

### Structural Identity
Views without an explicit `id` are identified by their **position in the view tree** (type + branch path). SwiftUI assigns structural identity based on the static type structure of the `body`. Conditional branches (`if/else`) produce different structural identities for each branch, forcing view destruction and recreation when the branch changes.

```swift
// Two distinct structural identities — state is destroyed on branch switch
if isLoggedIn {
    ProfileView()   // identity A
} else {
    LoginView()     // identity B
}
```

**Performance impact**: Branch switches destroy and recreate all state, subscriptions, and child views. Prefer view modifiers (`.opacity`, `.hidden`) or single-branch approaches when state preservation matters.

### Explicit Identity
Provided via `ForEach(items, id: \.stableID)` or the `.id()` modifier. Explicit identity **overrides** structural identity and directly controls view lifetime.

**Critical rule**: The lifetime of a view equals the duration of its identity. If the identity value changes, SwiftUI destroys the old view (including all `@State`, `@StateObject`, tasks) and creates a new one.

```swift
// WRONG: identity changes every render — view is destroyed and recreated each time
ForEach(items, id: \.self) { item in  // \.self on mutable structs = unstable
    ItemRow(item: item)
}

// RIGHT: stable identity — view is updated in place
ForEach(items, id: \.persistentID) { item in
    ItemRow(item: item)
}
```

## How SwiftUI Decides What to Re-evaluate

The update cycle follows this sequence:

1. **Dependency change detected** — a `@State`, `@Binding`, `@Observable` property, or environment value changes.
2. **Graph walk** — SwiftUI traverses the dependency graph to find every view that reads the changed value.
3. **Dirty marking** — affected views are marked for re-evaluation.
4. **Value comparison** — before calling `body`, SwiftUI compares the view struct's stored properties (using `Equatable` if conformed, otherwise reflection-based member-wise comparison). If all properties are equal to the previous value, `body` is **skipped**.
5. **Body evaluation** — if the comparison shows a difference, `body` runs and produces a new view tree.
6. **Diffing** — SwiftUI diffs the old and new trees to determine minimal render updates.

**Key insight**: Step 4 is the cheapest gate. Making views `Equatable` (or using the `@Equatable` macro) lets you control exactly which properties matter for diffing, potentially skipping expensive `body` evaluations.

## Dynamic Properties and Dependency Tracking

Dynamic properties (`@State`, `@Binding`, `@Environment`, `@Query`, `@AppStorage`) register dependencies **when read** in `body`. The tracking is automatic and precise:

```swift
struct MyView: View {
    @Environment(\.colorScheme) var colorScheme  // dependency registered on read

    var body: some View {
        // Only creates dependency if this branch executes
        if someCondition {
            Text("Scheme: \(colorScheme)")  // dependency edge created HERE
        }
    }
}
```

If `someCondition` is false and `colorScheme` is never accessed in that evaluation, no dependency is registered for that cycle. However, SwiftUI re-registers dependencies on each `body` evaluation, so the dependency set can change over time.

## @Observable vs ObservableObject

### ObservableObject (Legacy: objectWillChange)
Publishes a **single** `objectWillChange` signal. Every view holding `@ObservedObject` or `@EnvironmentObject` to that instance receives the signal and re-evaluates `body`, regardless of which `@Published` property changed.

```swift
// PROBLEM: changing `unrelatedCount` invalidates ALL views observing this model
class ViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var unrelatedCount: Int = 0
}
```

**Cost formula**: `(views observing the object) x (frequency of any property change)`.

### @Observable (Observation framework: property-level tracking)
Uses `ObservationRegistrar` with `access(keyPath:)` and `withMutation(keyPath:)` to track exactly which properties each view's `body` reads. Only views that read a specific changed property are invalidated.

```swift
@Observable class ViewModel {
    var title: String = ""        // tracked independently
    var unrelatedCount: Int = 0   // tracked independently
}

struct TitleView: View {
    let model: ViewModel
    var body: some View {
        Text(model.title)  // only depends on `title`
        // changing `unrelatedCount` does NOT trigger re-evaluation of this view
    }
}
```

**Cost formula**: `(views reading the specific property) x (frequency of that property's change)`.

**Migration guidance**: Replace `ObservableObject` with `@Observable`. Remove `@Published`. Replace `@ObservedObject` with a plain `let`/`var` or `@State` (for ownership). Replace `@EnvironmentObject` with `@Environment`.

## Common Performance Antipatterns

### 1. Using AnyView in ForEach / List
`AnyView` erases static type information, forcing SwiftUI to use runtime identity checks. List cannot determine row count without visiting all content.

```swift
// BAD: type-erased, forces full traversal
ForEach(items) { item in
    AnyView(rowView(for: item))
}

// GOOD: use @ViewBuilder or Group
ForEach(items) { item in
    rowView(for: item)  // returns concrete types via @ViewBuilder
}
```

### 2. Unstable ForEach identities
Using `id: \.self` on mutable values, or `UUID()` generated per render, causes identity churn — every render destroys and recreates all rows.

### 3. Filtering/sorting inside ForEach
Creates a new collection each `body` evaluation. The result has no stable structural relationship to the previous one, causing excessive diffing.

```swift
// BAD: sorts on every body call, unstable order can churn identities
ForEach(items.sorted(by: predicate)) { ... }

// GOOD: precompute in view model or @State, update on change
ForEach(sortedItems) { ... }
```

### 4. Broad @ObservedObject dependencies
A single `ObservableObject` with many `@Published` properties observed by many views creates O(N*M) invalidations. Split into focused models or migrate to `@Observable`.

### 5. Heavy computation in body
Formatters, date calculations, sorting, and image decoding in `body` run on the main thread during every re-evaluation.

```swift
// BAD: allocates formatter per body call
var body: some View {
    Text(NumberFormatter().string(from: value as NSNumber) ?? "")
}

// GOOD: static shared formatter or precomputed string
private static let formatter = NumberFormatter()
```

### 6. Conditional branches that destroy state
Using `if/else` instead of modifiers when you want to preserve child view state forces full teardown/recreation on branch switch. Prefer `.opacity(0)` or `.hidden()` to keep the view alive but invisible.
