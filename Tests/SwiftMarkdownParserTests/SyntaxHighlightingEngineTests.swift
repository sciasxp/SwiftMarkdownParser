import Testing
@testable import SwiftMarkdownParser

/// Test suite for syntax highlighting engines.
///
/// This test suite covers all syntax highlighting engines using Test-Driven Development (TDD).
/// Tests are written first, then implementations are created to pass the tests.
@Suite struct SyntaxHighlightingEngineTests {

    // MARK: - Core Protocol Tests

    @Test func syntaxHighlightingEngine_protocol_requirements() async throws {
        // Test that engines conform to protocol requirements
        let engines: [SyntaxHighlightingEngine] = [
            JavaScriptSyntaxEngine(),
            TypeScriptSyntaxEngine(),
            SwiftSyntaxEngine(),
            KotlinSyntaxEngine(),
            PythonSyntaxEngine(),
            BashSyntaxEngine()
        ]

        for engine in engines {
            // Each engine should support at least one language
            #expect(!engine.supportedLanguages().isEmpty, "Engine should support at least one language")

            // Each engine should be able to highlight empty code
            let emptyTokens = try await engine.highlight("", language: engine.supportedLanguages().first!)
            #expect(emptyTokens.isEmpty || emptyTokens.allSatisfy { $0.content.isEmpty })
        }
    }

    @Test func syntaxToken_equality() async throws {
        let token1 = SyntaxToken(content: "func", tokenType: .keyword, range: "func".startIndex..<"func".endIndex)
        let token2 = SyntaxToken(content: "func", tokenType: .keyword, range: "func".startIndex..<"func".endIndex)
        let token3 = SyntaxToken(content: "var", tokenType: .keyword, range: "var".startIndex..<"var".endIndex)

        #expect(token1 == token2)
        #expect(token1 != token3)
    }

    @Test func syntaxTokenType_allCases() async throws {
        // Ensure all token types are covered
        let expectedTypes: Set<SyntaxTokenType> = [
            .keyword, .string, .comment, .number, .identifier, .operator, .punctuation,
            .plain, .type, .function, .variable, .constant, .builtin, .attribute,
            .generic, .namespace, .property, .method, .parameter, .label, .escape,
            .interpolation, .regex, .template, .annotation, .modifier
        ]

        let actualTypes = Set(SyntaxTokenType.allCases)
        #expect(expectedTypes == actualTypes, "All token types should be defined")
    }

    // MARK: - Registry Tests

    @Test func syntaxHighlightingRegistry_initialization() async throws {
        let registry = SyntaxHighlightingRegistry()
        let supportedLanguages = await registry.supportedLanguages()

        // Should support all primary languages
        let expectedLanguages: Set<String> = [
            "javascript", "js", "jsx", "typescript", "ts", "tsx",
            "swift", "kotlin", "kt", "python", "py",
            "bash", "sh", "shell", "zsh"
        ]

        for language in expectedLanguages {
            #expect(supportedLanguages.contains(language), "Should support \(language)")
        }
    }

    @Test func syntaxHighlightingRegistry_engineRetrieval() async throws {
        let registry = SyntaxHighlightingRegistry()

        // Test engine retrieval for each language
        let testCases: [(String, SyntaxHighlightingEngine.Type)] = [
            ("javascript", JavaScriptSyntaxEngine.self),
            ("typescript", TypeScriptSyntaxEngine.self),
            ("swift", SwiftSyntaxEngine.self),
            ("kotlin", KotlinSyntaxEngine.self),
            ("python", PythonSyntaxEngine.self),
            ("bash", BashSyntaxEngine.self)
        ]

        for (language, expectedType) in testCases {
            let engine = await registry.engine(for: language)
            #expect(engine != nil, "Should have engine for \(language)")
            #expect(type(of: engine!) == expectedType, "Should return correct engine type for \(language)")
        }

        // Test unsupported language
        let unsupportedEngine = await registry.engine(for: "unsupported")
        #expect(unsupportedEngine == nil, "Should return nil for unsupported language")
    }

