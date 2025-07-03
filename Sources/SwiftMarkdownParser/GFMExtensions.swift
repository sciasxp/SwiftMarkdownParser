/// GitHub Flavored Markdown (GFM) extensions
/// 
/// This file implements GFM extensions including tables, task lists, strikethrough,
/// and autolinks as specified in the GitHub Flavored Markdown Spec.
import Foundation

// MARK: - GFM Utilities

/// Utilities for GitHub Flavored Markdown parsing
public enum GFMUtils {
    
    /// Check if a line is a table header separator
    public static func isTableHeaderSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // Must contain at least one pipe and one dash
        guard trimmed.contains("|") && trimmed.contains("-") else { return false }
        
        // Split by pipes and check each cell
        let cells = trimmed.components(separatedBy: "|")
        var validCells = 0
        
        for cell in cells {
            let cellTrimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
            if cellTrimmed.isEmpty {
                continue
            }
            
            // Check if cell contains only dashes, colons, and spaces
            let validChars = CharacterSet(charactersIn: "-: ")
            if cellTrimmed.rangeOfCharacter(from: validChars.inverted) == nil {
                validCells += 1
            }
        }
        
        return validCells > 0
    }
    
    /// Parse table header separator and return column alignments
    public static func parseTableHeaderSeparator(_ line: String) -> [GFMTableAlignment] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let cells = trimmed.components(separatedBy: "|")
        var alignments: [GFMTableAlignment] = []
        
        for cell in cells {
            let cellTrimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
            if cellTrimmed.isEmpty {
                continue
            }
            
            let alignment = parseColumnAlignment(cellTrimmed)
            alignments.append(alignment)
        }
        
        return alignments
    }
    
    /// Parse column alignment from separator cell
    private static func parseColumnAlignment(_ cell: String) -> GFMTableAlignment {
        let startsWithColon = cell.hasPrefix(":")
        let endsWithColon = cell.hasSuffix(":")
        
        if startsWithColon && endsWithColon {
            return .center
        } else if endsWithColon {
            return .right
        } else if startsWithColon {
            return .left
        } else {
            return .none
        }
    }
    
    /// Check if a line could be a table row
    public static func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.contains("|")
    }
    
    /// Parse table row into cells
    public static func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        var cells = trimmed.components(separatedBy: "|")
        
        // Remove empty cells at start and end (from leading/trailing pipes)
        if cells.first?.isEmpty == true {
            cells.removeFirst()
        }
        if cells.last?.isEmpty == true {
            cells.removeLast()
        }
        
        return cells.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    /// Check if a line is a task list item
    public static func isTaskListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must start with list marker
        guard let markerInfo = CommonMarkUtils.parseListMarker(trimmed) else { return false }
        
        // Extract content after marker
        let afterMarker = String(trimmed.dropFirst(markerInfo.width)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for task list checkbox
        return afterMarker.hasPrefix("[ ]") || afterMarker.hasPrefix("[x]") || afterMarker.hasPrefix("[X]")
    }
    
    /// Parse task list item
    public static func parseTaskListItem(_ line: String) -> GFMTaskListItemInfo? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let markerInfo = CommonMarkUtils.parseListMarker(trimmed) else { return nil }
        
        let afterMarker = String(trimmed.dropFirst(markerInfo.width)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        var isChecked = false
        var content = ""
        
        if afterMarker.hasPrefix("[ ]") {
            isChecked = false
            content = String(afterMarker.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if afterMarker.hasPrefix("[x]") || afterMarker.hasPrefix("[X]") {
            isChecked = true
            content = String(afterMarker.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return nil
        }
        
        return GFMTaskListItemInfo(
            marker: markerInfo,
            isChecked: isChecked,
            content: content
        )
    }
    
    /// Check if text contains strikethrough
    public static func containsStrikethrough(_ text: String) -> Bool {
        return text.contains("~~")
    }
    
    /// Parse strikethrough spans in text
    public static func parseStrikethrough(_ text: String) -> [GFMStrikethroughSpan] {
        var spans: [GFMStrikethroughSpan] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            // Find next ~~
            guard let startRange = text.range(of: "~~", range: currentIndex..<text.endIndex) else {
                break
            }
            
            let afterStart = startRange.upperBound
            
            // Find closing ~~
            guard let endRange = text.range(of: "~~", range: afterStart..<text.endIndex) else {
                break
            }
            
            let content = String(text[afterStart..<endRange.lowerBound])
            
            // Strikethrough cannot be empty or contain only whitespace
            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let span = GFMStrikethroughSpan(
                    range: startRange.lowerBound..<endRange.upperBound,
                    content: content
                )
                spans.append(span)
            }
            
            currentIndex = endRange.upperBound
        }
        
        return spans
    }
    
    /// Check if text contains autolinks
    public static func containsAutolinks(_ text: String) -> Bool {
        return text.contains("http://") || text.contains("https://") || text.contains("www.") || text.contains("@")
    }
    
    /// Parse autolinks in text
    public static func parseAutolinks(_ text: String) -> [GFMAutolinkSpan] {
        var spans: [GFMAutolinkSpan] = []
        
        // Parse URL autolinks
        spans.append(contentsOf: parseURLAutolinks(text))
        
        // Parse email autolinks
        spans.append(contentsOf: parseEmailAutolinks(text))
        
        return spans.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
    
    /// Parse URL autolinks
    static func parseURLAutolinks(_ text: String) -> [GFMAutolinkSpan] {
        var spans: [GFMAutolinkSpan] = []
        let urlPattern = #"(https?://[^\s<>\[\]]+)"#
        
        do {
            let regex = try NSRegularExpression(pattern: urlPattern, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let url = String(text[range])
                    let span = GFMAutolinkSpan(
                        range: range,
                        url: url,
                        type: .url
                    )
                    spans.append(span)
                }
            }
        } catch {
            // Regex failed, skip URL autolinks
        }
        
        return spans
    }
    
    /// Parse email autolinks
    static func parseEmailAutolinks(_ text: String) -> [GFMAutolinkSpan] {
        var spans: [GFMAutolinkSpan] = []
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        
        do {
            let regex = try NSRegularExpression(pattern: emailPattern, options: [])
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let email = String(text[range])
                    let span = GFMAutolinkSpan(
                        range: range,
                        url: "mailto:" + email,
                        type: .email
                    )
                    spans.append(span)
                }
            }
        } catch {
            // Regex failed, skip email autolinks
        }
        
        return spans
    }
}

