---
name: performance-audit
description: Audit SwiftUI view performance end-to-end. Use when debugging SwiftUI slowness, frame drops, scroll jank, or when asked for a performance audit, profiling help, or optimization.
argument-hint: "[file or view name]"
---

# SwiftUI Performance Audit

**Target**: $ARGUMENTS

## Workflow Decision Tree

- **User provides code** → Start with Code-First Review.
- **User only describes symptoms** → Ask for minimal code/context, then Code-First Review.
- **Code review inconclusive** → Guide the User to Profile; ask for trace or screenshots.

---

## 1. Code-First Review

**Collect:** Target view/feature code; data flow (state, environment, observable models); symptoms and reproduction steps.

**Focus on:**

- View invalidation storms from broad state changes.
- Unstable identity in lists (id churn, `UUID()` per render).
- Heavy work in `body` (formatting, sorting, image decoding).
- Layout thrash (deep stacks, `GeometryReader`, preference chains).
- Large images without downsampling or resizing.
- Over-animated hierarchies (implicit animations on large trees).

**Provide:** Likely root causes with code references; suggested fixes and refactors; if needed, a minimal repro or instrumentation suggestion.

---

## 2. Guide the User to Profile

Explain how to collect data with Instruments:

- Use the **SwiftUI** template in Instruments (Release build).
- Reproduce the exact interaction (scroll, navigation, animation).
- Capture SwiftUI timeline and Time Profiler.
- Export or screenshot the relevant lanes and the call tree.

**Ask for:** Trace export or screenshots of SwiftUI lanes + Time Profiler call tree; device/OS/build configuration.

---

## 3. Analyze and Diagnose

Prioritize likely SwiftUI culprits (same list as Code-First Review). Summarize findings with evidence from traces/logs.

---

## 4. Remediate

Apply targeted fixes:

- Narrow state scope (`@State` / `@Observable` closer to leaf views).
- Stabilize identities for `ForEach` and lists.
- Move heavy work out of `body` (precompute, cache, `@State`).
- Use `equatable()` or value wrappers for expensive subtrees.
- Downsample images before rendering.
- Reduce layout complexity or use fixed sizing where possible.

---

## 5. Verify

Ask the user to re-run the same capture and compare with baseline metrics. Summarize the delta (CPU, frame drops, memory peak) if provided.

---

## Common Code Smells (and Fixes)

### Expensive formatters in body

```swift
var body: some View {
    let number = NumberFormatter()      // slow allocation
    let measure = MeasurementFormatter() // slow allocation
    Text(measure.string(from: .init(value: meters, unit: .meters)))
}
```

**Fix:** Cache formatters in a model or dedicated helper (e.g. `static let shared` with reused instances).

### Computed properties that do heavy work

```swift
var filtered: [Item] {
    items.filter { $0.isEnabled }  // runs on every body eval
}
```

**Fix:** Precompute or cache on change (e.g. `@State private var filtered: [Item]`; update when inputs change).

### Sorting/filtering in body or ForEach

```swift
List {
    ForEach(items.sorted(by: sortRule)) { item in Row(item) }
}
```

**Fix:** Sort once before view updates: `let sortedItems = items.sorted(by: sortRule)` (e.g. in model or view model).

### Inline filtering in ForEach

```swift
ForEach(items.filter { $0.isEnabled }) { item in Row(item) }
```

**Fix:** Use a prefiltered collection with stable identity.

### Unstable identity

```swift
ForEach(items, id: \.self) { item in Row(item) }
```

**Fix:** Avoid `id: \.self` for non-stable values; use a stable ID (e.g. `id: \.id` on a type with stable `id`).

### Image decoding on the main thread

```swift
Image(uiImage: UIImage(data: data)!)
```

**Fix:** Decode/downsample off the main thread and store the result; use a cached/downsampled image in the view.

### Broad dependencies in observable models

```swift
@Observable class Model {
    var items: [Item] = []
}
var body: some View {
    Row(isFavorite: model.items.contains(item))  // broad dependency
}
```

**Fix:** Prefer granular view models or per-item state to reduce update fan-out.

---

## Outputs

Provide:

- A short **metrics table** (before/after if available).
- **Top issues** (ordered by impact).
- **Proposed fixes** with estimated effort.

---

## References

- [references/optimizing-swiftui-performance-instruments.md](references/optimizing-swiftui-performance-instruments.md)
- [references/understanding-improving-swiftui-performance.md](references/understanding-improving-swiftui-performance.md)
- [references/understanding-hangs-in-your-app.md](references/understanding-hangs-in-your-app.md)
- [references/demystify-swiftui-performance-wwdc23.md](references/demystify-swiftui-performance-wwdc23.md)