    // MARK: - Error Handling Tests

    @Test func syntaxHighlightingError_types() async throws {
        let errors: [SyntaxHighlightingError] = [
            .unsupportedLanguage("test"),
            .parsingError("test"),
            .cacheError("test"),
            .engineRegistrationError("test")
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "Error should have description")
        }
    }

    @Test func engine_unsupportedLanguage_throwsError() async throws {
        let engine = JavaScriptSyntaxEngine()

        let caughtError = await #expect(throws: SyntaxHighlightingError.self) {
            _ = try await engine.highlight("test", language: "unsupported")
        }
        if case .unsupportedLanguage(let language) = caughtError {
            #expect(language == "unsupported")
        } else {
            Issue.record("Should throw SyntaxHighlightingError.unsupportedLanguage, got \(String(describing: caughtError))")
        }
    }

    // MARK: - Edge Case Tests

    @Test func engines_handleEmptyStrings() async throws {
        let engines: [(SyntaxHighlightingEngine, String)] = [
            (SwiftSyntaxEngine(), "swift"),
            (PythonSyntaxEngine(), "python"),
            (JavaScriptSyntaxEngine(), "javascript"),
            (TypeScriptSyntaxEngine(), "typescript"),
            (KotlinSyntaxEngine(), "kotlin"),
            (BashSyntaxEngine(), "bash")
        ]

        for (engine, language) in engines {
            let tokens = try await engine.highlight("", language: language)
            #expect(tokens.isEmpty, "\(language) engine should handle empty strings")
        }
    }

    @Test func engines_handleVeryShortStrings() async throws {
        let engines: [(SyntaxHighlightingEngine, String)] = [
            (SwiftSyntaxEngine(), "swift"),
            (PythonSyntaxEngine(), "python"),
            (JavaScriptSyntaxEngine(), "javascript"),
            (TypeScriptSyntaxEngine(), "typescript"),
            (KotlinSyntaxEngine(), "kotlin"),
            (BashSyntaxEngine(), "bash")
        ]

        let testCases = ["a", "ab", "/", "//", "\"", "\"\"", "$", "/*", "*/", "@", "#"]

        for (engine, language) in engines {
            for testCase in testCases {
                do {
                    let tokens = try await engine.highlight(testCase, language: language)
                    // Should not crash and should return some tokens
                    #expect(tokens.count >= 0, "\(language) engine should handle '\(testCase)' without crashing")
                } catch {
                    Issue.record("\(language) engine should not throw error for '\(testCase)': \(error)")
                }
            }
        }
    }

    @Test func engines_handleSingleCharacterStrings() async throws {
        let engines: [(SyntaxHighlightingEngine, String)] = [
            (SwiftSyntaxEngine(), "swift"),
            (PythonSyntaxEngine(), "python"),
            (JavaScriptSyntaxEngine(), "javascript"),
            (TypeScriptSyntaxEngine(), "typescript"),
            (KotlinSyntaxEngine(), "kotlin"),
            (BashSyntaxEngine(), "bash")
        ]

        // Test single characters that could cause index out of bounds
        let singleChars = ["/", "*", "\"", "'", "$", "@", "#", "\\", "(", ")", "[", "]", "{", "}", ".", ",", ";", ":", "?", "!", "&", "|", "^", "~", "+", "-", "=", "<", ">", "%"]

        for (engine, language) in engines {
            for char in singleChars {
                do {
                    let tokens = try await engine.highlight(char, language: language)
                    #expect(tokens.count >= 0, "\(language) engine should handle single character '\(char)' without crashing")
                } catch {
                    Issue.record("\(language) engine should not throw error for single character '\(char)': \(error)")
                }
            }
        }
    }

    @Test func engines_handleUnclosedBlockComments() async throws {
        // Test for the specific bug where unclosed block comments extending to end of input
        // were incorrectly truncated by one character
        let testCases: [(SyntaxHighlightingEngine, String, String)] = [
            (KotlinSyntaxEngine(), "kotlin", "/* unclosed comment"),
            (KotlinSyntaxEngine(), "kotlin", "/* unclosed comment with more text"),
            (KotlinSyntaxEngine(), "kotlin", "/*a"),
            (TypeScriptSyntaxEngine(), "typescript", "/* unclosed comment"),
            (TypeScriptSyntaxEngine(), "typescript", "/* unclosed comment with more text"),
            (TypeScriptSyntaxEngine(), "typescript", "/*a"),
            (JavaScriptSyntaxEngine(), "javascript", "/* unclosed comment"),
            (SwiftSyntaxEngine(), "swift", "/* unclosed comment")
        ]

        for (engine, language, code) in testCases {
            do {
                let tokens = try await engine.highlight(code, language: language)

                // Find the comment token
                let commentTokens = tokens.filter { $0.tokenType == .comment }
                #expect(commentTokens.count == 1, "Should have exactly one comment token for '\(code)' in \(language)")

                if let commentToken = commentTokens.first {
                    // The comment token should include the entire input string
                    #expect(commentToken.content == code, "Comment token should include entire unclosed comment for '\(code)' in \(language)")
                }
            } catch {
                Issue.record("\(language) engine should not throw error for unclosed comment '\(code)': \(error)")
            }
        }
    }
}

