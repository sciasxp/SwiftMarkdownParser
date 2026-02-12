# Understanding Hangs in Your App

## What Constitutes a Hang

A **hang** occurs when the main thread is blocked for long enough that the app cannot respond to user input or update the display. The system defines hangs by duration:

| Duration | Classification | User Perception |
|----------|---------------|-----------------|
| **250ms - 500ms** | Micro hang | Noticeable stutter; app feels sluggish |
| **500ms - 2s** | Hang | App clearly unresponsive; user may retry tap |
| **2s - 10s** | Severe hang | User likely tries to force-quit |
| **> 10s** | Fatal hang | iOS watchdog may terminate the app |

The 250ms threshold is the point at which delays become perceptible to users. Any main-thread block exceeding this creates a measurable hang.

### The Main Run Loop

The main thread runs a `CFRunLoop` that processes events, layout, and rendering in a continuous cycle: receive event > dispatch to handlers > layout > commit to render server > wait for next event. A hang occurs when any step in this cycle takes too long, delaying the entire pipeline.

## Common Causes of Hangs

### 1. Synchronous I/O on the Main Thread

File reads, database queries, and network requests that block the calling thread.

```swift
// HANG: synchronous file read blocks main thread
func loadData() {
    let data = try! Data(contentsOf: largeFileURL)  // blocks until complete
    self.items = decode(data)
}

// FIX: async file read
func loadData() async {
    let data = try? await Task.detached {
        try Data(contentsOf: largeFileURL)
    }.value
    self.items = decode(data ?? Data())
}
```

SwiftData's `ModelContext.fetch()` is synchronous. For large result sets, this blocks the main thread.

```swift
// HANG: large SwiftData fetch on main thread
var body: some View {
    let items = try? modelContext.fetch(descriptor)  // blocks if large
    // ...
}

// FIX: use @Query (async) or fetch in .task
@Query(sort: \Item.date) var items: [Item]
```

### 2. Expensive Layout and Rendering

Deep view hierarchies, complex `GeometryReader` chains, or unoptimized images force expensive layout passes.

```swift
// HANG-RISK: nested GeometryReaders cause multiple layout passes
GeometryReader { outer in
    GeometryReader { inner in
        // layout is recalculated for both readers
    }
}

// FIX: use a single GeometryReader or .onGeometryChange
```

### 3. Large View Hierarchies

SwiftUI must diff the entire view tree on updates. A `body` that produces hundreds of views (e.g., non-lazy `VStack` with 500 items) triggers expensive tree comparison.

```swift
// HANG: eager stack with hundreds of items
ScrollView {
    VStack {
        ForEach(allItems) { item in  // 500+ items all created eagerly
            ItemRow(item: item)
        }
    }
}

// FIX: lazy stack defers creation
ScrollView {
    LazyVStack {
        ForEach(allItems) { item in
            ItemRow(item: item)
        }
    }
}
```

### 4. Image Decoding on the Main Thread

Loading a full-resolution image from disk or network and decoding it synchronously blocks the main thread. A 12MP JPEG can take 50-200ms to decode.

```swift
// HANG: synchronous decode of large image
Image(uiImage: UIImage(data: imageData)!)

// FIX: decode + downsample off main thread
@State private var thumbnail: UIImage?

.task {
    thumbnail = await downsample(data: imageData, to: targetSize)
}
```

### 5. Lock Contention and Priority Inversion

Main thread waiting on a lock held by a lower-priority background thread. The main thread is blocked until the background thread (which may be deprioritized by the scheduler) completes.

### 6. Expensive Computed Properties in Body

Sorting, filtering, date formatting, or number formatting performed inside `body`.

## Detecting Hangs with Instruments

### Thread State Trace

The **Thread States** instrument shows the exact state of each thread over time:

| State | Meaning |
|-------|---------|
| **Running** | Thread is executing on a CPU core |
| **Blocked** | Thread is waiting (I/O, lock, semaphore) |
| **Preempted** | Thread was interrupted by the scheduler |
| **Runnable** | Thread is ready but waiting for a CPU core |

