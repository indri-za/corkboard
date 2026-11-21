import Foundation

public enum TicketParser {
    public static func parse(fileURL: URL, column: Column) -> Ticket {
        let filename = fileURL.lastPathComponent
        let modified =
            (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? Date()
        let data = try? Data(contentsOf: fileURL)
        let text: String
        var unreadable = false
        if let data, var utf = String(data: data, encoding: .utf8) {
            if utf.hasPrefix("\u{feff}") { utf.removeFirst() }
            text = utf
        } else if let data, let latin = String(data: data, encoding: .isoLatin1) {
            text = latin
        } else {
            text = ""
            unreadable = data == nil
        }
        return parse(
            text: text,
            filename: filename,
            column: column,
            fileURL: fileURL,
            modified: modified,
            unreadable: unreadable
        )
    }

    public static func parse(
        text: String,
        filename: String,
        column: Column,
        fileURL: URL,
        modified: Date,
        unreadable: Bool = false
    ) -> Ticket {
        let normalized =
            text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        let metadata = readMetadata(lines)
        let heading = firstHeading(lines)
        let fromFile = filenameParts(filename)

        let number = heading.number ?? fromFile.number ?? ""
        let title: String
        if unreadable {
            title = "Couldn't read file"
        } else if let headingTitle = heading.title, !headingTitle.isEmpty {
            title = headingTitle
        } else if let fileTitle = fromFile.title, !fileTitle.isEmpty {
            title = fileTitle
        } else {
            title = filename
        }

        let summarySource =
            section(lines, titles: ["summary"])
            ?? section(lines, titles: ["overview"])
            ?? firstParagraph(lines)
        let summary =
            unreadable
            ? "This markdown file isn't valid text."
            : clip(plain(summarySource ?? ""))

        return Ticket(
            id: "\(column.rawValue)/\(filename)",
            fileURL: fileURL,
            filename: filename,
            relativePath: "\(column.rawValue)/\(filename)",
            column: column,
            number: number,
            numberParts: numberParts(number),
            title: title,
            type: metadata["type"],
            portal: metadata["portal"],
            status: metadata["status"],
            summary: summary,
            body: normalized,
            modified: modified
        )
    }

    static func numberParts(_ number: String) -> [Int] {
        guard !number.isEmpty else { return [] }
        let parts = number.split(separator: ".").compactMap { Int($0) }
        if parts.isEmpty { return [] }
        return parts
    }

    static func clip(_ text: String, limit: Int = 220) -> String {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard collapsed.count > limit else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: limit)
        let head = collapsed[..<end]
        if let space = head.lastIndex(of: " "),
            collapsed.distance(from: collapsed.startIndex, to: space) > limit / 2
        {
            return String(head[..<space]) + "…"
        }
        return String(head) + "…"
    }

