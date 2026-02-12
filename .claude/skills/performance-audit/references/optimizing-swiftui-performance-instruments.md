# Optimizing SwiftUI Performance with Instruments

## The SwiftUI Instruments Template

Xcode Instruments includes a dedicated **SwiftUI** profiling template. Always profile on a **physical device** with a **Release build** (optimizations enabled) — simulator results are unreliable for performance analysis.

**Access**: Xcode > Product > Profile (Cmd+I) > choose the "SwiftUI" template.

The SwiftUI template bundles these instruments:
- **SwiftUI** instrument (view lifecycle and updates)
- **Time Profiler** (CPU sampling)
- **Core Animation Commits** (render server work)
- **Allocations** (memory churn)

## SwiftUI Instrument Lanes

The SwiftUI instrument (Instruments 26+) provides four tracking lanes:

| Lane | What It Shows |
|------|---------------|
| **Update Groups** | Active SwiftUI work — clusters of view evaluations triggered by a single state change |
| **Long View Body Updates** | Views whose `body` evaluation exceeds the frame budget (color-coded orange/red by severity) |
| **Long Representable Updates** | Slow `UIViewRepresentable` / `UIViewControllerRepresentable` update cycles |
| **Other Long Updates** | Additional performance issues (environment propagation, preference key resolution) |

Results are color-coded: **orange** = likely contributed to a hitch; **red** = almost certainly caused a frame drop.

## View Body Trace: What It Shows and How to Interpret

Each entry in the View Body lane shows:
- **Which view's `body`** was evaluated (by type name)
- **Duration** of the `body` evaluation in microseconds/milliseconds
- **Cause** — which state change or dependency triggered the evaluation

### Interpreting Results

- **Single long body (>2ms on iPhone)**: The view is doing too much work. Look for formatters, sorting, image decoding, or complex layout in `body`.
- **Many short bodies in one frame**: View invalidation storm — a single state change cascaded to too many views. Check for broad `@ObservedObject` dependencies or environment changes at a high level.
- **Repeated evaluations of the same view**: That view's dependencies are changing rapidly (e.g., animation-driven state, timer, frequent network updates).

### Cause & Effect Graph

Instruments 26+ includes a **cause-and-effect visualization** that traces the chain from user interaction to state change to view invalidation. This reveals:
- Which state mutation triggered the cascade
- How many views were affected
- Whether unrelated views were needlessly invalidated

Use this to identify **over-broad dependency patterns** — e.g., a favorites toggle that invalidates every list row because each row reads the entire favorites array.

## Core Animation Commits Instrument

This instrument measures time spent in the **render server** (the out-of-process compositor). High commit times indicate:

- **Offscreen rendering**: Effects like shadows, masks, rounded corners with `clipShape` on complex hierarchies.
- **Large layer trees**: Too many `CALayer` instances from deeply nested view hierarchies.
- **Excessive blending**: Many overlapping translucent layers.

### What to look for:
- Commit durations > 4ms consistently (targeting 120fps means ~8ms total frame budget)
- Spikes during scroll or animation
- Correlation with visual complexity (e.g., large images, many overlays)

**Fix patterns**: Rasterize stable complex subtrees with `.drawingGroup()`, reduce layer count by flattening view hierarchy, pre-render shadows as images.

## Time Profiler for Finding Expensive Operations

The Time Profiler samples the call stack at regular intervals (typically 1ms). Use it to find main-thread bottlenecks during SwiftUI updates.

### Step-by-step usage:
1. Start profiling, reproduce the problematic interaction.
2. Select the time range around the hitch/hang.
3. In the call tree, set **"Separate by Thread"** and focus on **Thread 1 (Main Thread)**.
4. Enable **"Invert Call Tree"** to see the hottest leaf functions first.
5. Enable **"Hide System Libraries"** to focus on your code.

### Common hotspots in SwiftUI apps:
- `SwiftUI.ViewBody.evaluate()` — body is being called; check what's inside it.
- `NumberFormatter.init` / `DateFormatter.init` — formatter allocation in body.
- `Array.sort` / `Array.filter` — collection operations in body.
- `UIImage(data:)` / `CGImageSource` — image decoding on main thread.
- `ModelContext.fetch` — synchronous SwiftData query in body.

