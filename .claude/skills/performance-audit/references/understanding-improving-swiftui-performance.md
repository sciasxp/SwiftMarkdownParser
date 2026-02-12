# Understanding and Improving SwiftUI Performance

## Lazy Stacks vs Eager Stacks

**Eager stacks** (`VStack`, `HStack`) instantiate all child views immediately when the parent `body` evaluates. This is appropriate for small, fixed-size collections (fewer than ~20-30 items).

**Lazy stacks** (`LazyVStack`, `LazyHStack`) instantiate child views only when they are about to appear on screen. Views that scroll off screen may have their `body` storage released (but their identity and `@State` are preserved).

```swift
// WRONG: 1000 items all instantiated eagerly — causes hang on appear
ScrollView {
    VStack {
        ForEach(items) { item in ExpensiveRow(item: item) }
    }
}

// RIGHT: only visible items are instantiated
ScrollView {
    LazyVStack {
        ForEach(items) { item in ExpensiveRow(item: item) }
    }
}
```

### When to use eager stacks
- Small, fixed collections (settings screens, form fields)
- When you need the stack to size itself based on all children (e.g., centered content)
- Inside a `ScrollViewReader` where you need intrinsic content size

### When to use lazy stacks
- Collections with more than ~20-30 items
- Items that are expensive to create (images, complex layouts)
- Any scrollable list of dynamic data

### Lazy stack gotchas
- `LazyVStack` does not support `spacing` the same way — padding on individual items is more predictable.
- Lazy stacks use **id-based recycling**. Unstable identities cause excessive view creation/destruction.
- Avoid `.onAppear`/`.onDisappear` for data loading in lazy stacks if items can rapidly appear/disappear during fast scrolling. Use `.task` which auto-cancels.

## Identity Stability and Its Impact on Performance

View identity determines whether SwiftUI **updates** an existing view or **destroys and recreates** it. Stable identity is the single most important factor for list/scroll performance.

### Rules for stable identity:
1. Use a persistent, unique identifier (database ID, UUID stored at creation time).
2. Never use `UUID()` in a computed property or `body` — it generates a new value each evaluation.
3. Avoid `id: \.self` on mutable types — if the value changes, the identity changes, forcing recreation.
4. Never use array index as identity — insertions/deletions shift all subsequent identities.

```swift
// BAD: array index identity — inserting at index 0 invalidates ALL rows
ForEach(Array(items.enumerated()), id: \.offset) { index, item in
    Row(item: item)
}

// BAD: \.self on a mutable struct — editing a field changes the identity
ForEach(items, id: \.self) { item in Row(item: item) }

// GOOD: stable persistent ID
ForEach(items, id: \.id) { item in Row(item: item) }

// BEST: Identifiable conformance (ForEach infers id)
ForEach(items) { item in Row(item: item) }
```

**Impact of identity churn**: When an identity changes, SwiftUI destroys the old view (releasing all `@State`, canceling `.task`, removing animations) and creates a new one from scratch. In a list of 100 items, changing all identities means 100 destructions + 100 creations instead of 100 in-place updates.

## Minimizing View Body Complexity

Every expression in `body` runs on the **main thread** during view evaluation. The budget for `body` at 120fps is approximately **8ms per frame** total across all views that update in that frame.

### Principles:
- **No allocation-heavy operations**: formatters, date components, attributed strings.
- **No collection operations**: sorting, filtering, mapping, reducing.
- **No I/O**: file reads, image decoding, database queries.
- **No expensive string operations**: regex, localized string formatting with runtime parameters.

```swift
// BAD: multiple expensive operations in body
var body: some View {
    let sorted = items.sorted { $0.date > $1.date }
    let filtered = sorted.filter { $0.isActive }
    let formatted = filtered.map { DateFormatter().string(from: $0.date) }
    // ...
}

// GOOD: precomputed and cached
@Observable class ViewModel {
    var items: [Item] = [] { didSet { updateDerived() } }
    private(set) var displayItems: [(item: Item, dateString: String)] = []

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private func updateDerived() {
        displayItems = items
            .filter(\.isActive)
            .sorted { $0.date > $1.date }
            .map { (item: $0, dateString: Self.formatter.string(from: $0.date)) }
    }
}
```

### Extract subviews aggressively

Each extracted subview only re-evaluates when **its own inputs** change. A monolithic `body` re-evaluates everything when any dependency changes.

