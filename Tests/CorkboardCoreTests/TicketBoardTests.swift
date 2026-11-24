import XCTest

@testable import CorkboardCore

final class TicketBoardTests: XCTestCase {
    private var directories: [URL] = []

    override func tearDown() {
        for directory in directories {
            try? FileManager.default.removeItem(at: directory)
        }
        directories.removeAll()
        super.tearDown()
    }

    func testCreateMakesColumnFoldersAndPlaceholders() throws {
        let project = try makeDirectory()
        let root = try TicketBoard.create(in: project)
        XCTAssertEqual(root.lastPathComponent, "tickets")
        XCTAssertTrue(TicketRoot.isRoot(root))
        for column in Column.allCases {
            let placeholder = root.appendingPathComponent(column.rawValue)
                .appendingPathComponent(TicketBoard.placeholderFilename)
            let text = try String(contentsOf: placeholder, encoding: .utf8)
            XCTAssertEqual(text, TicketBoard.placeholderText)
        }
    }

    func testCreateAgainLeavesAnExistingTicketAlone() throws {
        let project = try makeDirectory()
        let root = try TicketBoard.create(in: project)
        let ticket = root.appendingPathComponent("todo/#1-Hello.md")
        try "hello".write(to: ticket, atomically: true, encoding: .utf8)
        let again = try TicketBoard.create(in: project)
        XCTAssertEqual(folderPath(again), folderPath(root))
        XCTAssertEqual(try String(contentsOf: ticket, encoding: .utf8), "hello")
        XCTAssertTrue(FileManager.default.fileExists(atPath: ticket.path))
    }

    func testCreateInsideAnExistingTicketsFolderFillsMissingColumns() throws {
        let project = try makeDirectory()
        let tickets = project.appendingPathComponent("tickets")
        try FileManager.default.createDirectory(
            at: tickets.appendingPathComponent("todo"), withIntermediateDirectories: true)
        let root = try TicketBoard.create(in: tickets)
        XCTAssertEqual(folderPath(root), folderPath(tickets))
        XCTAssertTrue(TicketRoot.isRoot(root))
    }

    func testCreateRefusesTheFilesystemRootAndAMissingFolder() {
        XCTAssertThrowsError(try TicketBoard.create(in: URL(fileURLWithPath: "/"))) { error in
            XCTAssertEqual(error as? TicketBoardError, .filesystemRoot)
        }
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(
            "corkboard-missing-\(UUID().uuidString)")
        XCTAssertThrowsError(try TicketBoard.create(in: missing)) { error in
            XCTAssertEqual(
                error as? TicketBoardError, .missingDirectory(missing.standardizedFileURL.path))
        }
    }

    func testCreateRefusesAFileBlockingAColumn() throws {
        let project = try makeDirectory()
        let tickets = project.appendingPathComponent("tickets")
        try FileManager.default.createDirectory(at: tickets, withIntermediateDirectories: true)
        try "nope".write(
            to: tickets.appendingPathComponent("todo"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try TicketBoard.create(in: project)) { error in
            XCTAssertEqual(error as? TicketBoardError, .blockedColumn("todo"))
        }
    }

    private func folderPath(_ url: URL) -> String {
        var path = url.resolvingSymlinksInPath().path
        if path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "corkboard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        directories.append(url)
        return url
    }
}
