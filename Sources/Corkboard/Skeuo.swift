import AppKit
import CorkboardCore
import SwiftUI

enum Ink {
    static let brown = Color(red: 0.20, green: 0.13, blue: 0.08)
    static let faded = Color(red: 0.28, green: 0.18, blue: 0.10).opacity(0.72)
    static let cream = Color(red: 0.99, green: 0.96, blue: 0.88)
    static let gold = Color(red: 0.98, green: 0.93, blue: 0.78)
}

enum Gloss {
    static let green = [
        Color(red: 0.47, green: 0.80, blue: 0.30), Color(red: 0.18, green: 0.52, blue: 0.14),
    ]
    static let blue = [
        Color(red: 0.42, green: 0.66, blue: 0.92), Color(red: 0.14, green: 0.36, blue: 0.74),
    ]
    static let red = [
        Color(red: 0.92, green: 0.38, blue: 0.30), Color(red: 0.66, green: 0.12, blue: 0.12),
    ]
    static let slate = [
        Color(red: 0.78, green: 0.74, blue: 0.68), Color(red: 0.45, green: 0.40, blue: 0.36),
    ]
    static let amber = [
        Color(red: 0.98, green: 0.80, blue: 0.32), Color(red: 0.76, green: 0.50, blue: 0.10),
    ]
}

func skeuoFont(_ name: String, _ size: CGFloat) -> Font {
    NSFont(name: name, size: size) == nil ? .system(size: size) : .custom(name, size: size)
}

func stableHash(_ string: String) -> Int {
    var hash = 5381
    for byte in string.utf8 {
        hash = ((hash << 5) &+ hash) &+ Int(byte)
    }
    return hash & 0x7fff_ffff
}

struct SkeuoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct GlossyBackground: View {
    var colors: [Color]

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            LinearGradient(
                colors: [Color.white.opacity(0.62), Color.white.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.55)
            )
        }
    }
}

struct GlossyButton: View {
    var title: String
    var systemImage: String?
    var colors: [Color]
    var foreground: Color = .white
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
                    .font(skeuoFont("HelveticaNeue-Bold", 13))
            }
            .foregroundStyle(foreground)
            .shadow(
                color: foreground == .white ? Color.black.opacity(0.35) : .clear, radius: 0, y: -0.5
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(GlossyBackground(colors: colors))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.38), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(SkeuoPressStyle())
        .disabled(!enabled)
    }
}

struct RoundGlossButton: View {
    var systemImage: String
    var colors: [Color]
    var size: CGFloat = 32
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                GlossyBackground(colors: colors)
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 0, y: -0.5)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
        .buttonStyle(SkeuoPressStyle())
    }
}

struct InsetField: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.16), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.28), lineWidth: 1)
            )
    }
}

extension Column {
    var tapeColors: [Color] {
        switch self {
        case .backlog:
            [Color(red: 0.66, green: 0.80, blue: 0.90), Color(red: 0.38, green: 0.56, blue: 0.74)]
        case .todo:
            [Color(red: 0.96, green: 0.88, blue: 0.58), Color(red: 0.80, green: 0.66, blue: 0.30)]
        case .inProgress:
            [Color(red: 0.92, green: 0.50, blue: 0.40), Color(red: 0.68, green: 0.24, blue: 0.20)]
        case .done:
            [Color(red: 0.62, green: 0.80, blue: 0.50), Color(red: 0.32, green: 0.54, blue: 0.30)]
        }
    }

    var tapeInk: Color {
        switch self {
        case .inProgress:
            Color(red: 0.99, green: 0.95, blue: 0.90)
        default:
            Color(red: 0.16, green: 0.10, blue: 0.06)
        }
    }

    var papers: [Color] {
        switch self {
        case .backlog:
            [
                Color(red: 0.80, green: 0.89, blue: 0.97),
                Color(red: 0.72, green: 0.84, blue: 0.94),
            ]
        case .todo:
            [
                Color(red: 1.00, green: 0.95, blue: 0.62),
                Color(red: 0.99, green: 0.90, blue: 0.52),
                Color(red: 1.00, green: 0.97, blue: 0.76),
            ]
        case .inProgress:
            [
                Color(red: 1.00, green: 0.80, blue: 0.66),
                Color(red: 0.99, green: 0.72, blue: 0.66),
            ]
        case .done:
            [
                Color(red: 0.80, green: 0.91, blue: 0.70),
                Color(red: 0.88, green: 0.94, blue: 0.76),
            ]
        }
    }

