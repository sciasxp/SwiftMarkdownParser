# Syntax Highlighting Guide

SwiftMarkdownParser includes semantic syntax highlighting for HTML code blocks
through one actor-isolated module.

## 🌟 Features

- **6 Programming Languages**: JavaScript, TypeScript, Swift, Kotlin, Python, Bash
- **25+ Token Types**: Keywords, strings, comments, operators, types, functions, and more
- **Modern Language Features**: ES6+, async/await, generics, coroutines, decorators
- **Truthful Discovery**: Supported identifiers come directly from six built-in adapters
- **Bounded Reuse**: Selection, fallback, token validation, and LRU caching share one owner
- **Thread-Safe**: Built with Swift 6 concurrency patterns
- **HTML Renderer**: Escaped semantic spans with caller-configurable CSS classes
- **SwiftUI Renderer**: Basic code blocks with monospace styling (no syntax highlighting)

## 🚀 Quick Start

### Basic HTML Rendering with Syntax Highlighting

````swift
import SwiftMarkdownParser

let codeMarkdown = """
# Code Example

```swift
@State private var count: Int = 0

func increment() async {
    await MainActor.run {
        count += 1
    }
}
```
"""

// Configure syntax highlighting
let context = HTMLRenderOptions(
    styleConfiguration: HTMLStyleConfiguration(
        syntaxHighlighting: HTMLSyntaxHighlightingOptions(
            enabled: true,
            cssPrefix: "hljs-"       // optional; default is "language-"
        )
    )
)

let parser = SwiftMarkdownParser()
let ast = try parser.parse(codeMarkdown)

let renderer = HTMLRenderer(options: context)
let highlightedHTML = try await renderer.renderFragment(ast)
````

### SwiftUI Integration (Basic Code Blocks Only)

**Note**: SwiftUI renderer does NOT support syntax highlighting. It only renders plain monospace code blocks.

```swift
import SwiftUI
import SwiftMarkdownParser

struct CodeExampleView: View {
    let markdown = """
    ```python
    async def fetch_data():
        response = await http.get('/api/data')
        return await response.json()
    ```
    """

    var body: some View {
        ScrollView {
            MarkdownView(markdown: markdown)
                .padding()
        }
    }
}

struct MarkdownView: View {
    let markdown: String
    @State private var renderedView: AnyView?

    var body: some View {
        Group {
            if let view = renderedView {
                view
            } else {
                ProgressView("Rendering...")
            }
        }
        .task {
            await renderMarkdown()
        }
    }

    @MainActor
    private func renderMarkdown() async {
        do {
            let parser = SwiftMarkdownParser()
            let ast = try parser.parse(markdown)

            // Use a predefined SwiftUI style - NO syntax highlighting available
            let context = SwiftUIRenderOptions(
                styleConfiguration: SwiftUIStyleConfiguration.github
            )

            let renderer = SwiftUIRenderer(options: context)
            self.renderedView = try await renderer.render(ast)
        } catch {
            self.renderedView = AnyView(Text("Error: \(error.localizedDescription)"))
        }
    }
}
```

## 📋 Supported Languages

Language identifiers are trimmed and matched case-insensitively. Discovery is
available through `await SyntaxHighlighter().supportedLanguages`.

| Language | Accepted identifiers |
| --- | --- |
| JavaScript | `javascript`, `js`, `jsx` |
| TypeScript | `typescript`, `ts`, `tsx` |
| Swift | `swift` |
| Kotlin | `kotlin`, `kt` |
| Python | `python`, `py` |
| Bash | `bash`, `sh`, `shell`, `zsh` |

### JavaScript
- **ES6+ Features**: Arrow functions, destructuring, template literals
- **Modern Syntax**: async/await, classes, modules
- **JSX Support**: React component syntax
- **Template Literals**: String interpolation with `${}`

```javascript
const fetchUser = async (id) => {
    const response = await fetch(`/api/users/${id}`);
    return await response.json();
};

const UserComponent = ({ user }) => (
    <div className="user-card">
        <h2>{user.name}</h2>
        <p>{user.email}</p>
    </div>
);
```

### TypeScript
- **Type Annotations**: Parameters, return types, variables
- **Generics**: Type parameters and constraints
- **Interfaces**: Object type definitions
- **Decorators**: Class and method decorators
- **TSX Support**: TypeScript + JSX

