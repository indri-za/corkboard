import Combine
import Foundation

/// A project the palette can open again. `path` is the tickets directory, symlink-resolved.
public struct ProjectBookmark: Codable, Equatable, Identifiable {
    public var path: String
    public var name: String
    public var openedAt: Date

    public var id: String { path }

    public init(path: String, name: String, openedAt: Date) {
        self.path = path
        self.name = name
        self.openedAt = openedAt
    }
}

/// Favourites in the order the user arranged them, and boards opened recently.
/// Launch never reads this to choose a folder.
public struct ProjectLibrary: Codable, Equatable {
    public static let recentLimit = 12

    public var favourites: [ProjectBookmark]
    public var recents: [ProjectBookmark]

    public init(favourites: [ProjectBookmark] = [], recents: [ProjectBookmark] = []) {
        self.favourites = favourites
        self.recents = recents
    }

    /// Recents that are not already pinned, newest first.
    public var displayedRecents: [ProjectBookmark] {
        let pinned = Set(favourites.map(\.path))
        return recents.filter { !pinned.contains($0.path) }
    }

    public func isFavourite(path: String) -> Bool {
        favourites.contains { $0.path == path }
    }

    public static func key(for root: URL) -> String {
        root.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// `~/project` for a `tickets` directory, otherwise the board directory itself.
    public static func locationLabel(forStoredPath path: String) -> String {
        let stored = path as NSString
        let shown = stored.lastPathComponent == "tickets" ? stored.deletingLastPathComponent : path
        return (shown as NSString).abbreviatingWithTildeInPath
    }

    public mutating func noteOpened(root: URL, at date: Date = Date()) {
        let path = Self.key(for: root)
        let name = TicketRoot.projectName(forRoot: URL(fileURLWithPath: path))
        recents.removeAll { $0.path == path }
        recents.insert(ProjectBookmark(path: path, name: name, openedAt: date), at: 0)
        if let index = favourites.firstIndex(where: { $0.path == path }) {
            favourites[index].name = name
            favourites[index].openedAt = date
        }
        trimRecents()
    }

    /// Appends a pin. A second pin of the same path leaves the order alone.
    public mutating func pin(root: URL, at date: Date = Date()) {
        let path = Self.key(for: root)
        guard !favourites.contains(where: { $0.path == path }) else { return }
        let name = TicketRoot.projectName(forRoot: URL(fileURLWithPath: path))
        let opened = recents.first { $0.path == path }?.openedAt ?? date
        favourites.append(ProjectBookmark(path: path, name: name, openedAt: opened))
    }

    public mutating func unpin(path: String) {
        favourites.removeAll { $0.path == path }
        trimRecents()
    }

    /// Drops the path from both lists so it does not reappear under Recents.
    public mutating func remove(path: String) {
        favourites.removeAll { $0.path == path }
        recents.removeAll { $0.path == path }
    }

    /// Moves a favourite to sit just before `before`, or to the end when `before` is nil.
    public mutating func moveFavourite(_ path: String, before other: String?) {
        guard let from = favourites.firstIndex(where: { $0.path == path }) else { return }
        if let other {
            guard path != other, favourites.contains(where: { $0.path == other }) else { return }
        }
        let item = favourites.remove(at: from)
        if let other, let destination = favourites.firstIndex(where: { $0.path == other }) {
            favourites.insert(item, at: destination)
        } else {
            favourites.append(item)
        }
    }

    /// Pinned paths do not count towards the recent limit, so a long favourite list
    /// cannot push a real recent off the palette.
    private mutating func trimRecents() {
        let pinned = Set(favourites.map(\.path))
        var unpinnedKept = 0
        recents = recents.filter { bookmark in
            if pinned.contains(bookmark.path) {
                return true
            }
            guard unpinnedKept < Self.recentLimit else { return false }
            unpinnedKept += 1
            return true
        }
    }
}

public enum ProjectLibraryStore {
    public static let defaultsKey = "corkboard.projectLibrary"

    public static func load(
        from defaults: UserDefaults, key: String = defaultsKey
    ) -> ProjectLibrary {
        guard let data = defaults.data(forKey: key) else { return ProjectLibrary() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ProjectLibrary.self, from: data)) ?? ProjectLibrary()
    }

    public static func save(
        _ library: ProjectLibrary, to defaults: UserDefaults, key: String = defaultsKey
    ) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(library) else { return }
        defaults.set(data, forKey: key)
    }
}

public final class ProjectLibraryController: ObservableObject {
    @Published public private(set) var library: ProjectLibrary
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = ProjectLibraryStore.defaultsKey) {
        self.defaults = defaults
        self.key = key
        library = ProjectLibraryStore.load(from: defaults, key: key)
    }

    public func noteOpened(root: URL, at date: Date = Date()) {
        library.noteOpened(root: root, at: date)
        persist()
    }

    public func pin(root: URL, at date: Date = Date()) {
        library.pin(root: root, at: date)
        persist()
    }

    public func unpin(path: String) {
        library.unpin(path: path)
        persist()
    }

    public func remove(path: String) {
        library.remove(path: path)
        persist()
    }

    public func moveFavourite(_ path: String, before other: String?) {
        library.moveFavourite(path, before: other)
        persist()
    }

    private func persist() {
        ProjectLibraryStore.save(library, to: defaults, key: key)
    }
}