```swift
// BAD: monolithic body — changing `title` re-evaluates the image section too
var body: some View {
    VStack {
        Text(title)
        AsyncImage(url: imageURL)  // re-evaluated even though URL didn't change
        Text(subtitle)
    }
}

// GOOD: extracted — each subview only re-evaluates on its own input changes
var body: some View {
    VStack {
        TitleView(title: title)
        CachedImageView(url: imageURL)
        SubtitleView(subtitle: subtitle)
    }
}
```

## Using equatable() and drawingGroup() Correctly

### equatable()

The `.equatable()` modifier tells SwiftUI to use the view's `Equatable` conformance to decide whether to re-evaluate `body`. If `==` returns `true`, `body` is **skipped entirely** — no evaluation, no diffing.

```swift
struct ExpensiveChartView: View, Equatable {
    let dataPoints: [DataPoint]
    let colorScheme: ColorScheme

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.dataPoints == rhs.dataPoints &&
        lhs.colorScheme == rhs.colorScheme
    }

    var body: some View {
        // Complex chart rendering — only runs if data or scheme changed
        Canvas { context, size in
            // expensive drawing
        }
    }
}

// Usage
ExpensiveChartView(dataPoints: data, colorScheme: scheme)
    .equatable()
```

The `@Equatable` macro (iOS 18+) auto-generates `Equatable` conformance, excluding `@State` and `@Environment` properties. Properties that are not `Equatable` and do not affect output can be annotated with `@SkipEquatable`.

**Warning**: `.equatable()` can **block legitimate updates** if the `Equatable` conformance is too aggressive (compares equal when the view should actually update). When debugging rendering issues, always check for `.equatable()` modifiers first.

### drawingGroup()

The `.drawingGroup()` modifier renders the entire subtree into an **offscreen Metal texture** before compositing it as a single image. This collapses a complex layer tree into one layer.

```swift
// Complex gradient/particle view that produces hundreds of layers
ZStack {
    ForEach(0..<200) { i in
        Circle()
            .fill(gradient)
            .offset(x: offsets[i].x, y: offsets[i].y)
    }
}
.drawingGroup()  // renders all 200 circles as a single Metal texture
```

**When to use**: Complex drawings with many overlapping shapes (particles, charts, generative art). The rendering work moves from Core Animation to Metal.

**When NOT to use**: Simple views, views with text (text rendering quality may degrade), views that change frequently (the offscreen pass runs every frame). Adding `.drawingGroup()` to a simple view can make it **slower** due to the overhead of the offscreen render pass.

## Image Loading and Downsampling Best Practices

Displaying a full-resolution image wastes memory and causes main-thread hangs during decoding. A 12MP image (4032x3024) uses ~48MB in memory as a decoded bitmap.

### Downsample with ImageIO (fastest method)

```swift
func downsample(imageAt url: URL, to pointSize: CGSize, scale: CGFloat) -> UIImage? {
    let maxDimension = max(pointSize.width, pointSize.height) * scale
    let options: [CFString: Any] = [
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimension
    ]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    return UIImage(cgImage: cgImage)
}
```

**Performance**: ImageIO downsampling of a 12MP JPEG takes ~16ms (vs ~130ms for `UIImage.preparingThumbnail(of:)`, vs ~200ms for `UIImage(data:)`). Always use ImageIO for performance-critical paths.

### UIKit preparingThumbnail (simpler API)

```swift
// Async thumbnail — runs off main thread
let thumbnail = await originalImage.byPreparingThumbnail(ofSize: targetSize)
```

### SwiftUI AsyncImage with downsampling

For network images, `AsyncImage` handles async loading but does NOT downsample. Combine it with a custom downsampling phase:

```swift
AsyncImage(url: imageURL) { phase in
    switch phase {
    case .success(let image):
        image.resizable().aspectRatio(contentMode: .fill)
    case .failure:
        Color.gray
    case .empty:
        ProgressView()
    @unknown default:
        EmptyView()
    }
}
.frame(width: 100, height: 100)
.clipped()
```

For local images, always downsample before creating `Image(uiImage:)`.

## List and Scroll View Performance

### Use List for large data sets over ScrollView + LazyVStack

`List` provides cell recycling similar to `UITableView`. `LazyVStack` creates views lazily but does not aggressively recycle them.

### Prefetch hints

