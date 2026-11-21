import XCTest

@testable import CorkboardCore

final class BoardTests: XCTestCase {
    private var directories: [URL] = []

    override func tearDown() {
        for directory in directories {
            try? FileManager.default.removeItem(at: directory)
        }
        directories.removeAll()
        super.tearDown()
    }

    func testParsesHouseFormats() {
        let modern = """
            # #104 — Self-serve signup + Stripe (phase 2)

            **Portal**: Marketing site + admin / superadmin
            **Type**: Feature (phase 2)
            **Status**: Backlog (after domain; #88 SMTP still in progress)

            ## Summary
            Justin wants to **sell**: sign up from the marketing site, add a card.

            ## Notes
            - Depends on outbound email.
            """
        let ticket = parse(
            modern, filename: "#104-Self-Serve-Signup-And-Stripe.md", column: .backlog)
        XCTAssertEqual(ticket.number, "104")
        XCTAssertEqual(ticket.numberParts, [104])
        XCTAssertEqual(ticket.title, "Self-serve signup + Stripe (phase 2)")
        XCTAssertEqual(ticket.type, "Feature (phase 2)")
        XCTAssertEqual(ticket.stamp, "FEATURE")
        XCTAssertEqual(ticket.portal, "Marketing site + admin / superadmin")
        XCTAssertTrue(ticket.summary.hasPrefix("Justin wants to sell:"))
        XCTAssertFalse(ticket.summary.contains("**"))

        let dotted = """
            # #23.22 Post-Event Export

            **Status**: Complete

            ## Overview

            Build the admin **post-event export** page for a single event.
            """
        let child = parse(dotted, filename: "#23.22-Post-Event-Export.md", column: .done)
        XCTAssertEqual(child.number, "23.22")
        XCTAssertEqual(child.numberParts, [23, 22])
        XCTAssertEqual(child.title, "Post-Event Export")
        XCTAssertTrue(child.summary.contains("post-event export"))

        let prose = """
            # #88 — Production infrastructure: apply, encryption, backups, SMTP

            **Type**: Infrastructure / DevOps / Reliability
            **Status**: In progress — merged to `develop`

            ## Next session handoff

            Prod **app is live**. Do **not** recreate the VM.

            More detail follows.
            """
        let infra = parse(prose, filename: "#88-Prod.md", column: .inProgress)
        XCTAssertEqual(infra.stamp, "INFRASTRUCTURE")
        XCTAssertTrue(infra.summary.contains("app is live"))
        XCTAssertFalse(infra.summary.contains("More detail"))
    }

    func testSortsNewestNumberFirst() {
        let names = ["23", "23.9", "23.10", "104", "23.31"]
        let tickets = names.map { number in
            parse("# #\(number) — Item\n", filename: "#\(number)-Item.md", column: .done)
        }
        let ordered = tickets.sorted(by: Ticket.boardOrder).map(\.number)
        XCTAssertEqual(ordered, ["104", "23.31", "23.10", "23.9", "23"])
    }

