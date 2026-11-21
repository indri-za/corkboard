import CorkboardCore
import SwiftUI

struct BoardView: View {
    @ObservedObject var store: BoardStore

    var body: some View {
        ZStack {
            WoodBackground()
            CorkFill()
                .padding(16)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)

            VStack(spacing: 0) {
                header
                if store.root == nil {
                    empty
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Column.allCases) { column in
                            ColumnView(store: store, column: column)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 18)
                }
            }

            if let ticket = store.selected {
                DetailOverlay(store: store, ticket: ticket)
                    .transition(.opacity)
            }

            if let column = store.creatingColumn {
                NewTicketSheet(store: store, column: column)
                    .transition(.opacity)
            }

            if let banner = store.banner {
                VStack {
                    Spacer()
                    Text(banner)
                        .font(skeuoFont("AmericanTypewriter-Bold", 15))
                        .foregroundStyle(Ink.brown)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(red: 1, green: 0.95, blue: 0.62))
                                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                        )
                        .padding(.bottom, 26)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .background(WindowChrome())
        .preferredColorScheme(.light)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: store.banner)
        .animation(.easeOut(duration: 0.16), value: store.selectedFilename)
        .animation(.easeOut(duration: 0.16), value: store.creatingColumn != nil)
        .task { await watchDisk() }
        .onExitCommand(perform: escape)
    }

    private var header: some View {
        ZStack {
            LeatherBar()
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Corkboard")
                        .font(skeuoFont("Noteworthy-Bold", 26))
                        .foregroundStyle(Ink.gold)
                        .shadow(color: .black.opacity(0.55), radius: 0, y: 1)
                        .shadow(color: .white.opacity(0.18), radius: 0, y: -1)
                    Text(subtitle)
                        .font(skeuoFont("HelveticaNeue-Medium", 10))
                        .tracking(1.5)
                        .foregroundStyle(Ink.gold.opacity(0.72))
                }
                Spacer()
                if store.root != nil {
                    search
                    RoundGlossButton(systemImage: "plus", colors: Gloss.green) {
                        store.selectedFilename = nil
                        store.creatingColumn = .todo
                    }
                    .help("New ticket  ⌘N")
                } else {
                    GlossyButton(title: "Open Project…", systemImage: "folder", colors: Gloss.blue)
                    {
                        ProjectOpener.open(store: store)
                    }
                }
            }
            .padding(.leading, 86)
            .padding(.trailing, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
        .frame(height: 78)
    }

    private var subtitle: String {
        if let name = store.projectName {
            return "BOARD  ·  \(name.uppercased())"
        }
        return "BOARD"
    }

    private var search: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.black.opacity(0.4))
            TextField("Search tickets", text: $store.query)
                .textFieldStyle(.plain)
                .font(skeuoFont("AmericanTypewriter", 14))
                .foregroundStyle(Ink.brown)
                .focusEffectDisabled()
            if !store.query.isEmpty {
                Button {
                    store.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.black.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(width: 280)
        .background(
            Capsule().fill(Color.white.opacity(0.94))
        )
        .overlay(
            Capsule().stroke(Color.black.opacity(0.28), lineWidth: 1)
        )
        .overlay(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.14), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
    }

    private var empty: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Text("Where are the tickets?")
                    .font(skeuoFont("Noteworthy-Bold", 30))
                    .foregroundStyle(Ink.brown)
                Text(
                    "This board reads a tickets folder — backlog, todo, in-progress, and done — from the directory you launched it in."
                )
                .font(skeuoFont("AmericanTypewriter", 15))
                .foregroundStyle(Ink.brown.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                Text(FileManager.default.currentDirectoryPath)
                    .font(skeuoFont("Menlo", 11))
                    .foregroundStyle(Ink.faded)
                    .lineLimit(2)
                    .truncationMode(.middle)
                GlossyButton(title: "Open Project…", systemImage: "folder", colors: Gloss.green) {
                    ProjectOpener.open(store: store)
                }
                .padding(.top, 4)
            }
            .padding(26)
            .frame(maxWidth: 520, alignment: .leading)
            .background(
                ZStack {
                    Color(red: 0.93, green: 0.86, blue: 0.68)
                    Image(nsImage: TextureCache.grain)
                        .resizable(resizingMode: .tile)
                        .blendMode(.multiply)
                        .opacity(0.25)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
            .rotationEffect(.degrees(-1.2))
            Spacer()
        }
    }

    private func escape() {
        if store.creatingColumn != nil {
            store.creatingColumn = nil
        } else if store.selectedFilename != nil {
            store.selectedFilename = nil
        } else if !store.query.isEmpty {
            store.query = ""
        }
    }

    private func watchDisk() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                break
            }
            store.refreshIfChanged()
        }
    }
}