    func paper(for filename: String) -> Color {
        let colors = papers
        return colors[stableHash(filename) % colors.count]
    }
}

func pinColor(for filename: String) -> Color {
    let pins = [
        Color(red: 0.78, green: 0.16, blue: 0.16),
        Color(red: 0.16, green: 0.38, blue: 0.72),
        Color(red: 0.18, green: 0.55, blue: 0.28),
        Color(red: 0.90, green: 0.72, blue: 0.18),
        Color(red: 0.92, green: 0.92, blue: 0.90),
        Color(red: 0.22, green: 0.18, blue: 0.16),
    ]
    return pins[stableHash(filename + ":pin") % pins.count]
}

func noteTilt(for filename: String) -> Double {
    (Double(stableHash(filename) % 25) - 12) / 8
}

struct Pushpin: View {
    var color: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.55, green: 0.55, blue: 0.58))
                .frame(width: 3, height: 12)
                .offset(y: 7)
                .shadow(color: .black.opacity(0.25), radius: 0.5, y: 1)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.95), color],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: 10
                    )
                )
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 0.6))
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
        }
        .frame(width: 16, height: 22)
    }
}

struct StampLabel: View {
    var text: String

    private var color: Color {
        switch text {
        case "BUG":
            Color(red: 0.66, green: 0.12, blue: 0.14)
        case "FEATURE":
            Color(red: 0.12, green: 0.28, blue: 0.58)
        default:
            Color(red: 0.36, green: 0.22, blue: 0.12)
        }
    }

    var body: some View {
        Text(text)
            .font(skeuoFont("AmericanTypewriter-Bold", 10))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color, lineWidth: 1.4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(color.opacity(0.35), lineWidth: 2.4)
                    .padding(-1)
            )
            .rotationEffect(.degrees(-8))
            .opacity(0.88)
    }
}

struct WoodBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.48, green: 0.28, blue: 0.13),
                    Color(red: 0.66, green: 0.42, blue: 0.20),
                    Color(red: 0.34, green: 0.18, blue: 0.08),
                    Color(red: 0.58, green: 0.36, blue: 0.16),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            WoodGrain()
                .blendMode(.multiply)
                .opacity(0.55)
                .allowsHitTesting(false)
        }
    }
}

struct WoodGrain: View {
    var body: some View {
        Canvas { context, size in
            var rng = SplitMix(seed: 11)
            var y: CGFloat = 0
            while y < size.height {
                let height = 0.6 + rng.next() * 2.2
                let shade = rng.next()
                let color =
                    shade > 0.5
                    ? Color.black.opacity(0.05 + rng.next() * 0.08)
                    : Color.white.opacity(0.03 + rng.next() * 0.05)
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: height)),
                    with: .color(color)
                )
                y += height + rng.next() * 3.5
            }
        }
    }
}

struct CorkFill: View {
    var body: some View {
        ZStack {
            Image(nsImage: TextureCache.cork)
                .resizable(resizingMode: .tile)
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.28)],
                center: .center,
                startRadius: 180,
                endRadius: 820
            )
            .allowsHitTesting(false)
        }
    }
}

struct LeatherBar: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color(red: 0.50, green: 0.30, blue: 0.16),
                    Color(red: 0.32, green: 0.17, blue: 0.09),
                    Color(red: 0.22, green: 0.11, blue: 0.06),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: [Color.white.opacity(0.28), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.35)
            )
            VStack(spacing: 2) {
                stitch
                stitch.offset(y: 1).opacity(0.35)
            }
            .padding(.bottom, 5)
        }
    }

    private var stitch: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 2)
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 2000, y: 0))
                }
                .stroke(Color.black.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
    }
}

struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { Self.configure(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { Self.configure(nsView) }
    }

    private static func configure(_ view: NSView) {
        guard let window = view.window else { return }
        window.title = "Corkboard"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(srgbRed: 0.30, green: 0.17, blue: 0.08, alpha: 1)
        window.minSize = NSSize(width: 980, height: 640)
    }
}

enum TextureCache {
    static let cork: NSImage = makeCork()
    static let grain: NSImage = makeGrain()