## Identifying View Invalidation Storms

A **view invalidation storm** occurs when a single state change triggers dozens or hundreds of view `body` evaluations in one frame. Symptoms:

- In the SwiftUI instrument: a dense cluster of short body evaluations all in one update group.
- In Time Profiler: `SwiftUI.UpdateCoalescingGroup` or `AG::Graph::UpdateValue` appearing frequently.
- Visible hitch or dropped frames during state change.

### Diagnostic steps:
1. In the SwiftUI instrument, click an update group and count the views that re-evaluated.
2. Check if unrelated views are in the group — they should not be.
3. Trace the cause: is it a broad `@ObservedObject`? An environment value changing at the root?

### Common causes and fixes:

| Cause | Fix |
|-------|-----|
| `ObservableObject` with many `@Published` properties | Migrate to `@Observable` for property-level tracking |
| Environment value set at root (e.g., custom theme) | Push environment values to the narrowest scope possible |
| `@State` array mutation triggers full list rebuild | Use stable identities; precompute filtered/sorted collections |
| Parent body re-evaluates and passes new closures | Extract child views into separate structs; use `@Binding` instead of closures |

## Identifying Unnecessary Re-renders

A re-render is unnecessary when `body` evaluates but the output is identical to the previous evaluation. This wastes CPU but produces no visible change.

### Detection methods:
1. **`Self._printChanges()` in debug builds**: Insert `let _ = Self._printChanges()` in `body` to log which property triggered the re-evaluation. If the logged property didn't actually affect the output, the re-render was unnecessary.
2. **SwiftUI instrument**: Look for views that re-evaluate frequently but produce identical output (correlate with no visible UI change).
3. **Equatable conformance test**: Make the view `Equatable` and log when `==` returns true but `body` was still called — this indicates the equality check was not in place.

```swift
// Debug helper — remove before shipping
struct DebugView: View {
    let value: Int
    var body: some View {
        let _ = Self._printChanges()  // prints: "DebugView: value changed."
        Text("\(value)")
    }
}
```

### Fixes for unnecessary re-renders:
- Add `Equatable` conformance (or `@Equatable` macro) and apply `.equatable()` modifier.
- Move the view into a separate struct so it only re-evaluates when its own inputs change.
- Use `@Observable` to get property-level tracking instead of object-level.

## Step-by-Step Profiling Workflow

1. **Build for profiling**: Product > Profile (Release build, physical device).
2. **Choose template**: Select "SwiftUI" template (includes SwiftUI, Time Profiler, Core Animation).
3. **Reproduce**: Perform the exact interaction that causes the issue (scroll, navigate, animate). Run for 10-30 seconds.
4. **Stop recording** and analyze.
5. **Check SwiftUI lane first**: Look for orange/red long body evaluations. Identify the worst offenders by duration.
6. **Check update group density**: If many views update per frame, you have an invalidation storm.
7. **Correlate with Time Profiler**: Select the same time range. Invert call tree, hide system libraries, look for your code in the hottest frames.
8. **Check Core Animation commits**: If commits are slow, the rendering pipeline is overloaded — simplify the layer tree.
9. **Check Allocations**: Look for allocation spikes during interaction — transient object creation (formatters, images, view models) during scroll.
10. **Fix, re-profile, compare**: Always re-profile after changes to verify improvement.

### Seven High-Impact Scenarios to Profile

1. **Cold app launch** — heavy initialization, synchronous data loading
2. **Scrolling long lists** — cell recycling, image loading, identity stability
3. **Navigation push/pop** — transition animations, destination view creation
4. **Tab switching** — lazy vs eager tab content, state restoration
5. **Deep link entry** — multiple navigation levels constructed at once
6. **Background to foreground** — state restoration, data refresh
7. **Orientation changes** — layout recalculation, geometry reader cascades

These seven scenarios expose approximately 90% of real-world SwiftUI performance issues.