// MARK: - JavaScript Engine Tests

extension SyntaxHighlightingEngineTests {

    @Test func javascriptEngine_highlightsKeywords() async throws {
        let engine = JavaScriptSyntaxEngine()
        let code = "function test() { const x = 42; }"
        let tokens = try await engine.highlight(code, language: "javascript")

        #expect(tokens.contains { $0.content == "function" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "const" && $0.tokenType == .keyword })
    }

    @Test func javascriptEngine_highlightsES6Features() async throws {
        let engine = JavaScriptSyntaxEngine()
        let code = "const arrow = (x) => x * 2;"
        let tokens = try await engine.highlight(code, language: "javascript")

        #expect(tokens.contains { $0.content == "const" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "=>" && $0.tokenType == .`operator` })
    }

    @Test func javascriptEngine_highlightsTemplateLiterals() async throws {
        let engine = JavaScriptSyntaxEngine()
        let code = "const msg = `Hello ${name}`;"
        let tokens = try await engine.highlight(code, language: "javascript")

        let templateTokens = tokens.filter { $0.tokenType == .template }
        let interpolationTokens = tokens.filter { $0.tokenType == .interpolation }

        #expect(!templateTokens.isEmpty, "Should have template tokens")
        #expect(!interpolationTokens.isEmpty, "Should have interpolation tokens")
    }

    @Test func javascriptEngine_highlightsAsyncAwait() async throws {
        let engine = JavaScriptSyntaxEngine()
        let code = "async function fetch() { await api.get(); }"
        let tokens = try await engine.highlight(code, language: "javascript")

        #expect(tokens.contains { $0.content == "async" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "await" && $0.tokenType == .keyword })
    }

    @Test func javascriptEngine_highlightsJSX() async throws {
        let engine = JavaScriptSyntaxEngine()
        let code = "const element = <div className='test'>{content}</div>;"
        let tokens = try await engine.highlight(code, language: "jsx")

        #expect(tokens.contains { $0.content == "className" && $0.tokenType == .attribute })
        #expect(tokens.contains { $0.content == "div" && $0.tokenType == .type })
    }
}

// MARK: - TypeScript Engine Tests

extension SyntaxHighlightingEngineTests {

    @Test func typescriptEngine_highlightsTypeAnnotations() async throws {
        let engine = TypeScriptSyntaxEngine()
        let code = "function greet(name: string): void {}"
        let tokens = try await engine.highlight(code, language: "typescript")

        #expect(tokens.contains { $0.content == "string" && $0.tokenType == .type })
        #expect(tokens.contains { $0.content == "void" && $0.tokenType == .type })
    }

