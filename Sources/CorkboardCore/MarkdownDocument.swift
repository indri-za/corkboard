import Foundation

public struct MarkdownListItem: Equatable, Sendable {
    public var marker: String
    public var checked: Bool?
    public var text: String

    public init(marker: String, checked: Bool?, text: String) {
        self.marker = marker
        self.checked = checked
        self.text = text
    }
}

public enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([MarkdownListItem])
    case code(String)
    case table(header: [String], rows: [[String]])
    case rule
    case quote(String)
}

public enum MarkdownDocument {
    public static func parse(_ source: String) -> [MarkdownBlock] {
        let text =
            source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = text.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let raw = lines[index]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || isComment(trimmed) {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                var code: [String] = []
                index += 1
                while index < lines.count
                    && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```")
                {
                    code.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(.code(code.joined(separator: "\n")))
                continue
            }

            if isRule(trimmed) {
                blocks.append(.rule)
                index += 1
                continue
            }

            if let level = headingLevel(trimmed) {
                blocks.append(.heading(level: level, text: headingBody(trimmed, level: level)))
                index += 1
                continue
            }

            if isTableRow(trimmed) {
                var rows: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    if !isTableRow(candidate) { break }
                    rows.append(candidate)
                    index += 1
                }
                blocks.append(parseTable(rows))
                continue
            }

            if isListItem(trimmed) {
                var items: [MarkdownListItem] = []
                while index < lines.count {
                    let candidateRaw = lines[index]
                    let candidate = candidateRaw.trimmingCharacters(in: .whitespaces)
                    if candidate.isEmpty { break }
                    if isListItem(candidate) {
                        items.append(parseItem(candidate))
                        index += 1
                        continue
                    }
                    if candidateRaw.hasPrefix("  ") || candidateRaw.hasPrefix("\t") {
                        if !items.isEmpty {
                            items[items.count - 1].text += " " + candidate
                        }
                        index += 1
                        continue
                    }
                    break
                }
                blocks.append(.bullets(items))
                continue
            }

            if trimmed.hasPrefix(">") {
                var parts: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix(">") else { break }
                    var quote = candidate.dropFirst()
                    if quote.first == " " { quote = quote.dropFirst() }
                    parts.append(String(quote))
                    index += 1
                }
                blocks.append(.quote(parts.joined(separator: " ")))
                continue
            }

            var paragraph: [String] = []
            while index < lines.count {
                let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                if candidate.isEmpty
                    || candidate.hasPrefix("```")
                    || headingLevel(candidate) != nil
                    || isListItem(candidate)
                    || isTableRow(candidate)
                    || candidate.hasPrefix(">")
                    || isRule(candidate)
                {
                    break
                }
                paragraph.append(candidate)
                index += 1
            }
            if paragraph.isEmpty {
                index += 1
            } else {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
            }
        }

        return blocks
    }

    private static func isComment(_ line: String) -> Bool {
        line.hasPrefix("<!--") && line.hasSuffix("-->")
    }

    private static func isRule(_ line: String) -> Bool {
        guard line.count >= 3 else { return false }
        let marks: Set<Character> = ["-", "*", "_"]
        guard let first = line.first, marks.contains(first) else { return false }
        return line.allSatisfy { $0 == first || $0 == " " }
    }

    private static func headingLevel(_ line: String) -> Int? {
        var count = 0
        for character in line {
            if character == "#" {
                count += 1
            } else {
                break
            }
        }
        guard (1...6).contains(count) else { return nil }
        let index = line.index(line.startIndex, offsetBy: count)
        guard index < line.endIndex, line[index] == " " else { return nil }
        return count
    }

    private static func headingBody(_ line: String, level: Int) -> String {
        let index = line.index(line.startIndex, offsetBy: level + 1)
        return String(line[index...]).trimmingCharacters(in: .whitespaces)
    }

    private static func isTableRow(_ line: String) -> Bool {
        let pipes = line.filter { $0 == "|" }.count
        if line.hasPrefix("|") { return pipes >= 1 }
        return pipes >= 2
    }

    private static func isListItem(_ line: String) -> Bool {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return true
        }
        guard let dot = line.firstIndex(of: ".") else { return false }
        let distance = line.distance(from: line.startIndex, to: dot)
        guard distance > 0, distance <= 3 else { return false }
        guard line[..<dot].allSatisfy(\.isNumber) else { return false }
        let after = line.index(after: dot)
        return after < line.endIndex && line[after] == " "
    }

    private static func parseItem(_ line: String) -> MarkdownListItem {
        var rest = line
        var marker = "•"
        if let dot = rest.firstIndex(of: "."),
            rest.distance(from: rest.startIndex, to: dot) <= 3,
            rest[..<dot].allSatisfy(\.isNumber)
        {
            let afterDot = rest.index(after: dot)
            if afterDot < rest.endIndex, rest[afterDot] == " " {
                marker = String(rest[...dot])
                rest = String(rest[rest.index(after: afterDot)...])
            }
        } else if rest.hasPrefix("- ") || rest.hasPrefix("* ") || rest.hasPrefix("+ ") {
            rest = String(rest.dropFirst(2))
        }

        var checked: Bool?
        if rest.hasPrefix("[ ]") {
            checked = false
            rest = String(rest.dropFirst(3))
        } else if rest.hasPrefix("[x]") || rest.hasPrefix("[X]") {
            checked = true
            rest = String(rest.dropFirst(3))
        }
        return MarkdownListItem(
            marker: marker, checked: checked, text: rest.trimmingCharacters(in: .whitespaces))
    }

    private static func parseTable(_ rows: [String]) -> MarkdownBlock {
        let parsed = rows.map(cells)
        guard !parsed.isEmpty else { return .table(header: [], rows: []) }
        if parsed.count >= 2, isSeparator(parsed[1]) {
            let body = parsed.dropFirst(2).filter { !isSeparator($0) }
            return .table(header: parsed[0], rows: Array(body))
        }
        return .table(header: [], rows: parsed.filter { !isSeparator($0) })
    }

    private static func cells(_ row: String) -> [String] {
        var parts = row.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        if parts.first?.isEmpty == true { parts.removeFirst() }
        if parts.last?.isEmpty == true { parts.removeLast() }
        return parts
    }

    private static func isSeparator(_ cells: [String]) -> Bool {
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let core = cell.replacingOccurrences(of: ":", with: "")
            return core.count >= 3 && core.allSatisfy { $0 == "-" }
        }
    }
}
