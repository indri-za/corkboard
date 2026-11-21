import AppKit
import CorkboardCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = AppIcon.render()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct CorkboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = BoardStore()
    @State private var didBoot = false

    var body: some Scene {
        WindowGroup {
            BoardView(store: store)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear(perform: boot)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Ticket") {
                    store.selectedFilename = nil
                    store.creatingColumn = store.creatingColumn ?? .todo
                }
                .keyboardShortcut("n")
                .disabled(store.root == nil)
                Button("Open Project…") {
                    ProjectOpener.open(store: store)
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
    }
}
