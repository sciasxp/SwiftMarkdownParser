/// Reads the Link Reference Definitions at the start of a closed paragraph's
/// raw text, as CommonMark 0.30 section 4.7 specifies. The Block Phase calls it
/// when a paragraph closes; what follows the definitions stays paragraph text.
enum LinkReferenceDefinitionParser {
    /// One definition; `range` covers its characters in the parsed text.
    struct Definition {
        let label: String
        let url: String
        let title: String?
        let range: Range<Int>
    }

    /// The definitions at the start of `text`, in order, and the offset where
    /// the rest of the text starts.
    static func parse(_ text: [Character]) -> (definitions: [Definition], end: Int) {
        var definitions: [Definition] = []
        var end = 0
        while end < text.count, let definition = definition(in: text, at: end) {
            definitions.append(definition)
            end = definition.range.upperBound
        }
        return (definitions, end)
    }

    /// A label's matching key: case-folded, whitespace collapsed and trimmed.
    static func normalizeLabel(_ label: String) -> String {
        label
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
    }

    // MARK: - One Definition

    /// The definition starting at `start`, ending after its line ending.
    private static func definition(in text: [Character], at start: Int) -> Definition? {
        var cursor = Cursor(text: text, position: start)
        cursor.skipSpaces()
        let definitionStart = cursor.position

        guard let label = cursor.label(), cursor.take(":") else { return nil }
        cursor.skipWhitespace(lineEndings: 1)
        guard let url = cursor.destination() else { return nil }
        let afterDestination = cursor.position

        // A title needs whitespace before it and nothing after it on its line
        let spaceBeforeTitle = cursor.skipWhitespace(lineEndings: 1)
        if spaceBeforeTitle, let title = cursor.title(), cursor.skipToLineEnd() {
            return Definition(label: label, url: url, title: title, range: definitionStart..<cursor.position)
        }

        cursor.position = afterDestination
        guard cursor.skipToLineEnd() else { return nil }
        return Definition(label: label, url: url, title: nil, range: definitionStart..<cursor.position)
    }

    private struct Cursor {
        let text: [Character]
        var position: Int

        private var current: Character? {
            position < text.count ? text[position] : nil
        }

        mutating func take(_ character: Character) -> Bool {
            guard current == character else { return false }
            position += 1
            return true
        }

        mutating func skipSpaces() {
            while let character = current, character == " " || character == "\t" {
                position += 1
            }
        }

        /// Skips spaces, tabs, and at most `lineEndings` line endings; whether
        /// it skipped anything.
        @discardableResult
        mutating func skipWhitespace(lineEndings: Int) -> Bool {
            let start = position
            var lineEndingsLeft = lineEndings
            while let character = current {
                if character == " " || character == "\t" {
                    position += 1
                } else if MarkdownSourceText.isLineEnding(character), lineEndingsLeft > 0 {
                    lineEndingsLeft -= 1
                    position += 1
                } else {
                    break
                }
            }
            return position > start
        }

        /// Skips spaces and tabs, then the line ending; false when other
        /// characters come first.
        mutating func skipToLineEnd() -> Bool {
            skipSpaces()
            guard let character = current else { return true }
            guard MarkdownSourceText.isLineEnding(character) else { return false }
            position += 1
            return true
        }

        /// `[label]`: at most 999 characters, not blank, without an unescaped
        /// bracket inside. Returns the raw label.
        mutating func label() -> String? {
            guard take("[") else { return nil }
            let start = position
            while let character = current {
                switch character {
                case "\\":
                    position += 1
                    if let next = current, next.isASCIIPunctuation {
                        position += 1
                    }
                case "[":
                    return nil
                case "]":
                    let label = text[start..<position]
                    position += 1
                    guard label.count <= 999, label.contains(where: { !$0.isWhitespace }) else { return nil }
                    return String(label)
                default:
                    position += 1
                }
            }
            return nil
        }

        /// `<…>` on one line, possibly empty, or a non-empty run of
        /// non-whitespace characters with balanced parentheses. Returns the
        /// destination with backslash escapes decoded.
        mutating func destination() -> String? {
            if take("<") {
                var destination = ""
                while let character = current {
                    position += 1
                    switch character {
                    case ">":
                        return destination
                    case "<":
                        return nil
                    case "\\":
                        destination.append(escaped())
                    default:
                        guard !MarkdownSourceText.isLineEnding(character) else { return nil }
                        destination.append(character)
                    }
                }
                return nil
            }

            var destination = ""
            var depth = 0
            while let character = current, character != " ", !character.isASCIIControl {
                if character == "(" {
                    depth += 1
                    guard depth <= 32 else { return nil }
                } else if character == ")" {
                    guard depth > 0 else { break }
                    depth -= 1
                }
                position += 1
                destination.append(character == "\\" ? escaped() : character)
            }
            guard depth == 0, !destination.isEmpty else { return nil }
            return destination
        }

        /// `"…"`, `'…'`, or `(…)`, possibly over several lines. Returns the
        /// title with backslash escapes decoded.
        mutating func title() -> String? {
            let closing: Character
            switch current {
            case "\"": closing = "\""
            case "'": closing = "'"
            case "(": closing = ")"
            default: return nil
            }
            let opening = text[position]
            position += 1
            var title = ""
            while let character = current {
                position += 1
                if character == closing {
                    return title
                }
                if character == "(" && opening == "(" {
                    return nil
                }
                title.append(character == "\\" ? escaped() : character)
            }
            return nil
        }

        /// After a backslash: the escaped punctuation character, consumed, or
        /// the backslash itself.
        private mutating func escaped() -> Character {
            guard let next = current, next.isASCIIPunctuation else { return "\\" }
            position += 1
            return next
        }
    }
}

private extension Character {
    var isASCIIPunctuation: Bool {
        isASCII && "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~".contains(self)
    }

    var isASCIIControl: Bool {
        guard let scalar = unicodeScalars.first, isASCII else { return false }
        return scalar.value < 0x20 || scalar.value == 0x7F
    }
}
