import Combine
import Foundation

public enum BoardError: LocalizedError, Equatable {
    case noBoard
    case emptyTitle
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noBoard:
            return "Open a tickets folder first."
        case .emptyTitle:
            return "Give the ticket a title."
        case .writeFailed(let message):
            return message
        }
    }
}

public final class BoardStore: ObservableObject {
    @Published public private(set) var root: URL?
    @Published public private(set) var columns: [Column: [Ticket]]
    @Published public var query: String = ""
    @Published public var banner: String?
    @Published public var selectedFilename: String?
    @Published public var creatingColumn: Column?

    public var projectName: String? {
        guard let root else { return nil }
        if root.lastPathComponent == "tickets" {
            let parent = root.deletingLastPathComponent().lastPathComponent
            return parent.isEmpty ? "tickets" : parent
        }
        return root.lastPathComponent
    }

    public var selected: Ticket? {
        guard let selectedFilename else { return nil }
        return allTickets.first { $0.filename == selectedFilename }
    }

    public var allTickets: [Ticket] {
        Column.allCases.flatMap { columns[$0] ?? [] }
    }

    private var signature = ""
    private var bannerToken = 0

    public init() {
        columns = Dictionary(uniqueKeysWithValues: Column.allCases.map { ($0, []) })
    }

    public func bootstrap(
        currentDirectory: URL, arguments: [String] = [], environment: [String: String] = [:]
    ) {
        let positional = arguments.first { argument in
            !argument.hasPrefix("-") && argument != "--"
        }
        if let positional {
            let url = URL(fileURLWithPath: positional, relativeTo: currentDirectory)
                .standardizedFileURL
            if let root = TicketRoot.resolve(url) {
                load(root: root)
                return
            }
        }
        if let env = environment["CORKBOARD_TICKETS"] ?? environment["CORKBOARD_ROOT"], !env.isEmpty
        {
            if let root = TicketRoot.resolve(URL(fileURLWithPath: env)) {
                load(root: root)
                return
            }
        }
        if let root = TicketRoot.searchUp(from: currentDirectory) {
            load(root: root)
            return
        }
        self.root = nil
        self.columns = Dictionary(uniqueKeysWithValues: Column.allCases.map { ($0, []) })
        signature = ""
    }

    public func load(root: URL) {
        let resolved = root.standardizedFileURL
        self.root = resolved
        var grouped = Dictionary(uniqueKeysWithValues: Column.allCases.map { ($0, [Ticket]()) })
        let manager = FileManager.default
        for column in Column.allCases {
            let directory = resolved.appendingPathComponent(column.rawValue)
            guard
                let urls = try? manager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
            else { continue }
            for url in urls {
                let name = url.lastPathComponent
                guard name.lowercased().hasSuffix(".md") else { continue }
                guard name.lowercased() != "placeholder.md" else { continue }
                var isDirectory = ObjCBool(false)
                if manager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                    isDirectory.boolValue
                {
                    continue
                }
                grouped[column, default: []].append(
                    TicketParser.parse(fileURL: url, column: column))
            }
            grouped[column] = (grouped[column] ?? []).sorted(by: Ticket.boardOrder)
        }
        columns = grouped
        signature = computeSignature()
        if let selectedFilename, !allTickets.contains(where: { $0.filename == selectedFilename }) {
            self.selectedFilename = nil
        }
    }

    public func reload() {
        guard let root else { return }
        load(root: root)
    }

    public func refreshIfChanged() {
        guard root != nil else { return }
        let next = computeSignature()
        if next != signature {
            reload()
        }
    }

    public func visible(_ column: Column) -> [Ticket] {
        let items = columns[column] ?? []
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter { $0.matches(needle) }
    }

    public func nextNumber() -> Int {
        let majors = allTickets.compactMap(\.numberParts.first)
        return (majors.max() ?? 0) + 1
    }

