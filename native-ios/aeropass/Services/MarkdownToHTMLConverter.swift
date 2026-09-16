import Foundation

/// Converts Markdown text to HTML for WebView rendering
struct MarkdownToHTMLConverter {
    
    static func convert(_ markdown: String) -> String {
        var html = markdown
        
        // Escape HTML entities first (but preserve LaTeX markers)
        html = escapeHTML(html)
        
        // Code blocks (```...```) - must be done first to avoid processing inside code
        html = convertCodeBlocks(html)
        
        // Block math formulas ($$...$$) - before inline processing
        html = convertBlockMath(html)
        
        // Inline math formulas ($...$)
        html = convertInlineMath(html)
        
        // Tables
        html = convertTables(html)
        
        // Headings (# ## ###)
        html = convertHeadings(html)
        
        // Horizontal rules
        html = convertHorizontalRules(html)
        
        // Blockquotes
        html = convertBlockquotes(html)
        
        // Unordered lists
        html = convertUnorderedLists(html)
        
        // Ordered lists
        html = convertOrderedLists(html)
        
        // Paragraphs
        html = convertParagraphs(html)
        
        // Inline formatting
        html = convertInlineFormatting(html)
        
        return html
    }
    
    private static func escapeHTML(_ text: String) -> String {
        // Always escape HTML special characters
        // Order matters: escape & first to avoid double-escaping
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
    
    private static func convertCodeBlocks(_ text: String) -> String {
        var result = text
        let pattern = "```(\\w*)\\n([\\s\\S]*?)```"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
        
        for match in matches.reversed() {
            if let fullRange = Range(match.range, in: result),
               let codeRange = Range(match.range(at: 2), in: result) {
                let language = match.range(at: 1).length > 0 ? String(result[Range(match.range(at: 1), in: result)!]) : ""
                let code = String(result[codeRange])
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                
                let langClass = language.isEmpty ? "" : " class=\"language-\(language)\""
                let replacement = "<pre><code\(langClass)>\(code)</code></pre>"
                result.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        return result
    }
    
    private static func convertBlockMath(_ text: String) -> String {
        // Block math: $$...$$ (multiline)
        var result = text
        let pattern = "\\$\\$([\\s\\S]*?)\\$\\$"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
        
        for match in matches.reversed() {
            if let fullRange = Range(match.range, in: result),
               let mathRange = Range(match.range(at: 1), in: result) {
                let math = String(result[mathRange])
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                let replacement = "<div class=\"math-block\">\\[\(math)\\]</div>"
                result.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        return result
    }
    
    private static func convertInlineMath(_ text: String) -> String {
        // Inline math: $...$ (single line, not preceded/followed by $)
        var result = text
        let pattern = "(?<!\\$)\\$(?!\\$)(.+?)(?<!\\$)\\$(?!\\$)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
        
        for match in matches.reversed() {
            if let fullRange = Range(match.range, in: result),
               let mathRange = Range(match.range(at: 1), in: result) {
                let math = String(result[mathRange])
                let replacement = "<span class=\"math-inline\">\\(\(math)\\)</span>"
                result.replaceSubrange(fullRange, with: replacement)
            }
        }
        
        return result
    }
    
    private static func convertTables(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var tableLines: [String] = []
        var inTable = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check if line is a table row (contains |)
            if trimmed.contains("|") && trimmed.hasPrefix("|") {
                if !inTable {
                    inTable = true
                    tableLines = []
                }
                tableLines.append(trimmed)
            } else {
                if inTable {
                    // End of table, process it
                    result.append(processTable(tableLines))
                    tableLines = []
                    inTable = false
                }
                result.append(line)
            }
        }
        
        // Handle table at end of text
        if inTable && !tableLines.isEmpty {
            result.append(processTable(tableLines))
        }
        
        return result.joined(separator: "\n")
    }
    
    private static func processTable(_ lines: [String]) -> String {
        guard lines.count >= 2 else { return lines.joined(separator: "\n") }
        
        var html = "<table>\n"
        
        // First line is header
        let headers = parseTableRow(lines[0])
        html += "  <thead>\n    <tr>\n"
        for header in headers {
            html += "      <th>\(header.trimmingCharacters(in: .whitespaces))</th>\n"
        }
        html += "    </tr>\n  </thead>\n"
        
        // Skip separator line (line with ---)
        var startRow = 1
        if lines.count > 1 && lines[1].contains("---") {
            startRow = 2
        }
        
        // Body rows
        if startRow < lines.count {
            html += "  <tbody>\n"
            for i in startRow..<lines.count {
                let cells = parseTableRow(lines[i])
                html += "    <tr>\n"
                for cell in cells {
                    html += "      <td>\(cell.trimmingCharacters(in: .whitespaces))</td>\n"
                }
                html += "    </tr>\n"
            }
            html += "  </tbody>\n"
        }
        
        html += "</table>"
        
        return html
    }
    
    private static func parseTableRow(_ line: String) -> [String] {
        // Remove leading and trailing |
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed = String(trimmed.dropFirst())
        }
        if trimmed.hasSuffix("|") {
            trimmed = String(trimmed.dropLast())
        }
        
        return trimmed.components(separatedBy: "|")
    }
    
    private static func convertHeadings(_ text: String) -> String {
        var result = text
        
        // H3
        result = result.replacingOccurrences(
            of: "(?m)^### (.+)$",
            with: "<h3>$1</h3>",
            options: .regularExpression
        )
        
        // H2
        result = result.replacingOccurrences(
            of: "(?m)^## (.+)$",
            with: "<h2>$1</h2>",
            options: .regularExpression
        )
        
        // H1
        result = result.replacingOccurrences(
            of: "(?m)^# (.+)$",
            with: "<h1>$1</h1>",
            options: .regularExpression
        )
        
        return result
    }
    
    private static func convertHorizontalRules(_ text: String) -> String {
        return text.replacingOccurrences(
            of: "(?m)^(---|\\*\\*\\*|___)$",
            with: "<hr>",
            options: .regularExpression
        )
    }
    
    private static func convertBlockquotes(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var inBlockquote = false
        
        for line in lines {
            if line.hasPrefix("&gt; ") {
                if !inBlockquote {
                    result.append("<blockquote>")
                    inBlockquote = true
                }
                result.append(String(line.dropFirst(5)))
            } else {
                if inBlockquote {
                    result.append("</blockquote>")
                    inBlockquote = false
                }
                result.append(line)
            }
        }
        
        if inBlockquote {
            result.append("</blockquote>")
        }
        
        return result.joined(separator: "\n")
    }
    
    private static func convertUnorderedLists(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var inList = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                if !inList {
                    result.append("<ul>")
                    inList = true
                }
                let content = String(trimmed.dropFirst(2))
                result.append("  <li>\(content)</li>")
            } else {
                if inList {
                    result.append("</ul>")
                    inList = false
                }
                result.append(line)
            }
        }
        
        if inList {
            result.append("</ul>")
        }
        
        return result.joined(separator: "\n")
    }
    
    private static func convertOrderedLists(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var inList = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let firstChar = trimmed.first, firstChar.isNumber,
               let dotIndex = trimmed.firstIndex(of: "."),
               trimmed[trimmed.startIndex..<dotIndex].allSatisfy({ $0.isNumber }) {
                if !inList {
                    result.append("<ol>")
                    inList = true
                }
                let afterDot = trimmed.index(after: dotIndex)
                let content = afterDot < trimmed.endIndex ? String(trimmed[afterDot...]).trimmingCharacters(in: .whitespaces) : ""
                result.append("  <li>\(content)</li>")
            } else {
                if inList {
                    result.append("</ol>")
                    inList = false
                }
                result.append(line)
            }
        }
        
        if inList {
            result.append("</ol>")
        }
        
        return result.joined(separator: "\n")
    }
    
