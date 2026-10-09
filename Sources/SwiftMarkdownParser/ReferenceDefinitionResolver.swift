import Foundation

struct ReferenceDefinitionResolution {
    let sourceForParsing: String
    let references: [String: LinkReference]
}

enum ReferenceDefinitionResolver {
    static func resolve(in source: String, sourceLength: Int) -> ReferenceDefinitionResolution {
        var references: [String: LinkReference] = [:]
        var output = ""
        var isRewritingSource = false
        var line = 1
        var offset = 0
        var openFence: Fence?
        var lineStart = source.startIndex

        while true {
            let newlineIndex = source[lineStart...].firstIndex(where: \.isNewline)
            let lineEnd = newlineIndex ?? source.endIndex
            let rawLine = String(source[lineStart..<lineEnd])
            let location = SourceLocation(line: line, column: 1, offset: offset)

            if let fence = fence(in: rawLine) {
                if let currentFence = openFence {
                    if fence.character == currentFence.character,
                       fence.length >= currentFence.length,
                       fence.remainder.allSatisfy(\.isWhitespace) {
                        openFence = nil
                    }
                } else {
                    openFence = fence
                }
                if isRewritingSource {
                    output.append(contentsOf: rawLine)
                }
            } else if openFence != nil {
                if isRewritingSource {
                    output.append(contentsOf: rawLine)
                }
            } else if let definition = parseDefinition(rawLine) {
                let normalizedLabel = normalizeLabel(definition.label)
                if references[normalizedLabel] == nil {
                    references[normalizedLabel] = LinkReference(
                        url: definition.url,
                        title: definition.title,
                        sourceLocation: location.extending(over: rawLine)
                    )
                }
                if !isRewritingSource {
                    output.reserveCapacity(sourceLength)
                    let prefixEnd = source.index(source.startIndex, offsetBy: offset)
                    output.append(contentsOf: source[..<prefixEnd])
                    isRewritingSource = true
                }
                for character in rawLine {
                    output.append(character == "\t" ? "\t" : " ")
                }
            } else {
                if isRewritingSource {
                    output.append(contentsOf: rawLine)
                }
            }

            guard let newlineIndex else { break }

            if isRewritingSource {
                output.append(source[newlineIndex])
            }
            offset += rawLine.count + 1
            line += 1
            lineStart = source.index(after: newlineIndex)
        }

        return ReferenceDefinitionResolution(
            sourceForParsing: isRewritingSource ? output : source,
            references: references
        )
    }

    static func normalizeLabel(_ label: String) -> String {
        label
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
    }

    private static func parseDefinition(_ line: String) -> (label: String, url: String, title: String?)? {
        let indentation = line.prefix(while: { $0 == " " }).count
        guard indentation <= 3 else { return nil }

        let trimmed = line.dropFirst(indentation).trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["),
              let separator = trimmed.range(of: "]:"),
              separator.lowerBound > trimmed.startIndex else {
            return nil
        }

        let label = String(trimmed[trimmed.index(after: trimmed.startIndex)..<separator.lowerBound])
        var destination = String(trimmed[separator.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        guard !destination.isEmpty else { return nil }

        var title: String?
        if let quote = destination.firstIndex(of: "\"") {
            let titlePart = destination[quote...]
            if titlePart.hasSuffix("\"") && titlePart.count >= 2 {
                title = String(titlePart.dropFirst().dropLast())
                destination = String(destination[..<quote]).trimmingCharacters(in: .whitespaces)
            }
        }

        if destination.hasPrefix("<"), destination.hasSuffix(">") {
            destination = String(destination.dropFirst().dropLast())
        }
        guard !destination.isEmpty else { return nil }
        return (label, destination, title)
    }

    private struct Fence {
        let character: Character
        let length: Int
        let remainder: Substring
    }

    private static func fence(in line: String) -> Fence? {
        let indentation = line.prefix(while: { $0 == " " }).count
        guard indentation <= 3 else { return nil }

        let content = line.dropFirst(indentation)
        guard let marker = content.first, marker == "`" || marker == "~" else { return nil }
        let runLength = content.prefix(while: { $0 == marker }).count
        guard runLength >= 3 else { return nil }

        return Fence(
            character: marker,
            length: runLength,
            remainder: content.dropFirst(runLength)
        )
    }
}
