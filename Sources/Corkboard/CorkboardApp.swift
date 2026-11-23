import AppKit
import CorkboardCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // A bare executable starts as an accessory. Promote it before SwiftUI
        // makes the board window. Doing this later closes that window.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = AppIcon.render()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct CorkboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store: BoardStore
    @StateObject private var library: ProjectLibraryController
    @StateObject private var palette: ProjectsPaletteController
    @State private var didBoot = false

    init() {
        let store = BoardStore()
        // A private suite lets a second instance exercise the palette without writing
        // over the user's favourites. It is never read to choose a board.
        let environment = ProcessInfo.processInfo.environment
        let defaults: UserDefaults
        let frameName: String
        if let suite = environment["CORKBOARD_DEFAULTS_SUITE"], !suite.isEmpty,
            let privateDefaults = UserDefaults(suiteName: suite)
        {
            defaults = privateDefaults
            frameName = "corkboard.projectsPalette.\(suite)"
        } else {
            defaults = .standard
            frameName = "corkboard.projectsPalette"
        }
        let library = ProjectLibraryController(defaults: defaults)
        let palette = ProjectsPaletteController(
            store: store, library: library, defaults: defaults, frameName: frameName)
        _store = StateObject(wrappedValue: store)
        _library = StateObject(wrappedValue: library)
        _palette = StateObject(wrappedValue: palette)
    }

    var body: some Scene {
        WindowGroup {
            BoardView(store: store, library: library, palette: palette)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear(perform: boot)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 840)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Corkboard") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Corkboard",
                        .applicationVersion: CorkboardVersion.current,
                        .applicationIcon: AppIcon.render(),
                    ])
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    UpdatePrompt.check()
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Ticket") {
                    store.selectedFilename = nil
                    store.creatingColumn = store.creatingColumn ?? .todo
                }
                .keyboardShortcut("n")
                .disabled(store.root == nil)
                Button("Open Project…") {
                    ProjectOpener.open(store: store, library: library)
                }
                .keyboardShortcut("o")
                Button("Reload Board") {
                    store.reload()
                }
                .keyboardShortcut("r")
                .disabled(store.root == nil)
                Button("Show Tickets in Finder") {
                    if let root = store.root {
                        TicketActions.reveal(root)
                    }
                }
                .disabled(store.root == nil)
            }
            CommandGroup(after: .sidebar) {
                Button(palette.isVisible ? "Hide Projects" : "Show Projects") {
                    palette.toggle()
                }
                .keyboardShortcut("b")
            }
        }
    }

    private func boot() {
        guard !didBoot else { return }
        didBoot = true
        store.bootstrap(
            currentDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            arguments: Array(CommandLine.arguments.dropFirst()),
            environment: ProcessInfo.processInfo.environment
        )
        // The palette records the board that opened. It is not consulted here.
        if let root = store.root {
            library.noteOpened(root: root)
        }
    }
}
