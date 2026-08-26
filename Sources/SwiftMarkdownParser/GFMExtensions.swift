/// GitHub Flavored Markdown (GFM) extensions
/// 
/// This file implements GFM extensions including tables, task lists, strikethrough,
/// and autolinks as specified in the GitHub Flavored Markdown Spec.
import Foundation

// MARK: - GFM Utilities

/// Utilities for GitHub Flavored Markdown parsing
enum GFMUtils {
    
    /// Check if a line is a table header separator
    static func isTableHeaderSeparator(_ line: String) -> Bool {
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
    static func parseTableHeaderSeparator(_ line: String) -> [GFMTableAlignment] {
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
    static func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.contains("|")
    }
    
    /// Parse table row into cells
    static func parseTableRow(_ line: String) -> [String] {
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
}