// MARK: - GFM Data Types

// Table column alignment is now defined in AST.swift as GFMTableAlignment

/// Information about a parsed GFM task list item
public struct GFMTaskListItemInfo: Sendable, Equatable {
    /// The list marker information
    public let marker: ListMarkerInfo
    
    /// Whether the task is checked
    public let isChecked: Bool
    
    /// The content after the checkbox
    public let content: String
}

/// Strikethrough span information for GFM
public struct GFMStrikethroughSpan: Sendable, Equatable {
    /// Range in the original text
    public let range: Range<String.Index>
    
    /// Content within the strikethrough
    public let content: String
}

/// Autolink span information for GFM
public struct GFMAutolinkSpan: Sendable, Equatable {
    /// Range in the original text
    public let range: Range<String.Index>
    
    /// The URL (including mailto: for emails)
    public let url: String
    
    /// Type of autolink
    public let type: GFMAutolinkType
}

/// Type of autolink for GFM
public enum GFMAutolinkType: String, Sendable, CaseIterable {
    case url = "url"
    case email = "email"
}

// MARK: - GFM AST Node Extensions (using nodes defined in AST.swift)

// MARK: - GFM Block Parser Extensions

extension BlockParser {
    
    /// Parse GFM table
    func parseGFMTable(_ lines: [String], startIndex: Int) throws -> (node: AST.GFMTableNode, consumedLines: Int) {
        guard startIndex < lines.count else {
            throw MarkdownParsingError.invalidTableStructure("No lines available for table parsing")
        }
        
        var currentIndex = startIndex
        var bodyRows: [AST.GFMTableRowNode] = []
        var alignments: [GFMTableAlignment] = []
        
        // Parse header row
        if currentIndex < lines.count && GFMUtils.isTableRow(lines[currentIndex]) {
            let headerCells = GFMUtils.parseTableRow(lines[currentIndex])
            let headerRow = AST.GFMTableRowNode(
                cells: headerCells.map { AST.GFMTableCellNode(content: $0, isHeader: true) },
                isHeader: true,
                sourceLocation: SourceLocation(line: currentIndex + 1, column: 1, offset: 0)
            )
            bodyRows.append(headerRow) // Add header to rows for now
            currentIndex += 1
        }
        
        // Parse separator row
        if currentIndex < lines.count && GFMUtils.isTableHeaderSeparator(lines[currentIndex]) {
            alignments = GFMUtils.parseTableHeaderSeparator(lines[currentIndex])
            currentIndex += 1
        } else {
            throw MarkdownParsingError.invalidTableStructure("Missing table header separator")
        }
        
        // Parse body rows
        while currentIndex < lines.count && GFMUtils.isTableRow(lines[currentIndex]) {
            let rowCells = GFMUtils.parseTableRow(lines[currentIndex])
            let cells = rowCells.enumerated().map { index, content in
                let alignment = index < alignments.count ? alignments[index] : .none
                return AST.GFMTableCellNode(content: content, isHeader: false, alignment: alignment)
            }
            
            let row = AST.GFMTableRowNode(
                cells: cells,
                isHeader: false,
                sourceLocation: SourceLocation(line: currentIndex + 1, column: 1, offset: 0)
            )
            bodyRows.append(row)
            currentIndex += 1
        }
        
        let table = AST.GFMTableNode(
            rows: bodyRows,
            alignments: alignments,
            sourceLocation: SourceLocation(line: startIndex + 1, column: 1, offset: 0)
        )
        
        return (node: table, consumedLines: currentIndex - startIndex)
    }
    
    /// Parse GFM task list item
    func parseGFMTaskListItem(_ line: String, lineNumber: Int) throws -> AST.GFMTaskListItemNode? {
        guard let taskInfo = GFMUtils.parseTaskListItem(line) else { return nil }
        
        let contentNode = AST.TextNode(content: taskInfo.content, sourceLocation: SourceLocation(line: lineNumber, column: 1, offset: 0))
        
        return AST.GFMTaskListItemNode(
            isChecked: taskInfo.isChecked,
            children: [contentNode],
            sourceLocation: SourceLocation(line: lineNumber, column: 1, offset: 0)
        )
    }
}

// MARK: - GFM Inline Parser Extensions

extension InlineParser {
    
    /// Parse GFM strikethrough
    func parseGFMStrikethrough(_ text: String) -> [AST.StrikethroughNode] {
        let spans = GFMUtils.parseStrikethrough(text)
        return spans.map { span in
            AST.StrikethroughNode(
                content: [AST.TextNode(content: span.content)],
                sourceLocation: nil
            )
        }
    }
    
    /// Parse GFM autolinks
    func parseGFMAutolinks(_ text: String) -> [AST.AutolinkNode] {
        let spans = GFMUtils.parseAutolinks(text)
        return spans.map { span in
            AST.AutolinkNode(
                url: span.url,
                text: span.type == .email ? String(span.url.dropFirst(7)) : span.url, // Remove "mailto:" for display
                sourceLocation: nil
            )
        }
    }
} 