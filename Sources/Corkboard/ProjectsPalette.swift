import CorkboardCore
import SwiftUI
import UniformTypeIdentifiers

struct ProjectsPaletteView: View {
    @ObservedObject var store: BoardStore
    @ObservedObject var library: ProjectLibraryController
    var onOpen: (URL) -> Void
    var onHide: () -> Void

    @State private var dropBefore: String?
    @State private var dropAtEnd = false

    var body: some View {
        ZStack {
            WoodBackground()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        favourites
                        recents
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .accessibilityIdentifier("projects-palette")
        .onExitCommand(perform: onHide)
    }

    private var header: some View {
        ZStack {
            LeatherBar()
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Projects")
                        .font(skeuoFont("Noteworthy-Bold", 22))
                        .foregroundStyle(Ink.gold)
                        .shadow(color: .black.opacity(0.55), radius: 0, y: 1)
                    Text(subtitle)
                        .font(skeuoFont("HelveticaNeue-Medium", 10))
                        .tracking(1.2)
                        .foregroundStyle(Ink.gold.opacity(0.72))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if store.root != nil {
                    GlossyButton(
                        title: currentIsPinned ? "Unpin" : "Pin",
                        systemImage: "pin",
                        colors: currentIsPinned ? Gloss.slate : Gloss.amber,
                        foreground: currentIsPinned ? Ink.brown : .white
                    ) {
                        toggleCurrentPin()
                    }
                    .help(
                        currentIsPinned
                            ? "Remove this board from favourites" : "Pin this board to favourites")
                }
            }
            .padding(.leading, 70)
            .padding(.trailing, 12)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .frame(height: 72)
    }

    private var subtitle: String {
        if let name = store.projectName {
            return "OPEN  ·  \(name.uppercased())"
        }
        return "FAVOURITES  ·  RECENTS"
    }

    private var currentIsPinned: Bool {
        guard let root = store.root else { return false }
        return library.library.isFavourite(path: ProjectLibrary.key(for: root))
    }

    private var favourites: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Favourites")
            if library.library.favourites.isEmpty {
                hint("Pin a project and it stays in this list.")
            } else {
                ForEach(library.library.favourites) { bookmark in
                    row(bookmark, favourite: true)
                }
                Color.clear
                    .frame(height: 12)
                    .overlay(alignment: .top) {
                        if dropAtEnd {
                            dropLine
                        }
                    }
                    .onDrop(of: [.utf8PlainText], isTargeted: endDrop) { providers in
                        acceptReorder(providers, before: nil)
                    }
            }
        }
    }

    private var recents: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Recents")
            if library.library.displayedRecents.isEmpty {
                hint(
                    library.library.recents.isEmpty
                        ? "Boards you open show up here." : "Pinned projects are listed above.")
            } else {
                ForEach(library.library.displayedRecents) { bookmark in
                    row(bookmark, favourite: false)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(skeuoFont("MarkerFelt-Wide", 13))
            .foregroundStyle(Ink.cream)
            .shadow(color: .black.opacity(0.45), radius: 0, y: 1)
            .accessibilityLabel(title)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(skeuoFont("AmericanTypewriter", 13))
            .foregroundStyle(Ink.cream.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 4)
    }

    private func row(_ bookmark: ProjectBookmark, favourite: Bool) -> some View {
        let missing = !directoryExists(bookmark.path)
        let current = isCurrent(bookmark)
        return HStack(alignment: .center, spacing: 4) {
            Button {
                onOpen(URL(fileURLWithPath: bookmark.path))
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title(for: bookmark))
                            .font(skeuoFont("Noteworthy-Bold", 16))
                            .foregroundStyle(Ink.brown)
                            .lineLimit(1)
                        if current {
                            StampLabel(text: "OPEN")
                                .scaleEffect(0.85)
                        }
                    }
                    Text(
                        missing
                            ? "missing" : ProjectLibrary.locationLabel(forStoredPath: bookmark.path)
                    )
                    .font(skeuoFont("AmericanTypewriter", 11))
                    .foregroundStyle(
                        missing ? Color(red: 0.62, green: 0.16, blue: 0.12) : Ink.faded
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open \(title(for: bookmark))")
            .accessibilityLabel("\(title(for: bookmark)), \(favourite ? "favourite" : "recent")")

            Button {
                if favourite {
                    library.unpin(path: bookmark.path)
                } else {
                    library.pin(root: URL(fileURLWithPath: bookmark.path))
                }
            } label: {
                Image(systemName: favourite ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(
                        favourite ? Color(red: 0.70, green: 0.15, blue: 0.14) : Ink.faded
                    )
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(favourite ? "Remove from favourites" : "Pin to favourites")
            .accessibilityLabel(
                favourite ? "Unpin \(title(for: bookmark))" : "Pin \(title(for: bookmark))")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background { paper(current: current) }
        .overlay(alignment: .top) {
            if favourite && dropBefore == bookmark.path {
                dropLine
            }
        }
        .opacity(missing ? 0.72 : 1)
        .contextMenu {
            Button("Show in Finder") { reveal(bookmark) }
            Button("Remove from List") { library.remove(path: bookmark.path) }
        }
        .modifier(FavouriteDrag(enabled: favourite, path: bookmark.path))
        .onDrop(of: [.utf8PlainText], isTargeted: rowDrop(bookmark.path, enabled: favourite)) {
            providers in
            guard favourite else { return false }
            return acceptReorder(providers, before: bookmark.path)
        }
    }

    private func paper(current: Bool) -> some View {
        let fill =
            current
            ? Color(red: 1.0, green: 0.95, blue: 0.70) : Color(red: 0.97, green: 0.94, blue: 0.86)
        return ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(fill)
            Image(nsImage: TextureCache.grain)
                .resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(0.22)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Color.black.opacity(current ? 0.38 : 0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
    }

    private var dropLine: some View {
        Rectangle()
            .fill(Color(red: 0.98, green: 0.86, blue: 0.35))
            .frame(height: 3)
            .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
    }

    private var endDrop: Binding<Bool> {
        Binding(
            get: { dropAtEnd },
            set: { targeted in
                dropAtEnd = targeted
                if targeted { dropBefore = nil }
            }
        )
    }

    private func rowDrop(_ path: String, enabled: Bool) -> Binding<Bool> {
        Binding(
            get: { dropBefore == path },
            set: { targeted in
                guard enabled else { return }
                if targeted {
                    dropBefore = path
                    dropAtEnd = false
                } else if dropBefore == path {
                    dropBefore = nil
                }
            }
        )
    }

    private func toggleCurrentPin() {
        guard let root = store.root else { return }
        let path = ProjectLibrary.key(for: root)
        if library.library.isFavourite(path: path) {
            library.unpin(path: path)
        } else {
            library.pin(root: root)
        }
    }

    private func isCurrent(_ bookmark: ProjectBookmark) -> Bool {
        guard let root = store.root else { return false }
        return ProjectLibrary.key(for: root) == bookmark.path
    }

    private func title(for bookmark: ProjectBookmark) -> String {
        guard directoryExists(bookmark.path) else { return bookmark.name }
        return TicketRoot.projectName(forRoot: URL(fileURLWithPath: bookmark.path))
    }

    private func reveal(_ bookmark: ProjectBookmark) {
        let url = URL(fileURLWithPath: bookmark.path)
        guard directoryExists(bookmark.path) else {
            store.showBanner("That project is gone")
            return
        }
        TicketActions.reveal(url)
    }

    private func directoryExists(_ path: String) -> Bool {
        var isDirectory = ObjCBool(false)
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    /// NSString publishes public.utf8-plain-text. public.plain-text highlights, then returns nothing.
    private func acceptReorder(_ providers: [NSItemProvider], before other: String?) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) {
            item, _ in
            let raw: String?
            if let data = item as? Data {
                raw = String(data: data, encoding: .utf8)
            } else if let string = item as? String {
                raw = string
            } else if let string = item as? NSString {
                raw = string as String
            } else {
                raw = nil
            }
            guard let raw, raw.hasPrefix(Self.dragPrefix) else { return }
            let path = String(raw.dropFirst(Self.dragPrefix.count))
            DispatchQueue.main.async {
                library.moveFavourite(path, before: other)
                dropBefore = nil
                dropAtEnd = false
            }
        }
        return true
    }

    static let dragPrefix = "corkboard-favourite:"
}

private struct FavouriteDrag: ViewModifier {
    var enabled: Bool
    var path: String

    func body(content: Content) -> some View {
        if enabled {
            content.onDrag {
                NSItemProvider(object: "\(ProjectsPaletteView.dragPrefix)\(path)" as NSString)
            }
        } else {
            content
        }
    }
}