For hang diagnosis: select the main thread and look for long **Blocked** or **Runnable** intervals during the hang period. Click the interval to see the blocking call stack.

### Hangs Instrument

The **Hangs** instrument (available in Xcode 14+) automatically detects and labels main-thread hangs:
- Shows hang duration and severity (micro, severe, fatal)
- Marks the exact time range of each hang
- Correlates with the call stack at the point of blocking

**Workflow**: Record with the Hangs instrument active. Reproduce the issue. The hang appears as a colored interval in the timeline. Click it to see the main thread's call stack during the hang.

### Time Profiler for Hang Investigation

When the Hangs instrument identifies a hang, switch to the **Time Profiler** track for the same time range. The call tree shows exactly which function was consuming main-thread time. Use "Invert Call Tree" to see leaf functions first.

## Fixing Main-Thread Blocking

### Pattern 1: Move to async/await

```swift
// BEFORE: blocks main thread
func processImages() {
    let results = images.map { resize($0) }  // synchronous, expensive
    self.thumbnails = results
}

// AFTER: async processing, main-thread update
func processImages() async {
    let results = await withTaskGroup(of: UIImage.self) { group in
        for image in images {
            group.addTask { resize(image) }
        }
        return await group.reduce(into: []) { $0.append($1) }
    }
    self.thumbnails = results  // back on MainActor via @MainActor
}
```

### Pattern 2: Task.detached for CPU-bound work

```swift
// Heavy computation off the main actor
@MainActor
func computeStatistics() async {
    let stats = await Task.detached {
        // runs on cooperative thread pool, NOT main thread
        return self.data.computeExpensiveStatistics()
    }.value
    self.statistics = stats  // update UI on main actor
}
```

### Pattern 3: Precomputation on data change

```swift
@Observable class ViewModel {
    var items: [Item] = [] {
        didSet { recomputeSorted() }
    }
    private(set) var sortedItems: [Item] = []

    private func recomputeSorted() {
        sortedItems = items.sorted(by: sortRule)
    }
}
```

### Pattern 4: Progressive loading

For large data sets, load and display incrementally:

```swift
@State private var visibleItems: [Item] = []

.task {
    for batch in allItems.chunked(into: 50) {
        visibleItems.append(contentsOf: batch)
        try? await Task.sleep(for: .milliseconds(16))  // yield to render
    }
}
```

## MetricKit and On-Device Hang Detection

### MXHangDiagnostic (MetricKit)

`MXHangDiagnostic` provides hang reports from users in the field. Available in iOS 16+. Reports include:

- **Hang duration** (total time the main thread was blocked)
- **Call stack tree** at the point of the hang
- **Aggregated data** across many user sessions

```swift
class MetricsSubscriber: NSObject, MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            if let hangDiagnostics = payload.hangDiagnostics {
                for hang in hangDiagnostics {
                    // hang.hangDuration — total hang time
                    // hang.callStackTree — where it happened
                    log(hang)
                }
            }
        }
    }
}

// Register in app startup
MXMetricManager.shared.add(subscriber)
```

### On-Device Hang Detection (Developer Settings)

iOS 16+ includes an on-device hang detection feature accessible in **Settings > Developer > Hang Detection**. When enabled on development-signed or TestFlight builds:
- Displays a real-time notification when a hang is detected
- Records the hang with call stack for later review
- Does not require Instruments or a tethered Mac

### Xcode Organizer Hang Reports

For shipped apps, the **Xcode Organizer > Hangs** tab aggregates hang reports from consenting users:
- Groups hangs by call stack signature
- Shows frequency and severity distribution
- Available without any code changes (system-collected)

## Checklist for Hang Prevention

- [ ] No synchronous file/network I/O on main thread
- [ ] No heavy computation (sort, filter, encode/decode) in `body` or event handlers
- [ ] Images are downsampled off the main thread before display
- [ ] SwiftData queries use `@Query` or are performed in `.task`
- [ ] Lock usage avoids priority inversion (use actors or async alternatives)
- [ ] Large collections are loaded progressively, not all at once
- [ ] `GeometryReader` is used sparingly and not nested
- [ ] View hierarchies use `LazyVStack`/`LazyHStack` for large collections
