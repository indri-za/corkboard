import Foundation

public enum TicketRoot {
    /// A tickets root contains at least one of the column folders.
    public static func isRoot(_ url: URL) -> Bool {
        let directory = url.standardizedFileURL
        var isDirectory = ObjCBool(false)
        let path = directory.path
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            return false
        }
        return Column.allCases.contains { column in
            var columnIsDirectory = ObjCBool(false)
            let columnPath = directory.appendingPathComponent(column.rawValue).path
            return FileManager.default.fileExists(
                atPath: columnPath, isDirectory: &columnIsDirectory)
                && columnIsDirectory.boolValue
        }
    }

    /// Accept a tickets folder, a project folder that contains `tickets/`, or a single column folder.
    public static func resolve(_ url: URL) -> URL? {
        let directory = url.standardizedFileURL
        if isRoot(directory) {
            return directory
        }
        let nested = directory.appendingPathComponent("tickets")
        if isRoot(nested) {
            return nested
        }
        if Column(rawValue: directory.lastPathComponent) != nil {
            let parent = directory.deletingLastPathComponent()
            if isRoot(parent) {
                return parent
            }
        }
        return nil
    }

    /// Walk from `start` toward the filesystem root. The nearest match wins.
    public static func searchUp(from start: URL) -> URL? {
        var current = start.standardizedFileURL
        for _ in 0..<16 {
            if let found = resolve(current) {
                return found
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }
        return nil
    }

    /// The folder a person would recognise. A `tickets` directory is named after its parent.
    public static func projectName(forRoot root: URL) -> String {
        let root = root.standardizedFileURL
        if root.lastPathComponent == "tickets" {
            let parent = root.deletingLastPathComponent().lastPathComponent
            if parent.isEmpty || parent == "/" {
                return "tickets"
            }
            return parent
        }
        return root.lastPathComponent
    }
}
