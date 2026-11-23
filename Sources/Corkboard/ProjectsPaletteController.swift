import AppKit
import CorkboardCore
import SwiftUI

/// Floating palette of favourite projects and recent boards. ⌘B shows and hides it.
/// It is not a document window: closing the board closes the palette too, so the
/// app still quits when the last board window closes.
final class ProjectsPaletteController: ObservableObject {
    @Published private(set) var isVisible = false

    private let store: BoardStore
    private let library: ProjectLibraryController
    private let defaults: UserDefaults
    private let frameName: String
    private var panel: NSPanel?
    private var observers: [NSObjectProtocol] = []

    init(
        store: BoardStore,
        library: ProjectLibraryController,
        defaults: UserDefaults = .standard,
        frameName: String = "corkboard.projectsPalette"
    ) {
        self.store = store
        self.library = library
        self.defaults = defaults
        self.frameName = frameName
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = ensurePanel()
        panel.orderFront(nil)
        isVisible = true
        rememberFrame()
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func open(root: URL) {
        let url = URL(fileURLWithPath: ProjectLibrary.key(for: root))
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            store.showBanner("That project is gone")
            return
        }
        guard TicketRoot.isRoot(url) else {
            store.showBanner("That folder has no tickets board")
            return
        }
        store.load(root: url)
        library.noteOpened(root: url)
        NSApp.activate(ignoringOtherApps: true)
        if let board = NSApp.windows.first(where: {
            $0 !== panel && $0.title == "Corkboard" && $0.isVisible
        }) {
            board.makeKeyAndOrderFront(nil)
        }
        panel?.orderFront(nil)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = makePanel()
        self.panel = panel
        observe(NSWindow.willCloseNotification, object: nil) { [weak self] notification in
            self?.windowWillClose(notification)
        }
        observe(NSWindow.didMoveNotification, object: panel) { [weak self] _ in
            self?.rememberFrame()
        }
        observe(NSWindow.didResizeNotification, object: panel) { [weak self] _ in
            self?.rememberFrame()
        }
        return panel
    }

    private func observe(
        _ name: Notification.Name, object: Any?, handler: @escaping (Notification) -> Void
    ) {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: name, object: object, queue: .main, using: handler))
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 560),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Projects"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        // A background drag fights the favourite reorder and creeps the panel along.
        // The leather header moves the panel itself.
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 280, height: 360)
        panel.backgroundColor = NSColor(srgbRed: 0.30, green: 0.17, blue: 0.08, alpha: 1)
        let host = NSHostingController(rootView: makeView())
        host.sizingOptions = []
        panel.contentViewController = host
        place(panel)
        return panel
    }

    private func makeView() -> ProjectsPaletteView {
        ProjectsPaletteView(
            store: store,
            library: library,
            onOpen: { [weak self] url in
                self?.open(root: url)
            },
            onHide: { [weak self] in
                self?.hide()
            }
        )
    }

    private func place(_ panel: NSPanel) {
        if let saved = defaults.string(forKey: frameDefaultsKey) {
            panel.setFrame(from: saved)
            return
        }
        positionBesideBoard(panel)
    }

    private func positionBesideBoard(_ panel: NSPanel) {
        var frame = panel.frame
        frame.size = NSSize(width: 320, height: 560)
        if let board = NSApp.windows.first(where: { $0.title == "Corkboard" && $0.isVisible }) {
            let boardFrame = board.frame
            frame.origin.x = boardFrame.maxX + 16
            frame.origin.y = boardFrame.maxY - frame.height
            let visible = (board.screen ?? NSScreen.main)?.visibleFrame
            if let visible {
                if frame.maxX > visible.maxX {
                    frame.origin.x = max(visible.minX + 12, boardFrame.minX - frame.width - 16)
                }
                if frame.minY < visible.minY {
                    frame.origin.y = visible.minY + 12
                }
                if frame.maxY > visible.maxY {
                    frame.origin.y = visible.maxY - frame.height
                }
            }
        } else {
            frame.origin = .zero
        }
        panel.setFrame(frame, display: false)
        if frame.origin == .zero {
            panel.center()
        }
    }

    private var frameDefaultsKey: String {
        "NSWindow Frame \(frameName)"
    }

    private func rememberFrame() {
        guard let panel else { return }
        defaults.set(panel.frameDescriptor, forKey: frameDefaultsKey)
    }

    private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === panel {
            isVisible = false
            return
        }
        guard window.title == "Corkboard" else { return }
        let otherBoards = NSApp.windows.contains { candidate in
            candidate !== window && candidate.title == "Corkboard" && candidate.isVisible
        }
        if !otherBoards {
            panel?.close()
        }
    }
}
