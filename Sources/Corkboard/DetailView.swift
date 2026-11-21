import CorkboardCore
import SwiftUI

struct DetailOverlay: View {
    @ObservedObject var store: BoardStore
    var ticket: Ticket

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { store.selectedFilename = nil }

            VStack(spacing: 0) {
                header
                ScrollView {
                    MarkdownView(
                        text: ticket.body,
                        baseDirectory: ticket.fileURL.deletingLastPathComponent()
                    )
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                    .padding(.leading, 18)
                }
                .background(alignment: .leading) {
                    Rectangle()
                        .fill(Color(red: 0.78, green: 0.36, blue: 0.36).opacity(0.75))
                        .frame(width: 1.4)
                        .padding(.leading, 32)
                        .allowsHitTesting(false)
                }
                footer
            }
            .frame(maxWidth: 760, maxHeight: .infinity)
            .padding(.vertical, 36)
            .background(paper)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 28, y: 16)
            .padding(.horizontal, 48)
            .padding(.vertical, 28)
        }
    }

    private var paper: some View {
        ZStack {
            Color(red: 0.99, green: 0.97, blue: 0.90)
            Image(nsImage: TextureCache.grain)
                .resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(0.18)
                .allowsHitTesting(false)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Pushpin(color: pinColor(for: ticket.filename))
                .padding(.leading, 4)
            Text(ticket.displayNumber)
                .font(skeuoFont("MarkerFelt-Wide", 20))
                .foregroundStyle(ticket.column.tapeInk)
            Text(ticket.column.title.uppercased())
                .font(skeuoFont("HelveticaNeue-Bold", 11))
                .tracking(1.1)
                .foregroundStyle(ticket.column.tapeInk.opacity(0.85))
            Spacer()
            RoundGlossButton(systemImage: "xmark", colors: Gloss.red, size: 26) {
                store.selectedFilename = nil
            }
            .help("Close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(GlossyBackground(colors: ticket.column.tapeColors))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(ticket.relativePath)
                .font(skeuoFont("AmericanTypewriter", 12))
                .foregroundStyle(Ink.gold.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            GlossyButton(title: "Editor", systemImage: "square.and.pencil", colors: Gloss.blue) {
                TicketActions.open(ticket)
            }
            GlossyButton(
                title: "Finder", systemImage: "folder", colors: Gloss.slate, foreground: Ink.brown
            ) {
                TicketActions.reveal(ticket.fileURL)
            }
            Menu {
                ForEach(Column.allCases) { column in
                    Button(column.title) {
                        store.move(filename: ticket.filename, to: column)
                    }
                    .disabled(column == ticket.column)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .bold))
                    Text("Move")
                        .font(skeuoFont("HelveticaNeue-Bold", 13))
                }
                .foregroundStyle(Ink.brown)
                .shadow(color: .clear, radius: 0)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(GlossyBackground(colors: Gloss.amber))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.24, blue: 0.13),
                    Color(red: 0.24, green: 0.12, blue: 0.07),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