```typescript
interface User {
    id: number;
    name: string;
    email?: string;
}

@Component({
    selector: 'user-list'
})
class UserList<T extends User> {
    users: T[] = [];

    async loadUsers(): Promise<void> {
        this.users = await this.userService.getUsers<T>();
    }
}
```

### Swift
- **Swift 6 Syntax**: Latest language features
- **Property Wrappers**: @State, @Binding, @Published
- **String Interpolation**: \(expression) syntax
- **Async/Await**: Modern concurrency
- **Closures**: Including shorthand syntax ($0, $1)

```swift
@State private var users: [User] = []
@Published var isLoading = false

func loadUsers() async throws {
    let response = try await URLSession.shared.data(from: url)
    users = try JSONDecoder().decode([User].self, from: response.0)
}

let sorted = users.sorted { $0.name < $1.name }
```

### Kotlin
- **Data Classes**: Automatic implementations
- **Coroutines**: suspend functions, async/await
- **Null Safety**: ? and ?: operators
- **Extension Functions**: Adding methods to existing types

```kotlin
data class User(val name: String, var age: Int)

suspend fun fetchUser(id: String): User? = withContext(Dispatchers.IO) {
    val response = httpClient.get("/api/users/$id")
    response.body<User>()
}

fun String.isEmail(): Boolean = this.contains('@')
```

### Python
- **Python 3+ Syntax**: Modern Python features
- **Async/Await**: Asynchronous programming
- **Triple-quoted Strings**: Multi-line strings
- **List Comprehensions**: Functional programming constructs
- **Type Hints**: Optional type annotations

```python
from typing import List, Optional

async def fetch_users() -> List[User]:
    async with aiohttp.ClientSession() as session:
        async with session.get('/api/users') as response:
            return await response.json()

users = [user for user in all_users if user.age >= 18]
```

### Bash
- **Shell Scripts**: Complete bash syntax
- **Variables**: $VAR and ${VAR} syntax
- **Control Structures**: if/then/fi, for/do/done
- **Built-in Commands**: Common shell utilities
- **Shebang**: #!/bin/bash detection

```bash
#!/bin/bash

USER_COUNT=$(wc -l < users.txt)

if [ $USER_COUNT -gt 100 ]; then
    echo "Many users: $USER_COUNT"
    for user in $(cat users.txt); do
        echo "Processing: $user"
    done
fi
```

## 🎨 Theme Values

`SyntaxHighlightingTheme` provides GitHub, Xcode, and VS Code Dark color
palettes for caller-owned presentation. `HTMLRenderer` emits semantic CSS
classes and does not select one of these palettes automatically. Supply CSS for
the configured prefix when a particular visual theme is required.

