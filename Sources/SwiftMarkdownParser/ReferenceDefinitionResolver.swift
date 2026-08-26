import Foundation

struct ReferenceDefinitionResolution {
    let sourceForParsing: String
    let references: [String: LinkReference]
}

enum ReferenceDefinitionResolver {
    static func resolve(in source: String) -> ReferenceDefinitionResolution {
        var references: [String: LinkReference] = [:]
        var output = ""
        var line = 1
        var offset = 0
        var openFence: Fence?

        for segment in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let rawLine = String(segment)
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
                output += rawLine
            } else if openFence != nil {
                output += rawLine
            } else if let definition = parseDefinition(rawLine) {
                let normalizedLabel = normalizeLabel(definition.label)
                if references[normalizedLabel] == nil {
                    references[normalizedLabel] = LinkReference(
                        url: definition.url,
                        title: definition.title,
                        sourceLocation: location.extending(over: rawLine)
                    )
                }
                output += String(rawLine.map { character in
                    character == "\t" ? "\t" : " "
                })
            } else {
                output += rawLine
            }

            offset += rawLine.count
            if offset < source.count {
                output += "\n"
                offset += 1
                line += 1
            }
        }

        return ReferenceDefinitionResolution(
            sourceForParsing: output,
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