    func testBoardReadsMovesAndCreatesWithoutChangingBytes() throws {
        let root = try makeRoot()
        let original = """
            # #12 — Keep the bytes

            **Type**: Bug
            **Status**: Todo

            ## Summary
            Dragging a note only changes its folder.

            ## Notes
            - [ ] Still open
            - [x] Parser sees this
            """
        let url = root.appendingPathComponent("todo/#12-Keep-The-Bytes.md")
        try original.write(to: url, atomically: true, encoding: .utf8)
        try "keep".write(
            to: root.appendingPathComponent("todo/placeholder.md"), atomically: true,
            encoding: .utf8)
        try "nope".write(
            to: root.appendingPathComponent("todo/notes.txt"), atomically: true, encoding: .utf8)

        let store = BoardStore()
        store.load(root: root)
        XCTAssertEqual(store.columns[.todo]?.map(\.filename), ["#12-Keep-The-Bytes.md"])
        XCTAssertEqual(store.columns[.backlog]?.count, 0)

        let before = try Data(contentsOf: url)
        store.move(filename: "#12-Keep-The-Bytes.md", to: .inProgress)
        let moved = root.appendingPathComponent("in-progress/#12-Keep-The-Bytes.md")
        XCTAssertEqual(try Data(contentsOf: moved), before)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(store.columns[.inProgress]?.first?.column, .inProgress)
        XCTAssertEqual(store.columns[.todo]?.isEmpty, true)

        store.move(filename: "#12-Keep-The-Bytes.md", to: .inProgress)
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path))

        let created = try store.create(
            title: "Self-serve signup",
            type: "Feature",
            summary: "Sell the product.",
            column: .backlog
        )
        XCTAssertEqual(created.number, "13")
        XCTAssertEqual(created.filename, "#13-Self-Serve-Signup.md")
        let body = try String(contentsOf: created.fileURL, encoding: .utf8)
        XCTAssertTrue(body.contains("# #13 — Self-serve signup"))
        XCTAssertTrue(body.contains("**Type**: Feature"))
        XCTAssertTrue(body.contains("**Status**: Backlog"))
        XCTAssertTrue(body.contains("Sell the product."))
        XCTAssertEqual(store.visible(.backlog).map(\.filename), ["#13-Self-Serve-Signup.md"])

        store.query = "bytes"
        XCTAssertEqual(store.visible(.inProgress).count, 1)
        XCTAssertEqual(store.visible(.backlog).count, 0)
    }

    func testFindsTicketsWalkingUpFromANestedDirectory() throws {
        let project = try makeDirectory()
        let tickets = project.appendingPathComponent("tickets")
        try FileManager.default.createDirectory(at: tickets, withIntermediateDirectories: true)
        for column in Column.allCases {
            try FileManager.default.createDirectory(
                at: tickets.appendingPathComponent(column.rawValue),
                withIntermediateDirectories: true)
        }
        let deep = project.appendingPathComponent("src/deep")
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)

        XCTAssertEqual(
            TicketRoot.resolve(project)?.resolvingSymlinksInPath().path,
            tickets.resolvingSymlinksInPath().path)
        XCTAssertEqual(
            TicketRoot.resolve(tickets)?.resolvingSymlinksInPath().path,
            tickets.resolvingSymlinksInPath().path)
        XCTAssertEqual(
            TicketRoot.resolve(tickets.appendingPathComponent("todo"))?.resolvingSymlinksInPath()
                .path,
            tickets.resolvingSymlinksInPath().path
        )
        XCTAssertEqual(
            TicketRoot.searchUp(from: deep)?.resolvingSymlinksInPath().path,
            tickets.resolvingSymlinksInPath().path)

        let store = BoardStore()
        store.bootstrap(currentDirectory: deep)
        XCTAssertEqual(
            store.root?.resolvingSymlinksInPath().path, tickets.resolvingSymlinksInPath().path)
        XCTAssertEqual(store.projectName, project.lastPathComponent)
    }

    func testMarkdownBlocks() {
        let source = """
            # Title

            Hello **there**.

            - [x] Done item
            - [ ] Open item

            ```bash
            echo hi
            ```

            | Host | Type |
            |------|------|
            | app | A |

            > A quote
            """
        let blocks = MarkdownDocument.parse(source)
        XCTAssertEqual(blocks.first, .heading(level: 1, text: "Title"))
        XCTAssertTrue(blocks.contains(.paragraph("Hello **there**.")))
        XCTAssertTrue(
            blocks.contains(
                .bullets([
                    MarkdownListItem(marker: "•", checked: true, text: "Done item"),
                    MarkdownListItem(marker: "•", checked: false, text: "Open item"),
                ])))
        XCTAssertTrue(blocks.contains(.code("echo hi")))
        XCTAssertTrue(blocks.contains(.table(header: ["Host", "Type"], rows: [["app", "A"]])))
        XCTAssertTrue(blocks.contains(.quote("A quote")))
    }

    func testRealTicketsFolderParsesWhenPresent() throws {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tickets = repo.appendingPathComponent("tickets")
        guard TicketRoot.isRoot(tickets) else { return }

        let store = BoardStore()
        store.load(root: tickets)
        XCTAssertGreaterThan(store.allTickets.count, 10)
        for ticket in store.allTickets {
            XCTAssertFalse(ticket.title.isEmpty, ticket.filename)
            XCTAssertNotEqual(ticket.filename.lowercased(), "placeholder.md")
        }
        XCTAssertEqual(store.projectName, repo.lastPathComponent)
    }

    private func parse(_ text: String, filename: String, column: Column) -> Ticket {
        TicketParser.parse(
            text: text,
            filename: filename,
            column: column,
            fileURL: URL(fileURLWithPath: "/tmp/\(filename)"),
            modified: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makeRoot() throws -> URL {
        let root = try makeDirectory()
        for column in Column.allCases {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(column.rawValue), withIntermediateDirectories: true)
        }
        return root
    }

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("corkboard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        directories.append(url)
        return url
    }
}
