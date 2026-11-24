import AppKit

/// A bare executable is named after the binary, so the menu bar says "corkboard".
/// The application menu should use the product name.
enum AppMenuTitle {
    static let name = "Corkboard"
    private static var applying = false
    private static var scheduled = false

    /// SwiftUI rebuilds the menus when the board changes and writes the binary name back.
    /// Apply again, and once more on the next turn, without looping on our own edits.
    static func schedule() {
        apply()
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async {
            scheduled = false
            apply()
        }
    }

    static func apply() {
        guard !applying else { return }
        applying = true
        defer { applying = false }
        guard let main = NSApp.mainMenu else { return }
        guard let item = main.items.first(where: isApplicationMenu) else { return }
        if item.title != name {
            item.title = name
        }
        guard let submenu = item.submenu else { return }
        if submenu.title != name {
            submenu.title = name
        }
        for entry in submenu.items {
            let renamed = entry.title.replacingOccurrences(of: "corkboard", with: name)
            if renamed != entry.title {
                entry.title = renamed
            }
        }
    }

    private static func isApplicationMenu(_ item: NSMenuItem) -> Bool {
        if item.title.compare(name, options: [.caseInsensitive, .diacriticInsensitive])
            == .orderedSame
        {
            return true
        }
        return item.submenu?.items.contains { entry in
            entry.title.range(of: "corkboard", options: [.caseInsensitive]) != nil
        } == true
    }
}
