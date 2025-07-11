import Foundation

public struct BashSyntaxEngine: SyntaxHighlightingEngine {
    
    public init() {}
    
    public func highlight(_ code: String, language: String) async throws -> [SyntaxToken] {
        guard supportedLanguages().contains(language.lowercased()) else {
            throw SyntaxHighlightingError.unsupportedLanguage(language)
        }
        
        return try await tokenize(code)
    }
    
    public func supportedLanguages() -> Set<String> {
        return Set(["bash", "sh", "shell", "zsh"])
    }
    
    private func tokenize(_ code: String) async throws -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var currentIndex = code.startIndex
        
        while currentIndex < code.endIndex {
            let char = code[currentIndex]
            
            // Skip whitespace
            if char.isWhitespace {
                currentIndex = code.index(after: currentIndex)
                continue
            }
            
            // Comments and shebang
            if char == "#" {
                if let token = try parseComment(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Variables
            if char == "$" {
                if let token = try parseVariable(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Strings
            if char == "\"" || char == "'" {
                if let token = try parseString(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Numbers
            if char.isNumber {
                if let token = try parseNumber(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Identifiers and keywords
            if char.isLetter || char == "_" {
                if let token = try parseIdentifier(code, startIndex: currentIndex) {
                    tokens.append(token)
                    currentIndex = token.range.upperBound
                    continue
                }
            }
            
            // Operators and punctuation
            if let token = try parseOperatorOrPunctuation(code, startIndex: currentIndex) {
                tokens.append(token)
                currentIndex = token.range.upperBound
                continue
            }
            
            // Fallback: single character as plain text
            let endIndex = code.index(after: currentIndex)
            let content = String(code[currentIndex..<endIndex])
            tokens.append(SyntaxToken(content: content, tokenType: .plain, range: currentIndex..<endIndex))
            currentIndex = endIndex
        }
        
        return tokens
    }
    
    // MARK: - Parsing Methods
    
    private func parseComment(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex] == "#" else { return nil }
        
        // Check for shebang
        if startIndex == code.startIndex {
            let remainingString = String(code[startIndex...])
            if remainingString.hasPrefix("#!") {
                var endIndex = startIndex
                while endIndex < code.endIndex && code[endIndex] != "\n" {
                    endIndex = code.index(after: endIndex)
                }
                
                let content = String(code[startIndex..<endIndex])
                return SyntaxToken(content: content, tokenType: .comment, range: startIndex..<endIndex)
            }
        }
        
        // Regular comment
        var endIndex = startIndex
        while endIndex < code.endIndex && code[endIndex] != "\n" {
            endIndex = code.index(after: endIndex)
        }
        
        let content = String(code[startIndex..<endIndex])
        return SyntaxToken(content: content, tokenType: .comment, range: startIndex..<endIndex)
    }
    
    private func parseVariable(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex] == "$" else { return nil }
        
        var currentIndex = code.index(after: startIndex)
        
        // Handle ${variable} syntax
        if currentIndex < code.endIndex && code[currentIndex] == "{" {
            currentIndex = code.index(after: currentIndex)
            while currentIndex < code.endIndex && code[currentIndex] != "}" {
                currentIndex = code.index(after: currentIndex)
            }
            if currentIndex < code.endIndex {
                currentIndex = code.index(after: currentIndex) // Include closing brace
            }
        } else {
            // Handle $variable syntax
            while currentIndex < code.endIndex && (code[currentIndex].isLetter || code[currentIndex].isNumber || code[currentIndex] == "_") {
                currentIndex = code.index(after: currentIndex)
            }
        }
        
        let content = String(code[startIndex..<currentIndex])
        return SyntaxToken(content: content, tokenType: .variable, range: startIndex..<currentIndex)
    }
    
    private func parseString(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex else { return nil }
        
        let quoteChar = code[startIndex]
        guard quoteChar == "\"" || quoteChar == "'" else { return nil }
        
        var currentIndex = code.index(after: startIndex)
        while currentIndex < code.endIndex {
            let char = code[currentIndex]
            if char == quoteChar {
                currentIndex = code.index(after: currentIndex)
                break
            }
            if char == "\\" && currentIndex < code.index(before: code.endIndex) {
                currentIndex = code.index(after: currentIndex)
            }
            currentIndex = code.index(after: currentIndex)
        }
        
        let content = String(code[startIndex..<currentIndex])
        return SyntaxToken(content: content, tokenType: .string, range: startIndex..<currentIndex)
    }
    
    private func parseNumber(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && code[startIndex].isNumber else { return nil }
        
        var currentIndex = startIndex
        
        // Regular numbers
        while currentIndex < code.endIndex && (code[currentIndex].isNumber || code[currentIndex] == ".") {
            currentIndex = code.index(after: currentIndex)
        }
        
        let content = String(code[startIndex..<currentIndex])
        return SyntaxToken(content: content, tokenType: .number, range: startIndex..<currentIndex)
    }
    
    private func parseIdentifier(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex && (code[startIndex].isLetter || code[startIndex] == "_") else { return nil }
        
        var currentIndex = startIndex
        while currentIndex < code.endIndex && (code[currentIndex].isLetter || code[currentIndex].isNumber || code[currentIndex] == "_" || code[currentIndex] == "-") {
            currentIndex = code.index(after: currentIndex)
        }
        
        let content = String(code[startIndex..<currentIndex])
        let tokenType = classifyIdentifier(content)
        
        return SyntaxToken(content: content, tokenType: tokenType, range: startIndex..<currentIndex)
    }
    
    private func parseOperatorOrPunctuation(_ code: String, startIndex: String.Index) throws -> SyntaxToken? {
        guard startIndex < code.endIndex else { return nil }
        
        let remainingString = String(code[startIndex...])
        
        // Multi-character operators (check longer ones first)
        let multiCharOperators = ["==", "!=", "<=", ">=", "&&", "||", "<<", ">>", "2>", "2>&1", "&>", ">>", "<<"]
        for op in multiCharOperators {
            if remainingString.hasPrefix(op) {
                let endIndex = code.index(startIndex, offsetBy: op.count)
                return SyntaxToken(content: op, tokenType: .`operator`, range: startIndex..<endIndex)
            }
        }
        
        // Single character operators
        let singleCharOperators: Set<Character> = ["+", "-", "*", "/", "%", "=", "!", "<", ">", "&", "|", "^", "~", "?", ":"]
        if singleCharOperators.contains(code[startIndex]) {
            let content = String(code[startIndex])
            let endIndex = code.index(after: startIndex)
            return SyntaxToken(content: content, tokenType: .`operator`, range: startIndex..<endIndex)
        }
        
        // Punctuation
        let punctuation: Set<Character> = ["(", ")", "[", "]", "{", "}", ",", ";", ".", "@", "`"]
        if punctuation.contains(code[startIndex]) {
            let content = String(code[startIndex])
            let endIndex = code.index(after: startIndex)
            return SyntaxToken(content: content, tokenType: .punctuation, range: startIndex..<endIndex)
        }
        
        return nil
    }
    
    private func classifyIdentifier(_ content: String) -> SyntaxTokenType {
        // Keywords
        if bashKeywords.contains(content) {
            return .keyword
        }
        
        // Built-in commands
        if bashBuiltins.contains(content) {
            return .builtin
        }
        
        // Common commands
        if bashCommands.contains(content) {
            return .builtin
        }
        
        return .identifier
    }
    
    // MARK: - Bash Language Definitions
    
    private let bashKeywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do", "done",
        "in", "function", "select", "time", "coproc", "local", "readonly", "export", "unset",
        "declare", "typeset", "alias", "unalias", "set", "unset", "shift", "break", "continue",
        "return", "exit", "trap", "wait", "exec", "eval", "source", "builtin", "command",
        "enable", "help", "let", "mapfile", "printf", "read", "readarray", "type", "ulimit",
        "umask", "hash", "history", "fc", "jobs", "bg", "fg", "disown", "suspend", "kill",
        "killall", "nohup", "timeout", "test", "true", "false"
    ]
    
    private let bashBuiltins: Set<String> = [
        "echo", "printf", "read", "cd", "pwd", "pushd", "popd", "dirs", "which", "type",
        "alias", "unalias", "history", "fc", "jobs", "bg", "fg", "disown", "suspend",
        "kill", "killall", "nohup", "timeout", "wait", "sleep", "usleep", "exec", "eval",
        "source", ".", "builtin", "command", "enable", "help", "let", "mapfile", "printf",
        "read", "readarray", "type", "ulimit", "umask", "hash", "set", "unset", "shift",
        "export", "declare", "typeset", "local", "readonly", "getopts", "basename", "dirname"
    ]
    
    private let bashCommands: Set<String> = [
        "ls", "cat", "grep", "sed", "awk", "cut", "sort", "uniq", "head", "tail", "wc",
        "find", "locate", "xargs", "tar", "gzip", "gunzip", "zip", "unzip", "curl", "wget",
        "ssh", "scp", "rsync", "git", "svn", "make", "cmake", "gcc", "g++", "clang",
        "python", "python3", "node", "npm", "yarn", "java", "javac", "ruby", "perl",
        "php", "go", "rust", "swift", "docker", "kubectl", "helm", "terraform", "ansible",
        "vim", "nano", "emacs", "less", "more", "file", "stat", "du", "df", "mount",
        "umount", "ps", "top", "htop", "kill", "killall", "pgrep", "pkill", "nohup",
        "screen", "tmux", "crontab", "at", "batch", "systemctl", "service", "chkconfig",
        "update-rc.d", "iptables", "netstat", "ss", "lsof", "tcpdump", "wireshark",
        "ping", "traceroute", "dig", "nslookup", "host", "whois", "nc", "netcat",
        "openssl", "gpg", "base64", "xxd", "hexdump", "od", "strings", "nm", "objdump",
        "strip", "ar", "ranlib", "ld", "ldd", "strace", "ltrace", "gdb", "valgrind"
    ]
} 