import AppKit

/// A bare executable is named after the binary, so the menu bar says "corkboard".
/// The application menu should use the product name.
enum AppMenuTitle {
    static let name = "Corkboard"

    static func apply() {
        guard let main = NSApp.mainMenu else { return }
        guard let item = main.items.first(where: isApplicationMenu) else { return }
        item.title = name
        guard let submenu = item.submenu else { return }
        submenu.title = name
        for entry in submenu.items {
            entry.title = entry.title.replacingOccurrences(of: "corkboard", with: name)
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