    private static func convertParagraphs(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var paragraphLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip if it's already an HTML tag
            if trimmed.hasPrefix("<") {
                if !paragraphLines.isEmpty {
                    result.append("<p>\(paragraphLines.joined(separator: " "))</p>")
                    paragraphLines = []
                }
                result.append(line)
                continue
            }
            
            if trimmed.isEmpty {
                if !paragraphLines.isEmpty {
                    result.append("<p>\(paragraphLines.joined(separator: " "))</p>")
                    paragraphLines = []
                }
            } else {
                paragraphLines.append(trimmed)
            }
        }
        
        if !paragraphLines.isEmpty {
            result.append("<p>\(paragraphLines.joined(separator: " "))</p>")
        }
        
        return result.joined(separator: "\n")
    }
    
    private static func convertInlineFormatting(_ text: String) -> String {
        var result = text
        
        // Bold + Italic (***text*** or ___text___)
        result = result.replacingOccurrences(
            of: "\\*\\*\\*(.+?)\\*\\*\\*",
            with: "<strong><em>$1</em></strong>",
            options: .regularExpression
        )
        
        // Bold (**text** or __text__)
        result = result.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        
        // Italic (*text* or _text_)
        result = result.replacingOccurrences(
            of: "(?<!\\*)\\*(.+?)\\*(?!\\*)",
            with: "<em>$1</em>",
            options: .regularExpression
        )
        
        // Inline code (`text`)
        result = result.replacingOccurrences(
            of: "`(.+?)`",
            with: "<code>$1</code>",
            options: .regularExpression
        )
        
        return result
    }
}