    private static func makeCork() -> NSImage {
        let size = NSSize(width: 280, height: 280)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(srgbRed: 0.73, green: 0.52, blue: 0.33, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        var rng = SplitMix(seed: 42)
        for _ in 0..<90 {
            let x = rng.next() * size.width
            let y = rng.next() * size.height
            let w = 8 + rng.next() * 22
            let h = 6 + rng.next() * 16
            let light = rng.next() > 0.45
            let color =
                light
                ? NSColor(srgbRed: 0.84, green: 0.66, blue: 0.42, alpha: 0.28)
                : NSColor(srgbRed: 0.45, green: 0.28, blue: 0.14, alpha: 0.30)
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h)).fill()
        }
        for _ in 0..<700 {
            let x = rng.next() * size.width
            let y = rng.next() * size.height
            let r = 0.4 + rng.next() * 1.5
            let light = rng.next() > 0.5
            let color =
                light
                ? NSColor(calibratedWhite: 1, alpha: 0.16)
                : NSColor(calibratedWhite: 0, alpha: 0.14)
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: r, height: r)).fill()
        }
        image.unlockFocus()
        return image
    }

    private static func makeGrain() -> NSImage {
        let size = NSSize(width: 140, height: 140)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        var rng = SplitMix(seed: 9)
        for _ in 0..<420 {
            let x = rng.next() * size.width
            let y = rng.next() * size.height
            let r = 0.4 + rng.next() * 1.1
            NSColor(calibratedWhite: rng.next() > 0.5 ? 0.55 : 0.75, alpha: 0.45).setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: r, height: r)).fill()
        }
        image.unlockFocus()
        return image
    }
}

struct SplitMix {
    var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x123_4567_89ab_cdef : seed
    }

    mutating func next() -> CGFloat {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return CGFloat(z % 10_000) / 10_000
    }
}

enum AppIcon {
    static func render() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        NSColor(calibratedWhite: 0, alpha: 0.22).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: 96, y: 64, width: 340, height: 360), xRadius: 18, yRadius: 18
        ).fill()

        let face = NSBezierPath(
            roundedRect: NSRect(x: 78, y: 86, width: 340, height: 360), xRadius: 16, yRadius: 16)
        NSColor(srgbRed: 1, green: 0.93, blue: 0.55, alpha: 1).setFill()
        face.fill()
        NSColor(srgbRed: 0.86, green: 0.72, blue: 0.22, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 78, y: 400, width: 340, height: 46)).fill()

        NSColor(srgbRed: 0.25, green: 0.16, blue: 0.08, alpha: 0.8).setStroke()
        let line = NSBezierPath()
        line.lineWidth = 8
        line.lineCapStyle = .round
        line.move(to: NSPoint(x: 120, y: 300))
        line.line(to: NSPoint(x: 360, y: 292))
        line.move(to: NSPoint(x: 124, y: 250))
        line.line(to: NSPoint(x: 330, y: 246))
        line.move(to: NSPoint(x: 122, y: 200))
        line.line(to: NSPoint(x: 280, y: 204))
        line.stroke()

        let pin = NSBezierPath(ovalIn: NSRect(x: 226, y: 412, width: 60, height: 60))
        NSColor(srgbRed: 0.78, green: 0.14, blue: 0.14, alpha: 1).setFill()
        pin.fill()
        NSColor.white.withAlphaComponent(0.7).setFill()
        NSBezierPath(ovalIn: NSRect(x: 242, y: 438, width: 16, height: 16)).fill()
        image.unlockFocus()
        return image
    }
}

enum TicketActions {
    static func open(_ ticket: Ticket) {
        NSWorkspace.shared.open(ticket.fileURL)
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

enum ProjectOpener {
    static let panelDirectoryKey = "corkboard.panelDirectory"

    static func open(store: BoardStore) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use This Folder"
        panel.message = "Choose the project folder, or the tickets folder inside it."
        if let root = store.root {
            panel.directoryURL = root.deletingLastPathComponent()
        } else if let saved = UserDefaults.standard.string(forKey: panelDirectoryKey) {
            panel.directoryURL = URL(fileURLWithPath: saved)
        } else {
            panel.directoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let root = TicketRoot.resolve(url) else {
            store.showBanner("That folder has no tickets board")
            return
        }
        UserDefaults.standard.set(root.deletingLastPathComponent().path, forKey: panelDirectoryKey)
        store.load(root: root)
    }
}