    @Test func typescriptEngine_highlightsGenerics() async throws {
        let engine = TypeScriptSyntaxEngine()
        let code = "function identity<T>(arg: T): T { return arg; }"
        let tokens = try await engine.highlight(code, language: "typescript")

        #expect(tokens.contains { $0.content == "T" && $0.tokenType == .generic })
    }

    @Test func typescriptEngine_highlightsInterfaces() async throws {
        let engine = TypeScriptSyntaxEngine()
        let code = "interface User { name: string; age?: number; }"
        let tokens = try await engine.highlight(code, language: "typescript")

        #expect(tokens.contains { $0.content == "interface" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "User" && $0.tokenType == .type })
    }

    @Test func typescriptEngine_highlightsDecorators() async throws {
        let engine = TypeScriptSyntaxEngine()
        let code = "@Component({ selector: 'app' }) class App {}"
        let tokens = try await engine.highlight(code, language: "typescript")

        #expect(tokens.contains { $0.content == "@Component" && $0.tokenType == .attribute })
    }
}

// MARK: - Swift Engine Tests

extension SyntaxHighlightingEngineTests {

    @Test func swiftEngine_highlightsModernSyntax() async throws {
        let engine = SwiftSyntaxEngine()
        let code = "func greet(name: String) async throws -> String {}"
        let tokens = try await engine.highlight(code, language: "swift")

        #expect(tokens.contains { $0.content == "func" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "async" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "throws" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "String" && $0.tokenType == .type })
    }

    @Test func swiftEngine_highlightsPropertyWrappers() async throws {
        let engine = SwiftSyntaxEngine()
        let code = "@State private var count: Int = 0"
        let tokens = try await engine.highlight(code, language: "swift")

        #expect(tokens.contains { $0.content == "@State" && $0.tokenType == .attribute })
        #expect(tokens.contains { $0.content == "private" && $0.tokenType == .modifier })
        #expect(tokens.contains { $0.content == "var" && $0.tokenType == .keyword })
    }

    @Test func swiftEngine_highlightsStringInterpolation() async throws {
        let engine = SwiftSyntaxEngine()
        let code = "let message = \"Hello \\(name)\""
        let tokens = try await engine.highlight(code, language: "swift")

        let interpolationTokens = tokens.filter { $0.tokenType == .interpolation }
        #expect(!interpolationTokens.isEmpty, "Should have interpolation tokens")
    }

    @Test func swiftEngine_highlightsClosures() async throws {
        let engine = SwiftSyntaxEngine()
        let code = "let numbers = [1, 2, 3].map { $0 * 2 }"
        let tokens = try await engine.highlight(code, language: "swift")

        #expect(tokens.contains { $0.content == "$0" && $0.tokenType == .parameter })
        #expect(tokens.contains { $0.content == "map" && $0.tokenType == .method })
    }
}

// MARK: - Kotlin Engine Tests

extension SyntaxHighlightingEngineTests {

    @Test func kotlinEngine_highlightsDataClasses() async throws {
        let engine = KotlinSyntaxEngine()
        let code = "data class User(val name: String, var age: Int)"
        let tokens = try await engine.highlight(code, language: "kotlin")

        #expect(tokens.contains { $0.content == "data" && $0.tokenType == .modifier })
        #expect(tokens.contains { $0.content == "class" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "val" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "var" && $0.tokenType == .keyword })
    }

    @Test func kotlinEngine_highlightsExtensionFunctions() async throws {
        let engine = KotlinSyntaxEngine()
        let code = "fun String.isEmail(): Boolean = this.contains('@')"
        let tokens = try await engine.highlight(code, language: "kotlin")

        #expect(tokens.contains { $0.content == "fun" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "String" && $0.tokenType == .type })
        #expect(tokens.contains { $0.content == "Boolean" && $0.tokenType == .type })
    }

