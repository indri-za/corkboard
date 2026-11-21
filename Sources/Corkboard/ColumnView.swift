import AppKit
import CorkboardCore
import SwiftUI
import UniformTypeIdentifiers

struct ColumnView: View {
    @ObservedObject var store: BoardStore
    var column: Column
    @State private var targeted = false
    @State private var hovered: String?

    private var tickets: [Ticket] { store.visible(column) }
    private var total: Int { store.columns[column]?.count ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            tape
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .zIndex(1)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(targeted ? 0.08 : 0.16))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    .blur(radius: 0.4)
                    .mask(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.black, .black.opacity(0.2), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .allowsHitTesting(false)

                ScrollView {
                    LazyVStack(spacing: 16) {
                        if tickets.isEmpty {
                            Text(store.query.isEmpty ? "no notes yet" : "no matches")
                                .font(skeuoFont("MarkerFelt-Thin", 18))
                                .foregroundStyle(Color.black.opacity(0.32))
                                .rotationEffect(.degrees(-2))
                                .padding(.top, 28)
                        } else {
                            ForEach(tickets) { ticket in
                                note(ticket)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }

                if targeted {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.85),
                            style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                        )
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.utf8PlainText], isTargeted: $targeted) { providers in
            acceptDrop(providers)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(column.title) column")
    }

    private var tape: some View {
        HStack(spacing: 8) {
            Text(column.title)
                .font(skeuoFont("MarkerFelt-Wide", 18))
                .foregroundStyle(column.tapeInk)
                .shadow(
                    color: column == .inProgress
                        ? Color.black.opacity(0.25) : Color.white.opacity(0.45), radius: 0, y: 1
                )
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(countLabel)
                .font(skeuoFont("HelveticaNeue-Bold", 11))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.black.opacity(0.28))
                )
            Button {
                store.selectedFilename = nil
                store.creatingColumn = column
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(column.tapeInk)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(0.28)))
                    .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(SkeuoPressStyle())
            .help("New \(column.title) ticket")
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(height: 40)
        .background(
            ZStack {
                GlossyBackground(colors: column.tapeColors)
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.clear, Color.black.opacity(0.08)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.28), radius: 2, y: 2)
        .rotationEffect(.degrees(column.tapeTilt))
        .padding(.vertical, 4)
    }

    private var countLabel: String {
        if store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(total)"
        }
        return "\(tickets.count)/\(total)"
    }

    private func note(_ ticket: Ticket) -> some View {
        Button {
            store.creatingColumn = nil
            store.selectedFilename = ticket.filename
        } label: {
            StickyNoteView(ticket: ticket, hovering: hovered == ticket.filename)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .contentShape(RoundedRectangle(cornerRadius: 2))
        .onHover { inside in
            hovered = inside ? ticket.filename : (hovered == ticket.filename ? nil : hovered)
            if inside {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .onDrag {
            NSItemProvider(object: "corkboard-ticket:\(ticket.filename)" as NSString)
        }
        .onDrop(of: [.utf8PlainText], isTargeted: .constant(false)) { providers in
            acceptDrop(providers)
        }
        .contextMenu {
            Button("Open in Editor") { TicketActions.open(ticket) }
            Button("Show in Finder") { TicketActions.reveal(ticket.fileURL) }
            Divider()
            ForEach(Column.allCases) { destination in
                Button("Move to \(destination.title)") {
                    store.move(filename: ticket.filename, to: destination)
                }
                .disabled(destination == ticket.column)
            }
            Divider()
            Button("Copy Filename") { TicketActions.copy(ticket.filename) }
        }
        .zIndex(hovered == ticket.filename ? 2 : 0)
    }

    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        // NSString publishes public.utf8-plain-text. Loading it as public.plain-text
        // succeeds the hover and then returns nothing, so the note snaps back.
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
            let prefix = "corkboard-ticket:"
            guard let raw, raw.hasPrefix(prefix) else { return }
            let filename = String(raw.dropFirst(prefix.count))
            DispatchQueue.main.async {
                store.move(filename: filename, to: column)
            }
        }
        return true
    }
}