`List` internally prefetches upcoming rows. For custom scroll views, use `.onAppear` with a threshold to trigger data loading before the user reaches the bottom.

### Avoid complex content in rows

Each list row's `body` is evaluated during scrolling. Keep row views simple and precompute derived data.

```swift
// BAD: per-row computation during scroll
struct ItemRow: View {
    let item: Item
    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
            Text(RelativeDateTimeFormatter().localizedString(for: item.date, relativeTo: .now))
        }
    }
}

// GOOD: precomputed relative date string
struct ItemRow: View {
    let item: Item
    let relativeDateString: String  // computed once in view model
    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
            Text(relativeDateString)
        }
    }
}
```

### Avoid nesting ForEach

Nested `ForEach` inside a `List` forces List to visit all content to determine row count, defeating lazy evaluation.

```swift
// BAD: nested ForEach — List cannot determine row count efficiently
List {
    ForEach(sections) { section in
        ForEach(section.items) { item in Row(item: item) }
    }
}

// GOOD: use Section for grouping
List {
    ForEach(sections) { section in
        Section(section.title) {
            ForEach(section.items) { item in Row(item: item) }
        }
    }
}
```

## State Management Patterns That Minimize Re-renders

### Push state down to leaf views

State declared at a parent level invalidates all children when it changes. Move `@State` to the lowest view that needs it.

```swift
// BAD: toggle state at parent invalidates both children
struct ParentView: View {
    @State private var isExpanded = false
    var body: some View {
        VStack {
            ExpensiveHeaderView()  // re-evaluates when isExpanded changes
            ToggleButton(isExpanded: $isExpanded)
        }
    }
}

// GOOD: toggle state scoped to the button
struct ToggleSection: View {
    var body: some View {
        VStack {
            ExpensiveHeaderView()  // never re-evaluates from toggle
            ExpandableContent()    // owns its own @State
        }
    }
}
```

### Use @Binding to share without broadening scope

`@Binding` creates a reference to state owned elsewhere without making the parent a dependency of the child.

### Avoid storing derived state

Derived state (computed from other state) should be computed properties or precomputed values in the view model — not separate `@State` properties that need manual synchronization.

```swift
// BAD: derived @State that can desync
@State private var items: [Item] = []
@State private var filteredItems: [Item] = []  // must be manually updated

// GOOD: computed property
var filteredItems: [Item] { items.filter(\.isActive) }  // if cheap enough

// GOOD: precomputed in @Observable model
@Observable class VM {
    var items: [Item] = [] { didSet { filtered = items.filter(\.isActive) } }
    private(set) var filtered: [Item] = []
}
```

## @Observable Property Granularity

With `@Observable`, each property is tracked independently. This means the **structure of your model** directly determines the granularity of view updates.

### Split unrelated properties into separate models

```swift
// BAD: reading `title` also creates dependency on the entire model
// (fine with @Observable, but if many views read different properties, consider splitting)
@Observable class AppState {
    var userProfile: Profile = .empty
    var settings: Settings = .default
    var notifications: [Notification] = []
}

// GOOD: separate models for unrelated concerns
@Observable class UserState { var profile: Profile = .empty }
@Observable class SettingsState { var settings: Settings = .default }
@Observable class NotificationState { var items: [Notification] = [] }
```

### Computed properties are observed through their dependencies

```swift
@Observable class ViewModel {
    var firstName: String = ""
    var lastName: String = ""
    var fullName: String { "\(firstName) \(lastName)" }  // observed through firstName + lastName
}
// A view reading `fullName` will update when EITHER firstName or lastName changes
```

### Avoid reading properties you do not display

```swift
// BAD: reads `model.items` to compute count — now depends on the entire array
Text("Count: \(model.items.count)")

// BETTER: expose a dedicated count property
// In the model:
var itemCount: Int { items.count }
// In the view:
Text("Count: \(model.itemCount)")
// Still depends on items internally, but expresses intent clearly
```

### Use @State for view-local observable objects

```swift
// Creates and owns the model — survives view re-creation by parent
struct DetailView: View {
    @State private var viewModel = DetailViewModel()
    // ...
}
```

Using `let viewModel = DetailViewModel()` without `@State` creates a new instance every time the parent re-evaluates `body`. With `@State`, SwiftUI preserves the instance across re-evaluations as long as the view's identity is stable.
