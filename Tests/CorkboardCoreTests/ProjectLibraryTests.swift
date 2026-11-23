import XCTest

@testable import CorkboardCore

final class ProjectLibraryTests: XCTestCase {
    func testProjectNameComesFromTheParentOfTickets() {
        XCTAssertEqual(
            TicketRoot.projectName(forRoot: URL(fileURLWithPath: "/work/corkboard/tickets")),
            "corkboard")
        XCTAssertEqual(
            TicketRoot.projectName(forRoot: URL(fileURLWithPath: "/work/board")),
            "board")
        XCTAssertEqual(
            TicketRoot.projectName(forRoot: URL(fileURLWithPath: "/tickets")),
            "tickets")
    }

    func testKeyCollapsesTheTemporaryDirectorySymlink() throws {
        let name = "corkboard-key-\(UUID().uuidString)"
        let viaTmp = URL(fileURLWithPath: "/tmp/\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: viaTmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: viaTmp) }
        let viaPrivate = URL(fileURLWithPath: "/private/tmp/\(name)", isDirectory: true)
        XCTAssertEqual(ProjectLibrary.key(for: viaTmp), ProjectLibrary.key(for: viaPrivate))
    }

    func testLocationLabelUsesTheProjectDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(
            ProjectLibrary.locationLabel(forStoredPath: home + "/development/corkboard/tickets"),
            "~/development/corkboard")
        XCTAssertEqual(
            ProjectLibrary.locationLabel(forStoredPath: home + "/development/board"),
            "~/development/board")
    }

    func testOpeningMovesAProjectToTheFrontWithoutDuplicatingIt() {
        var library = ProjectLibrary()
        let first = URL(fileURLWithPath: "/private/tmp/one/tickets")
        let second = URL(fileURLWithPath: "/private/tmp/two/tickets")
        library.noteOpened(root: first, at: Date(timeIntervalSince1970: 10))
        library.noteOpened(root: second, at: Date(timeIntervalSince1970: 20))
        library.noteOpened(root: first, at: Date(timeIntervalSince1970: 30))
        XCTAssertEqual(library.recents.map(\.name), ["one", "two"])
        XCTAssertEqual(library.recents.first?.openedAt, Date(timeIntervalSince1970: 30))
    }

    func testPinningHidesAProjectFromRecentsUntilItIsUnpinned() {
        var library = ProjectLibrary()
        let first = URL(fileURLWithPath: "/private/tmp/one/tickets")
        let second = URL(fileURLWithPath: "/private/tmp/two/tickets")
        library.noteOpened(root: first, at: Date(timeIntervalSince1970: 10))
        library.noteOpened(root: second, at: Date(timeIntervalSince1970: 20))
        library.pin(root: first)
        library.pin(root: first, at: Date(timeIntervalSince1970: 99))
        XCTAssertEqual(library.favourites.map(\.name), ["one"])
        XCTAssertEqual(library.displayedRecents.map(\.name), ["two"])

        library.pin(root: second)
        XCTAssertEqual(library.favourites.map(\.name), ["one", "two"])
        XCTAssertTrue(library.displayedRecents.isEmpty)

        library.noteOpened(root: second, at: Date(timeIntervalSince1970: 40))
        XCTAssertEqual(library.favourites.map(\.name), ["one", "two"])
        XCTAssertEqual(library.favourites[1].openedAt, Date(timeIntervalSince1970: 40))

        library.unpin(path: ProjectLibrary.key(for: first))
        XCTAssertEqual(library.favourites.map(\.name), ["two"])
        XCTAssertEqual(library.displayedRecents.map(\.name), ["one"])
    }

    func testRemoveDropsThePathFromBothLists() {
        var library = ProjectLibrary()
        let root = URL(fileURLWithPath: "/private/tmp/one/tickets")
        library.noteOpened(root: root, at: Date(timeIntervalSince1970: 10))
        library.pin(root: root)
        library.remove(path: ProjectLibrary.key(for: root))
        XCTAssertTrue(library.favourites.isEmpty)
        XCTAssertTrue(library.recents.isEmpty)
    }

