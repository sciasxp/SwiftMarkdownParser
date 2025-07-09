# SwiftUI Renderer Documentation

Complete guide to using the SwiftMarkdownParser SwiftUI renderer for creating native iOS and macOS markdown views.

## Table of Contents

- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Basic Usage](#basic-usage)
- [Styling and Theming](#styling-and-theming)
- [Accessibility](#accessibility)
- [Interactive Features](#interactive-features)
- [Performance Optimization](#performance-optimization)
- [Advanced Integration](#advanced-integration)
- [Error Handling](#error-handling)
- [Platform Differences](#platform-differences)
- [API Reference](#api-reference)

## Quick Start

```swift
import SwiftUI
import SwiftMarkdownParser

struct ContentView: View {
    let markdown = "# Hello **SwiftUI**!\n\nThis is native SwiftUI rendering."
    
    var body: some View {
        MarkdownView(markdown: markdown)
    }
}

struct MarkdownView: View {
    let markdown: String
    @State private var content: AnyView?
    
    var body: some View {
        Group {
            if let content = content {
                content
            } else {
                ProgressView()
            }
        }
        .task {
            await loadMarkdown()
        }
    }
    
    private func loadMarkdown() async {
        do {
            let parser = SwiftMarkdownParser()
            let ast = try await parser.parseToAST(markdown)
            let renderer = SwiftUIRenderer()
            let view = try await renderer.render(document: ast)
            
            await MainActor.run {
                self.content = view
            }
        } catch {
            await MainActor.run {
                self.content = AnyView(Text("Error: \(error.localizedDescription)"))
            }
        }
    }
}
```

## Requirements

- **iOS 17.0+** or **macOS 14.0+**
- **Swift 6.0+**
- **Xcode 16.0+**
- **SwiftUI framework**

## Basic Usage

### Creating a SwiftUI Renderer

```swift
// Default renderer
let renderer = SwiftUIRenderer()

// Custom renderer with configuration
let context = SwiftUIRenderContext(
    styleConfiguration: SwiftUIStyleConfiguration(),
    linkHandler: { url in
        UIApplication.shared.open(url)
    }
)
let renderer = SwiftUIRenderer(context: context)
```

### Rendering Documents

```swift
// Parse and render
let parser = SwiftMarkdownParser()
let ast = try await parser.parseToAST(markdown)
let view = try await renderer.render(document: ast)

// Use in SwiftUI
struct MyView: View {
    var body: some View {
        ScrollView {
            view
                .padding()
        }
    }
}
```

### Rendering Individual Nodes

```swift
// Render specific nodes
let headingNode = AST.HeadingNode(level: 1, children: [
    AST.TextNode(content: "My Title")
])
let headingView = try await renderer.render(node: headingNode)
```

## Styling and Theming

### Basic Style Configuration

```swift
let styleConfig = SwiftUIStyleConfiguration(
    // Typography
    bodyFont: .body,
    codeFont: .system(.body, design: .monospaced),
    headingFonts: [
        1: .largeTitle,
        2: .title,
        3: .title2,
        4: .title3,
        5: .headline,
        6: .subheadline
    ],
    
    // Colors
    textColor: .primary,
    headingColor: .primary,
    linkColor: .blue,
    codeTextColor: .primary,
    codeBackgroundColor: Color.gray.opacity(0.1),
    
    // Spacing
    documentSpacing: 16,
    paragraphSpacing: 8,
    listItemSpacing: 4
)
```

### Dark Mode Support

```swift
let darkModeConfig = SwiftUIStyleConfiguration(
    textColor: .primary,                          // Adapts automatically
    headingColor: .primary,
    linkColor: .blue,
    codeBackgroundColor: Color(.systemGray6),     // System colors
    blockQuoteBackgroundColor: Color(.systemGray6),
    blockQuoteBorderColor: .blue,
    tableBorderColor: Color(.systemGray4)
)
```

### Custom Theme Example

```swift
struct BlogTheme {
    static let configuration = SwiftUIStyleConfiguration(
        bodyFont: .system(.body, design: .serif),
        headingFonts: [
            1: .system(.largeTitle, design: .serif, weight: .bold),
            2: .system(.title, design: .serif, weight: .semibold),
            3: .system(.title2, design: .serif, weight: .medium)
        ],
        headingColor: Color(.systemBlue),
        linkColor: Color(.systemIndigo),
        codeBackgroundColor: Color(.systemGray6),
        blockQuoteBackgroundColor: Color(.systemBlue).opacity(0.05),
        blockQuoteBorderColor: Color(.systemBlue),
        tableBorderColor: Color(.systemGray4),
        tableHeaderBackgroundColor: Color(.systemGray5)
    )
}

// Usage
let context = SwiftUIRenderContext(
    styleConfiguration: BlogTheme.configuration
)
```

### Responsive Design

```swift
struct ResponsiveMarkdownView: View {
    let markdown: String
    @Environment(\.horizontalSizeClass) var sizeClass
    
    private var styleConfig: SwiftUIStyleConfiguration {
        SwiftUIStyleConfiguration(
            bodyFont: sizeClass == .compact ? .body : .title3,
            documentSpacing: sizeClass == .compact ? 12 : 20,
            paragraphSpacing: sizeClass == .compact ? 6 : 12
        )
    }
    
    var body: some View {
        MarkdownView(
            markdown: markdown,
            styleConfiguration: styleConfig
        )
    }
}
```

## Accessibility

### Built-in Accessibility Features

The SwiftUI renderer includes comprehensive accessibility support:

- **VoiceOver**: Proper labels and hints for all elements
- **Dynamic Type**: Automatic font scaling support
- **Semantic Traits**: Headers, links, buttons identified correctly
- **Navigation**: Logical reading order maintained

### Accessibility Configuration

```swift
let accessibleContext = SwiftUIRenderContext(
    styleConfiguration: SwiftUIStyleConfiguration(
        bodyFont: .body,  // Supports Dynamic Type
        headingFonts: [    // Also supports Dynamic Type
            1: .largeTitle,
            2: .title,
            3: .title2
        ]
    ),
    enableAccessibility: true  // Enable enhanced accessibility features
)
```

### Custom Accessibility Labels

```swift
// The renderer automatically provides appropriate accessibility labels:
// - Headings: "Heading level 1: Title text"
// - Links: "Link: destination URL"
// - Images: "Image: alt text"
// - Code blocks: "Code block in Swift: code content"
// - Task lists: "Completed task" or "Incomplete task"
```

### VoiceOver Testing

```swift
// Test accessibility in simulator
#if DEBUG
struct AccessibilityTestView: View {
    var body: some View {
        MarkdownView(markdown: """
        # Accessibility Test
        
        This is a **bold** statement with a [link](https://apple.com).
        
        - [x] Completed task
        - [ ] Pending task
        """)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Markdown content")
    }
}
#endif
```

## Interactive Features

### Link Handling

```swift
let interactiveContext = SwiftUIRenderContext(
    linkHandler: { url in
        // Custom link routing
        if url.scheme == "myapp" {
            handleDeepLink(url)
        } else if url.host?.contains("internal") == true {
            navigateInternally(to: url)
        } else {
            // Open external links
            Task { @MainActor in
                UIApplication.shared.open(url)
            }
        }
    }
)

func handleDeepLink(_ url: URL) {
    // Handle app-specific URLs like myapp://profile/123
    if url.path == "/profile" {
        // Navigate to profile
    }
}

func navigateInternally(to url: URL) {
    // Handle internal navigation
    NavigationManager.shared.navigate(to: url)
}
```

### Custom Image Loading

```swift
let context = SwiftUIRenderContext(
    imageHandler: { url in
        AnyView(
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                    )
            }
        )
    }
)

// Custom cached image implementation
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                content(image)
            case .failure(_):
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            case .empty:
                placeholder()
            @unknown default:
                placeholder()
            }
        }
    }
}
```

### Interactive Task Lists

```swift
struct InteractiveMarkdownView: View {
    @State private var taskStates: [String: Bool] = [:]
    
    var body: some View {
        MarkdownView(
            markdown: markdown,
            onTaskToggle: { taskId, isChecked in
                taskStates[taskId] = isChecked
                // Save to persistence layer
                saveTaskState(taskId, isChecked)
            }
        )
    }
}

// Note: Task list interactivity would require custom renderer extension
```

## Performance Optimization

### Lazy Loading for Large Documents

```swift
struct LazyMarkdownView: View {
    let markdownSections: [String]
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(markdownSections.indices, id: \.self) { index in
                MarkdownSectionView(markdown: markdownSections[index])
                    .id(index)
            }
        }
    }
}

struct MarkdownSectionView: View {
    let markdown: String
    @State private var renderedView: AnyView?
    
    var body: some View {
        Group {
            if let view = renderedView {
                view
            } else {
                ProgressView()
                    .frame(height: 100)
            }
        }
        .onAppear {
            Task {
                await renderSection()
            }
        }
    }
    
    private func renderSection() async {
        // Render only when section becomes visible
        let parser = SwiftMarkdownParser()
        let ast = try? await parser.parseToAST(markdown)
        let renderer = SwiftUIRenderer()
        let view = try? await renderer.render(document: ast!)
        
        await MainActor.run {
            self.renderedView = view
        }
    }
}
```

### Memory Management

```swift
struct EfficientMarkdownView: View {
    let markdown: String
    @State private var content: AnyView?
    @State private var task: Task<Void, Never>?
    
    var body: some View {
        Group {
            if let content = content {
                content
            } else {
                ProgressView()
            }
        }
        .onAppear {
            renderMarkdown()
        }
        .onDisappear {
            // Cancel rendering task if view disappears
            task?.cancel()
        }
    }
    
    private func renderMarkdown() {
        task = Task {
            do {
                let parser = SwiftMarkdownParser()
                let ast = try await parser.parseToAST(markdown)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                let renderer = SwiftUIRenderer()
                let view = try await renderer.render(document: ast)
                
                await MainActor.run {
                    self.content = view
                }
            } catch {
                await MainActor.run {
                    self.content = AnyView(Text("Failed to render"))
                }
            }
        }
    }
}
```

## Advanced Integration

### SwiftUI App Integration

```swift
import SwiftUI
import SwiftMarkdownParser

@main
struct MarkdownApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var documentStore = DocumentStore()
    
    var body: some View {
        NavigationSplitView {
            DocumentList(documents: documentStore.documents)
        } detail: { document in
            DocumentDetailView(document: document)
        }
    }
}

struct DocumentDetailView: View {
    let document: MarkdownDocument
    @Environment(\.colorScheme) var colorScheme
    
    private var styleConfig: SwiftUIStyleConfiguration {
        SwiftUIStyleConfiguration(
            bodyFont: .body,
            linkColor: colorScheme == .dark ? .blue : .blue,
            codeBackgroundColor: Color(.systemGray6)
        )
    }
    
    var body: some View {
        ScrollView {
            MarkdownView(
                markdown: document.content,
                styleConfiguration: styleConfig
            )
            .padding()
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.large)
    }
}
```

### Integration with Navigation

```swift
struct NavigableMarkdownView: View {
    let markdown: String
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            MarkdownView(
                markdown: markdown,
                context: SwiftUIRenderContext(
                    linkHandler: { url in
                        handleNavigation(url: url)
                    }
                )
            )
            .navigationDestination(for: String.self) { destination in
                DetailView(content: destination)
            }
        }
    }
    
    private func handleNavigation(url: URL) {
        if url.scheme == "internal" {
            navigationPath.append(url.absoluteString)
        } else {
            UIApplication.shared.open(url)
        }
    }
}
```

### Custom View Wrappers

```swift
struct StyledMarkdownView: View {
    let markdown: String
    let theme: MarkdownTheme
    
    var body: some View {
        MarkdownView(
            markdown: markdown,
            styleConfiguration: theme.styleConfiguration
        )
        .background(theme.backgroundColor)
        .cornerRadius(theme.cornerRadius)
        .shadow(radius: theme.shadowRadius)
    }
}

struct MarkdownTheme {
    let styleConfiguration: SwiftUIStyleConfiguration
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    static let paper = MarkdownTheme(
        styleConfiguration: SwiftUIStyleConfiguration(
            bodyFont: .system(.body, design: .serif),
            textColor: Color(.label),
            codeBackgroundColor: Color(.systemGray6)
        ),
        backgroundColor: Color(.systemBackground),
        cornerRadius: 12,
        shadowRadius: 2
    )
    
    static let code = MarkdownTheme(
        styleConfiguration: SwiftUIStyleConfiguration(
            bodyFont: .system(.body, design: .monospaced),
            textColor: Color(.label),
            codeBackgroundColor: Color(.systemGray5)
        ),
        backgroundColor: Color(.systemGray6),
        cornerRadius: 8,
        shadowRadius: 1
    )
}
```

## Error Handling

### Graceful Error Display

```swift
struct RobustMarkdownView: View {
    let markdown: String
    @State private var renderState: RenderState = .loading
    
    enum RenderState {
        case loading
        case success(AnyView)
        case failure(Error)
    }
    
    var body: some View {
        Group {
            switch renderState {
            case .loading:
                ProgressView("Rendering...")
                
            case .success(let view):
                view
                
            case .failure(let error):
                ErrorView(error: error) {
                    renderMarkdown()
                }
            }
        }
        .task {
            await renderMarkdown()
        }
    }
    
    private func renderMarkdown() async {
        do {
            let parser = SwiftMarkdownParser()
            let ast = try await parser.parseToAST(markdown)
            let renderer = SwiftUIRenderer()
            let view = try await renderer.render(document: ast)
            
            await MainActor.run {
                self.renderState = .success(view)
            }
        } catch {
            await MainActor.run {
                self.renderState = .failure(error)
            }
        }
    }
}

struct ErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Rendering Failed")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

## Platform Differences

### iOS-Specific Features

```swift
#if os(iOS)
struct iOSMarkdownView: View {
    let markdown: String
    
    var body: some View {
        MarkdownView(
            markdown: markdown,
            context: SwiftUIRenderContext(
                linkHandler: { url in
                    // iOS-specific link handling
                    let safariVC = SFSafariViewController(url: url)
                    UIApplication.shared.windows.first?.rootViewController?.present(safariVC, animated: true)
                }
            )
        )
        .refreshable {
            // Pull to refresh on iOS
            await refreshContent()
        }
    }
}
#endif
```

### macOS-Specific Features

```swift
#if os(macOS)
struct macOSMarkdownView: View {
    let markdown: String
    
    var body: some View {
        MarkdownView(
            markdown: markdown,
            context: SwiftUIRenderContext(
                linkHandler: { url in
                    // macOS-specific link handling
                    NSWorkspace.shared.open(url)
                }
            )
        )
        .frame(maxWidth: 800)  // Optimal reading width
        .background(Color(.windowBackgroundColor))
    }
}
#endif
```

## API Reference

### SwiftUIRenderer

```swift
@available(iOS 17.0, macOS 14.0, *)
public struct SwiftUIRenderer: MarkdownRenderer {
    public typealias Output = AnyView
    public let context: SwiftUIRenderContext
    
    public init(context: SwiftUIRenderContext = SwiftUIRenderContext())
    public func render(document: AST.DocumentNode) async throws -> AnyView
    public func render(node: ASTNode) async throws -> AnyView
}
```

### SwiftUIRenderContext

```swift
@available(iOS 17.0, macOS 14.0, *)
public struct SwiftUIRenderContext: Sendable {
    public let baseURL: URL?
    public let styleConfiguration: SwiftUIStyleConfiguration
    public let linkHandler: (@Sendable (URL) -> Void)?
    public let imageHandler: (@Sendable (URL) -> AnyView)?
    public let maxDepth: Int
    public let enableAccessibility: Bool
    
    public init(
        baseURL: URL? = nil,
        styleConfiguration: SwiftUIStyleConfiguration = SwiftUIStyleConfiguration(),
        linkHandler: (@Sendable (URL) -> Void)? = nil,
        imageHandler: (@Sendable (URL) -> AnyView)? = nil,
        maxDepth: Int = 50,
        enableAccessibility: Bool = true
    )
}
```

### SwiftUIStyleConfiguration

```swift
@available(iOS 17.0, macOS 14.0, *)
public struct SwiftUIStyleConfiguration: Sendable {
    // Typography
    public let bodyFont: Font
    public let codeFont: Font
    public let headingFonts: [Int: Font]
    
    // Colors
    public let textColor: Color
    public let headingColor: Color
    public let linkColor: Color
    public let codeTextColor: Color
    public let codeBackgroundColor: Color
    
    // Spacing
    public let documentSpacing: CGFloat
    public let paragraphSpacing: CGFloat
    public let listItemSpacing: CGFloat
    
    // And many more styling properties...
    
    public init(
        bodyFont: Font = .body,
        codeFont: Font = .system(.body, design: .monospaced),
        headingFonts: [Int: Font] = defaultHeadingFonts,
        textColor: Color = .primary,
        // ... other parameters
    )
}
```

### Supported Elements

All CommonMark and GFM elements are fully supported:

- **Text**: Basic text, emphasis, strong emphasis, strikethrough
- **Headings**: All 6 levels with automatic font scaling
- **Paragraphs**: With proper spacing and alignment
- **Lists**: Ordered and unordered, with nesting support
- **Code**: Inline code spans and code blocks
- **Links**: Clickable links with custom handlers
- **Images**: AsyncImage integration with custom loading
- **Tables**: Native SwiftUI table layouts
- **Task Lists**: Checkboxes with custom styling
- **Block Quotes**: Styled containers with borders
- **Thematic Breaks**: Dividers and separators

---

**Next Steps**: Check out the [Parser Usage Documentation](ParserUsage.md) for comprehensive AST manipulation and configuration options. 