    static func plain(_ markdown: String) -> String {
        var lines: [String] = []
        var inFence = false
        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence || trimmed.hasPrefix("#") || trimmed.hasPrefix("|") || isRule(trimmed) {
                continue
            }
            var cleaned = trimmed
            if let item = listBody(cleaned) {
                cleaned = item
            }
            cleaned = stripInline(cleaned)
            if !cleaned.isEmpty {
                lines.append(cleaned)
            }
        }
        return lines.joined(separator: " ")
    }

    private static func readMetadata(_ lines: [String]) -> [String: String] {
        var values: [String: String] = [:]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") { break }
            guard trimmed.hasPrefix("**"), let marker = trimmed.range(of: "**:") else { continue }
            let keyStart = trimmed.index(trimmed.startIndex, offsetBy: 2)
            guard keyStart <= marker.lowerBound else { continue }
            let key = trimmed[keyStart..<marker.lowerBound]
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            let value = trimmed[marker.upperBound...]
                .trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                values[key] = value
            }
        }
        return values
    }

    private static func firstHeading(_ lines: [String]) -> (number: String?, title: String?) {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("# "), !trimmed.hasPrefix("## ") else { continue }
            let body = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            guard !body.isEmpty else { continue }
            if let split = splitNumber(String(body)) {
                return (split.number, split.title)
            }
            return (nil, String(body))
        }
        return (nil, nil)
    }

    private static func filenameParts(_ filename: String) -> (number: String?, title: String?) {
        var base = filename
        if base.lowercased().hasSuffix(".md") {
            base = String(base.dropLast(3))
        }
        if base.hasPrefix("#") {
            base.removeFirst()
        }
        guard let split = splitNumber(base) else { return (nil, nil) }
        let title = split.title.replacingOccurrences(of: "-", with: " ")
        return (split.number, title)
    }

    /// Pulls a leading ticket number off strings like `#104 — Title` or `23.22 Post-Event`.
    static func splitNumber(_ text: String) -> (number: String, title: String)? {
        var rest = text.trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix("#") {
            rest.removeFirst()
            rest = rest.trimmingCharacters(in: .whitespaces)
        }
        guard !rest.isEmpty, rest.first?.isNumber == true else { return nil }

        var number = ""
        var index = rest.startIndex
        while index < rest.endIndex {
            let character = rest[index]
            if character.isNumber || character == "." {
                number.append(character)
                index = rest.index(after: index)
            } else {
                break
            }
        }
        guard isValidNumber(number) else { return nil }
        var title = rest[index...].trimmingCharacters(in: .whitespaces)
        if let first = title.first, separatorCharacters.contains(first) {
            while let next = title.first, separatorCharacters.contains(next) || next == " " {
                title.removeFirst()
            }
            title = title.trimmingCharacters(in: .whitespaces)
        }
        guard !title.isEmpty else { return nil }
        return (number, title)
    }

    private static let separatorCharacters: Set<Character> = ["—", "–", "-", ":"]

    private static func isValidNumber(_ number: String) -> Bool {
        guard !number.isEmpty, !number.hasPrefix("."), !number.hasSuffix(".") else { return false }
        let parts = number.split(separator: ".", omittingEmptySubsequences: false)
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy(\.isNumber)
        }
    }

    private static func section(_ lines: [String], titles: [String]) -> String? {
        var capturing = false
        var buffer: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## "), !trimmed.hasPrefix("###") {
                if capturing { break }
                let name = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces).lowercased()
                capturing = titles.contains { name == $0 || name.hasPrefix($0 + " ") }
                continue
            }
            if capturing {
                buffer.append(line)
            }
        }
        let text = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func firstParagraph(_ lines: [String]) -> String? {
        var started = false
        var buffer: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !started {
                if trimmed.isEmpty || trimmed.hasPrefix("#") || isMetadata(trimmed) {
                    continue
                }
                started = true
            }
            if trimmed.isEmpty || (trimmed.hasPrefix("## ") && !trimmed.hasPrefix("###")) {
                break
            }
            if isMetadata(trimmed) { continue }
            buffer.append(trimmed)
        }
        let text = buffer.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func isMetadata(_ line: String) -> Bool {
        line.hasPrefix("**") && line.contains("**:")
    }

    private static func isRule(_ line: String) -> Bool {
        line.count >= 3 && line.allSatisfy { $0 == "-" || $0 == " " }
    }

    private static func listBody(_ line: String) -> String? {
        let patterns = ["- [x] ", "- [X] ", "- [ ] ", "* [x] ", "* [ ] ", "- ", "* ", "+ "]
        for pattern in patterns where line.hasPrefix(pattern) {
            return String(line.dropFirst(pattern.count))
        }
        if let dot = line.firstIndex(of: "."),
            line[..<dot].allSatisfy(\.isNumber),
            line.distance(from: line.startIndex, to: dot) <= 3
        {
            let after = line.index(after: dot)
            if after < line.endIndex, line[after] == " " {
                return String(line[line.index(after: after)...])
            }
        }
        return nil
    }

    private static func stripInline(_ text: String) -> String {
        var result = ""
        var rest = Substring(text)
        while let bracket = rest.range(of: "](") {
            if let open = rest[..<bracket.lowerBound].lastIndex(of: "[") {
                result.append(contentsOf: rest[..<open])
                let label = rest[rest.index(after: open)..<bracket.lowerBound]
                result.append(contentsOf: label)
                if let close = rest[bracket.upperBound...].firstIndex(of: ")") {
                    rest = rest[rest.index(after: close)...]
                    continue
                }
            }
            result.append(contentsOf: rest[..<bracket.upperBound])
            rest = rest[bracket.upperBound...]
        }
        result.append(contentsOf: rest)
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "`", with: "")
        result = result.replacingOccurrences(of: "*", with: "")
        return result.trimmingCharacters(in: .whitespaces)
    }
}