    @Test func kotlinEngine_highlightsCoroutines() async throws {
        let engine = KotlinSyntaxEngine()
        let code = "suspend fun fetch(): String = withContext(Dispatchers.IO) {}"
        let tokens = try await engine.highlight(code, language: "kotlin")

        #expect(tokens.contains { $0.content == "suspend" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "withContext" && $0.tokenType == .function })
    }

    @Test func kotlinEngine_highlightsNullSafety() async throws {
        let engine = KotlinSyntaxEngine()
        let code = "val name: String? = user?.name ?: \"Unknown\""
        let tokens = try await engine.highlight(code, language: "kotlin")

        #expect(tokens.contains { $0.content == "?" && $0.tokenType == .`operator` })
        #expect(tokens.contains { $0.content == "?:" && $0.tokenType == .`operator` })
    }
}

// MARK: - Python Engine Tests

extension SyntaxHighlightingEngineTests {

    @Test func pythonEngine_highlightsKeywords() async throws {
        let engine = PythonSyntaxEngine()
        let code = "def function(): pass"
        let tokens = try await engine.highlight(code, language: "python")

        #expect(tokens.contains { $0.content == "def" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "pass" && $0.tokenType == .keyword })
    }

    @Test func pythonEngine_highlightsStrings() async throws {
        let engine = PythonSyntaxEngine()
        let code = "print('Hello \"World\"')"
        let tokens = try await engine.highlight(code, language: "python")

        let stringToken = tokens.first { $0.tokenType == .string }
        #expect(stringToken != nil)
    }

    @Test func pythonEngine_highlightsBuiltins() async throws {
        let engine = PythonSyntaxEngine()
        let code = "print(len(range(10)))"
        let tokens = try await engine.highlight(code, language: "python")

        #expect(tokens.contains { $0.content == "print" && $0.tokenType == .builtin })
        #expect(tokens.contains { $0.content == "len" && $0.tokenType == .builtin })
        #expect(tokens.contains { $0.content == "range" && $0.tokenType == .builtin })
    }

    @Test func pythonEngine_highlightsAsyncAwait() async throws {
        let engine = PythonSyntaxEngine()
        let code = "async def fetch(): await api.get()"
        let tokens = try await engine.highlight(code, language: "python")

        #expect(tokens.contains { $0.content == "async" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "await" && $0.tokenType == .keyword })
    }
}

// MARK: - Bash Engine Tests

extension SyntaxHighlightingEngineTests {

    @Test func bashEngine_highlightsShebang() async throws {
        let engine = BashSyntaxEngine()
        let code = "#!/bin/bash\necho 'Hello'"
        let tokens = try await engine.highlight(code, language: "bash")

        #expect(tokens.contains { $0.content == "#!/bin/bash" && $0.tokenType == .comment })
    }

    @Test func bashEngine_highlightsCommands() async throws {
        let engine = BashSyntaxEngine()
        let code = "ls -la\ngrep 'pattern' file.txt"
        let tokens = try await engine.highlight(code, language: "bash")

        #expect(tokens.contains { $0.content == "ls" && $0.tokenType == .builtin })
        #expect(tokens.contains { $0.content == "grep" && $0.tokenType == .builtin })
    }

    @Test func bashEngine_highlightsVariables() async throws {
        let engine = BashSyntaxEngine()
        let code = "NAME='John'\necho $NAME"
        let tokens = try await engine.highlight(code, language: "bash")

        #expect(tokens.contains { $0.content == "$NAME" && $0.tokenType == .variable })
    }

    @Test func bashEngine_highlightsControlStructures() async throws {
        let engine = BashSyntaxEngine()
        let code = "if [ $? -eq 0 ]; then echo 'success'; fi"
        let tokens = try await engine.highlight(code, language: "bash")

        #expect(tokens.contains { $0.content == "if" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "then" && $0.tokenType == .keyword })
        #expect(tokens.contains { $0.content == "fi" && $0.tokenType == .keyword })
    }
}
