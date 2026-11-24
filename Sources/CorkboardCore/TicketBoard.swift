import Foundation

public enum TicketBoardError: LocalizedError, Equatable {
    case filesystemRoot
    case missingDirectory(String)
    case notADirectory(String)
    case blockedColumn(String)

    public var errorDescription: String? {
        switch self {
        case .filesystemRoot:
            return "Choose a project folder before creating a board."
        case .missingDirectory(let path):
            return "That folder doesn't exist (\(path))."
        case .notADirectory(let path):
            return "That path is not a folder (\(path))."
        case .blockedColumn(let name):
            return "A file named \(name) is where a column folder should be."
        }
    }
}

/// Creates the `tickets/` column folders and the placeholder file Git keeps.
public enum TicketBoard {
    public static let placeholderFilename = "placeholder.md"
    public static let placeholderText =
        "<!-- Keeps this column in git when it has no tickets. The board does not show this file. -->\n"

    /// Makes a board in `directory`, or inside `directory/tickets` when that is the project folder.
    /// Files that are already there are left alone. Returns the tickets root.
    public static func create(in directory: URL) throws -> URL {
        let directory = directory.standardizedFileURL
        if directory.path == "/" {
            throw TicketBoardError.filesystemRoot
        }
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory)
        else {
            throw TicketBoardError.missingDirectory(directory.path)
        }
        guard isDirectory.boolValue else {
            throw TicketBoardError.notADirectory(directory.path)
        }

        let root = columnRoot(for: directory)
        let manager = FileManager.default
        for column in Column.allCases {
            let folder = root.appendingPathComponent(column.rawValue)
            var columnIsDirectory = ObjCBool(false)
            if manager.fileExists(atPath: folder.path, isDirectory: &columnIsDirectory) {
                guard columnIsDirectory.boolValue else {
                    throw TicketBoardError.blockedColumn(column.rawValue)
                }
            } else {
                try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            let placeholder = folder.appendingPathComponent(placeholderFilename)
            if !manager.fileExists(atPath: placeholder.path) {
                try placeholderText.write(to: placeholder, atomically: true, encoding: .utf8)
            }
        }
        return root
    }

    private static func columnRoot(for directory: URL) -> URL {
        if TicketRoot.isRoot(directory) || directory.lastPathComponent == "tickets" {
            return directory
        }
        return directory.appendingPathComponent("tickets")
    }
}