### GitHub Theme
Clean, professional styling matching GitHub's code blocks:
- **Background**: Light gray (#f6f8fa)
- **Keywords**: Deep red (#d73a49)
- **Strings**: Dark blue (#032f62)
- **Comments**: Gray (#6a737d)

### Xcode Theme
Apple's development environment colors:
- **Background**: White
- **Keywords**: Purple (#aa0d91)
- **Strings**: Red (#c41a16)
- **Comments**: Green (#008400)

### VS Code Dark Theme
Popular dark theme for developers:
- **Background**: Dark gray (#1e1e1e)
- **Keywords**: Light blue (#4fc3f7)
- **Strings**: Orange (#ce9178)
- **Comments**: Green (#6a9955)

## 🛠️ Configuration

### HTML Renderer Configuration

```swift
let syntaxConfig = HTMLSyntaxHighlightingOptions(
    enabled: true,
    cssPrefix: "hljs-"   // optional; default is "language-"
)

let context = HTMLRenderOptions(
    styleConfiguration: HTMLStyleConfiguration(
        syntaxHighlighting: syntaxConfig
    )
)
```

### SwiftUI Renderer Configuration

**Note**: SwiftUI renderer does not support syntax highlighting. Only basic styling is available.

```swift
let context = SwiftUIRenderOptions(
    styleConfiguration: SwiftUIStyleConfiguration(
        // Only basic code styling - no syntax highlighting
        codeFont: .system(.body, design: .monospaced),
        codeTextColor: .primary,
        codeBackgroundColor: Color.gray.opacity(0.1),
        codeCornerRadius: 8.0
    )
)
```

## 🎨 Custom Token CSS

### Styling HTML Tokens

```swift
// Custom CSS classes for HTML output
let context = HTMLRenderOptions(
    styleConfiguration: HTMLStyleConfiguration(
        syntaxHighlighting: HTMLSyntaxHighlightingOptions(
            enabled: true,
            cssPrefix: "custom-"
        ),
        cssClasses: [
            .codeBlock: "my-code-block"
        ]
    )
)

// Then provide your own CSS rules:
// .custom-keyword { color: #0066cc; }
// .custom-string { color: #009900; }
// .custom-comment { color: #888888; }
```

### SwiftUI Basic Styling

```swift
// Only basic styling available for SwiftUI
let customStyle = SwiftUIStyleConfiguration(
    codeFont: .system(.footnote, design: .monospaced),
    codeTextColor: Color.blue,
    codeBackgroundColor: Color.gray.opacity(0.05),
    codeCornerRadius: 4.0
)

let context = SwiftUIRenderOptions(styleConfiguration: customStyle)
```

### Token Color Mapping

The syntax highlighting system supports 25+ token types:

| Token Type | Description | Example |
|------------|-------------|---------|
| `.keyword` | Language keywords | `func`, `class`, `if`, `async` |
| `.string` | String literals | `"Hello"`, `'world'` |
| `.comment` | Comments | `// comment`, `/* block */` |
| `.number` | Numeric literals | `42`, `3.14`, `0xFF` |
| `.identifier` | Variable names | `userName`, `count` |
| `.operator` | Operators | `+`, `-`, `==`, `&&` |
| `.punctuation` | Punctuation | `(`, `)`, `{`, `}`, `;` |
| `.type` | Type names | `String`, `Int`, `User` |
| `.function` | Function names | `print`, `map`, `filter` |
| `.builtin` | Built-in functions | `console.log`, `len`, `echo` |
| `.constant` | Constants | `true`, `false`, `null` |
| `.attribute` | Attributes/decorators | `@State`, `@Component` |
| `.generic` | Generic parameters | `<T>`, `<K, V>` |
| `.method` | Method calls | `user.getName()` |
| `.property` | Object properties | `user.name` |
| `.parameter` | Function parameters | `$0`, `$1` |
| `.modifier` | Access modifiers | `public`, `private` |
| `.template` | Template literals | `` `Hello ${name}` `` |
| `.interpolation` | String interpolation | `${name}`, `\(value)` |
| `.regex` | Regular expressions | `/pattern/flags` |
| `.escape` | Escape sequences | `\n`, `\t`, `\"` |

## ⚡ Performance

### Highlighting Module

`SyntaxHighlighter` is the public semantic interface. Its supported-language
set is derived from installed adapters, and its bounded cache is automatic:

```swift
let highlighter = SyntaxHighlighter()
let supportedLanguages = await highlighter.supportedLanguages

if let tokens = await highlighter.highlight(
    "let answer = 42",
    language: "swift"
) {
    // Every token range belongs to the exact source string passed above.
    print(tokens)
}
```

### Performance Features

- **LRU Cache**: Bounded least-recently-used eviction owned by each highlighter
- **Actor-based**: Thread-safe concurrent access
- **Best-effort Fallback**: Unsupported languages or adapter failures return `nil`
- **Validated Results**: Tokens are sorted, non-overlapping, and tied to the supplied source
- **Portable Cache Entries**: Cached offsets are rebound to the current source string

**Note**: SwiftUI renderer performance is simpler as it doesn't perform syntax highlighting.

## 🔧 Advanced Usage

### Direct Semantic Highlighting

```swift
let highlighter = SyntaxHighlighter()
let tokens = await highlighter.highlight(
    "const x = 42;",
    language: "javascript"
)

for token in tokens ?? [] {
    print("\(token.content): \(token.tokenType)")
}
```

The six language adapters are implementation details. This keeps aliases,
support discovery, fallback, and caching behind the same interface.

Caller-registered language engines are intentionally not part of the public
interface. Package contributors add a built-in language through an internal
adapter plus module and HTML integration tests.

### Error Handling

```swift
let highlighter = SyntaxHighlighter()
if let tokens = await highlighter.highlight(code, language: "swift") {
    consume(tokens)
} else {
    consumePlainText(code)
}
```

## 🧪 Testing

### Unit Tests

The syntax highlighting system includes comprehensive tests:

```bash
# Run all syntax highlighting tests
swift test --filter SyntaxHighlightingEngineTests
swift test --filter SyntaxHighlighterTests

# Run specific language tests
swift test --filter swiftEngine
swift test --filter javascriptEngine

# Run integration tests (HTML renderer)
swift test --filter SyntaxHighlightingIntegrationTests
```

### Test Coverage

- **Engine Tests**: Each language engine has dedicated tests
- **Theme Tests**: Caller-owned semantic color palettes
- **Module Tests**: Support truth, aliases, fallback, validation, and LRU behavior
- **Integration Tests**: Cache reuse and gap-preserving HTML token assembly
- **Edge Cases**: Malformed code, empty blocks, special characters

## 📚 Examples

### Complete HTML Example with Syntax Highlighting

````swift
import SwiftMarkdownParser

let multiLanguageMarkdown = """
# Multi-language Code Examples

## Frontend (TypeScript + React)
```typescript
interface User {
    id: number;
    name: string;
    email: string;
}

const UserCard: React.FC<{ user: User }> = ({ user }) => (
    <div className="user-card">
        <h3>{user.name}</h3>
        <p>{user.email}</p>
    </div>
);
```

## Backend (Swift)
```swift
struct User: Codable {
    let id: Int
    let name: String
    let email: String
}

@main
struct App {
    static func main() async throws {
        let users = try await UserService.fetchUsers()
        print("Loaded \(users.count) users")
    }
}
```
"""

async func generateHighlightedHTML() throws -> String {
    let parser = SwiftMarkdownParser()
    let ast = try parser.parse(multiLanguageMarkdown)

    let context = HTMLRenderOptions(
        styleConfiguration: HTMLStyleConfiguration(
            syntaxHighlighting: HTMLSyntaxHighlightingOptions(
                enabled: true,
                cssPrefix: "hljs-"
            ),
            cssClasses: [
                .codeBlock: "code-block highlighted",
                .heading: "section-heading"
            ]
        )
    )

    let renderer = HTMLRenderer(options: context)
    return try await renderer.renderFragment(ast)
}

// Usage
let html = try await generateHighlightedHTML()
print(html)
````

### SwiftUI Example (Basic Code Blocks)

```swift
import SwiftUI
import SwiftMarkdownParser

struct SwiftUICodeExample: View {
    let codeMarkdown = """
    ```swift
    let message = "Hello, World!"
    print(message)
    ```
    """

    @State private var renderedView: AnyView?

    var body: some View {
        VStack {
            if let view = renderedView {
                view
            } else {
                ProgressView("Rendering...")
            }
        }
        .task {
            await renderCode()
        }
    }

    @MainActor
    private func renderCode() async {
        do {
            let parser = SwiftMarkdownParser()
            let ast = try parser.parse(codeMarkdown)

            // SwiftUI basic styling - no syntax highlighting
            let context = SwiftUIRenderOptions(
                styleConfiguration: SwiftUIStyleConfiguration(
                    codeFont: .system(.body, design: .monospaced),
                    codeTextColor: .primary,
                    codeBackgroundColor: Color.gray.opacity(0.1)
                )
            )

            let renderer = SwiftUIRenderer(options: context)
            self.renderedView = try await renderer.render(ast)
        } catch {
            self.renderedView = AnyView(Text("Error: \(error.localizedDescription)"))
        }
    }
}
```

## 📋 Renderer Comparison

| Feature | HTML Renderer | SwiftUI Renderer |
|---------|---------------|------------------|
| Syntax Highlighting | ✅ Full support | ❌ Not supported |
| Themes | Caller CSS via semantic classes | Basic styling only |
| Token-level styling | ✅ 25+ token types | ❌ Plain text only |
| Custom CSS classes | ✅ Configurable | ❌ N/A |
| Performance | ✅ Cached highlighting | ✅ Simple rendering |
| Use case | Web/HTML output | Native iOS/macOS apps |

---

The HTML renderer provides cached semantic highlighting for its six built-in
languages. SwiftUI output continues to use plain monospace code blocks.

See [Architecture](Architecture.md) for module ownership and the separation
between semantic classification and HTML presentation.
