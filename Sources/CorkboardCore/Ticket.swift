import Foundation

public struct Ticket: Identifiable, Hashable, Sendable {
    public let id: String
    public let fileURL: URL
    public let filename: String
    public let relativePath: String
    public let column: Column
    public let number: String
    public let numberParts: [Int]
    public let title: String
    public let type: String?
    public let portal: String?
    public let status: String?
    public let summary: String
    public let body: String
    public let modified: Date

    public var displayNumber: String {
        number.isEmpty ? filename : "#\(number)"
    }

    /// Short rubber-stamp label, e.g. "BUG" or "FEATURE".
    public var stamp: String? {
        guard let type else { return nil }
        let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let head =
            trimmed.split(whereSeparator: { $0 == "/" || $0 == "(" }).first.map(String.init)
            ?? trimmed
        let word = head.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return nil }
        let upper = word.uppercased()
        return upper.count <= 18 ? upper : String(upper.prefix(16))
    }

    public var portalDisplay: String? {
        guard let portal else { return nil }
        let cleaned =
            portal
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    public var modifiedLabel: String {
        Ticket.dayFormatter.string(from: modified)
    }

    public func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        let haystack = [
            number, title, type ?? "", portal ?? "", status ?? "", summary, filename, body,
        ]
        .joined(separator: "\n")
        .lowercased()
        return haystack.contains(needle)
    }

    static func boardOrder(_ lhs: Ticket, _ rhs: Ticket) -> Bool {
        let left = lhs.numberParts
        let right = rhs.numberParts
        if left.isEmpty != right.isEmpty {
            return !left.isEmpty
        }
        let count = max(left.count, right.count)
        if count > 0 {
            for index in 0..<count {
                let lvalue = index < left.count ? left[index] : -1
                let rvalue = index < right.count ? right[index] : -1
                if lvalue != rvalue { return lvalue > rvalue }
            }
        }
        return lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}