    func testRecentCapKeepsPinnedProjectsAndTheNewestUnpinnedBoards() {
        var library = ProjectLibrary()
        let pinned = URL(fileURLWithPath: "/private/tmp/pinned/tickets")
        library.noteOpened(root: pinned, at: Date(timeIntervalSince1970: 1))
        library.pin(root: pinned)
        for index in 0..<13 {
            library.noteOpened(
                root: URL(fileURLWithPath: "/private/tmp/recent-\(index)/tickets"),
                at: Date(timeIntervalSince1970: TimeInterval(10 + index))
            )
        }
        XCTAssertEqual(library.favourites.map(\.name), ["pinned"])
        XCTAssertEqual(library.displayedRecents.count, ProjectLibrary.recentLimit)
        XCTAssertEqual(library.displayedRecents.first?.name, "recent-12")
        XCTAssertFalse(library.displayedRecents.contains { $0.name == "recent-0" })
        XCTAssertFalse(library.displayedRecents.contains { $0.name == "pinned" })
        XCTAssertTrue(library.recents.contains { $0.name == "pinned" })

        library.unpin(path: ProjectLibrary.key(for: pinned))
        XCTAssertTrue(library.favourites.isEmpty)
        XCTAssertEqual(library.displayedRecents.count, ProjectLibrary.recentLimit)
        XCTAssertFalse(library.recents.contains { $0.name == "pinned" })
    }

    func testReordersFavourites() {
        var library = ProjectLibrary()
        let paths = ["a", "b", "c"].map { URL(fileURLWithPath: "/private/tmp/\($0)/tickets") }
        for path in paths {
            library.pin(root: path)
        }
        library.moveFavourite(
            ProjectLibrary.key(for: paths[2]), before: ProjectLibrary.key(for: paths[0]))
        XCTAssertEqual(library.favourites.map(\.name), ["c", "a", "b"])
        library.moveFavourite(ProjectLibrary.key(for: paths[0]), before: nil)
        XCTAssertEqual(library.favourites.map(\.name), ["c", "b", "a"])

        let snapshot = library.favourites
        library.moveFavourite(
            ProjectLibrary.key(for: paths[0]), before: ProjectLibrary.key(for: paths[0]))
        library.moveFavourite("/missing", before: nil)
        XCTAssertEqual(library.favourites, snapshot)
    }

    func testStoreRoundTripsAndIgnoresCorruptData() {
        let name = "corkboard-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        var library = ProjectLibrary()
        library.noteOpened(
            root: URL(fileURLWithPath: "/private/tmp/alpha/tickets"),
            at: Date(timeIntervalSince1970: 50))
        library.pin(root: URL(fileURLWithPath: "/private/tmp/alpha/tickets"))
        ProjectLibraryStore.save(library, to: defaults)

        let loaded = ProjectLibraryStore.load(from: defaults)
        XCTAssertEqual(loaded.favourites.map(\.name), ["alpha"])
        XCTAssertTrue(loaded.displayedRecents.isEmpty)
        XCTAssertEqual(loaded.recents.map(\.name), ["alpha"])
        XCTAssertEqual(loaded.recents.first?.openedAt, Date(timeIntervalSince1970: 50))

        defaults.set(Data("nope".utf8), forKey: ProjectLibraryStore.defaultsKey)
        XCTAssertEqual(ProjectLibraryStore.load(from: defaults), ProjectLibrary())
    }

    func testControllerReloadsWhatItSaved() {
        let name = "corkboard-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        let controller = ProjectLibraryController(defaults: defaults)
        let root = URL(fileURLWithPath: "/private/tmp/alpha/tickets")
        controller.noteOpened(root: root, at: Date(timeIntervalSince1970: 50))
        controller.pin(root: root)

        let again = ProjectLibraryController(defaults: defaults)
        XCTAssertEqual(again.library.favourites.map(\.name), ["alpha"])
        XCTAssertTrue(again.library.displayedRecents.isEmpty)
        XCTAssertEqual(again.library.recents.map(\.name), ["alpha"])
    }
}