    public func move(filename: String, to column: Column) {
        guard let root else { return }
        guard let ticket = allTickets.first(where: { $0.filename == filename }) else { return }
        guard ticket.column != column else { return }
        let destinationDirectory = root.appendingPathComponent(column.rawValue)
        let destination = destinationDirectory.appendingPathComponent(ticket.filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            showBanner("\(ticket.filename) is already in \(column.title)")
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: destinationDirectory, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: ticket.fileURL, to: destination)
            showBanner("Moved \(ticket.displayNumber) to \(column.title)")
            reload()
        } catch {
            showBanner("Couldn't move \(ticket.displayNumber)")
        }
    }

    @discardableResult
    public func create(title: String, type: String, summary: String, column: Column) throws
        -> Ticket
    {
        guard let root else { throw BoardError.noBoard }
        let cleanTitle =
            title
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw BoardError.emptyTitle }
        let number = nextNumber()
        let filename = uniqueFilename(number: number, slug: Self.slug(cleanTitle), root: root)
        let body = Self.template(
            number: number,
            title: cleanTitle,
            type: type.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            column: column
        )
        let directory = root.appendingPathComponent(column.rawValue)
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try body.write(
                to: directory.appendingPathComponent(filename), atomically: true, encoding: .utf8)
        } catch {
            throw BoardError.writeFailed(error.localizedDescription)
        }
        reload()
        showBanner("Added #\(number)")
        guard let ticket = allTickets.first(where: { $0.filename == filename }) else {
            throw BoardError.writeFailed("Saved \(filename), but it didn't show up on the board.")
        }
        return ticket
    }

    public func showBanner(_ text: String) {
        bannerToken += 1
        let token = bannerToken
        banner = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            guard let self, self.bannerToken == token else { return }
            self.banner = nil
        }
    }

    private func computeSignature() -> String {
        guard let root else { return "" }
        var parts: [String] = []
        let manager = FileManager.default
        for column in Column.allCases {
            let directory = root.appendingPathComponent(column.rawValue)
            let urls =
                (try? manager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
            for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let values = try? url.resourceValues(forKeys: [
                    .contentModificationDateKey, .fileSizeKey,
                ])
                let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
                let size = values?.fileSize ?? 0
                parts.append("\(column.rawValue)/\(url.lastPathComponent):\(modified):\(size)")
            }
        }
        return parts.joined(separator: "|")
    }

    private func uniqueFilename(number: Int, slug: String, root: URL) -> String {
        func candidate(_ suffix: String) -> String { "#\(number)-\(slug)\(suffix).md" }
        var name = candidate("")
        var extra = 2
        let taken = Set(allTickets.map(\.filename))
        while taken.contains(name) || fileExists(name, root: root) {
            name = candidate("-\(extra)")
            extra += 1
            if extra > 40 { break }
        }
        return name
    }

    private func fileExists(_ filename: String, root: URL) -> Bool {
        Column.allCases.contains { column in
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent(column.rawValue).appendingPathComponent(
                    filename
                ).path
            )
        }
    }

    static func slug(_ title: String) -> String {
        let words = title.split { character in
            !character.isLetter && !character.isNumber
        }.map { part -> String in
            let lower = part.lowercased()
            guard let first = lower.first else { return "" }
            return String(first).uppercased() + lower.dropFirst()
        }.filter { !$0.isEmpty }
        let joined = words.joined(separator: "-")
        if joined.isEmpty { return "Ticket" }
        if joined.count <= 48 { return joined }
        let clipped = String(joined.prefix(48))
        return clipped.hasSuffix("-") ? String(clipped.dropLast()) : clipped
    }

    private static func template(
        number: Int, title: String, type: String, summary: String, column: Column
    ) -> String {
        var lines = ["# #\(number) — \(title)", ""]
        if !type.isEmpty {
            lines.append("**Type**: \(type)")
        }
        lines.append("**Status**: \(column.statusLabel)")
        lines.append("")
        lines.append("## Summary")
        lines.append(summary)
        lines.append("")
        lines.append("## Notes")
        lines.append("- ")
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
