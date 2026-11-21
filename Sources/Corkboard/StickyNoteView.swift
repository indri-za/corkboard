import CorkboardCore
import SwiftUI

struct StickyNoteView: View {
    var ticket: Ticket
    var hovering: Bool

    private var paper: Color { ticket.column.paper(for: ticket.filename) }

    private var band: Color {
        switch ticket.column {
        case .backlog: Color(red: 0.58, green: 0.74, blue: 0.88)
        case .todo: Color(red: 0.93, green: 0.78, blue: 0.32)
        case .inProgress: Color(red: 0.92, green: 0.58, blue: 0.46)
        case .done: Color(red: 0.58, green: 0.78, blue: 0.48)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Pushpin(color: pinColor(for: ticket.filename))
            }
            .frame(height: 12)
            .frame(maxWidth: .infinity)

            HStack(alignment: .firstTextBaseline) {
                Text(ticket.displayNumber)
                    .font(skeuoFont("MarkerFelt-Wide", 14))
                    .foregroundStyle(Ink.brown.opacity(0.78))
                Spacer(minLength: 4)
                if let stamp = ticket.stamp {
                    StampLabel(text: stamp)
                }
            }

            Text(ticket.title)
                .font(skeuoFont("Noteworthy-Bold", 16))
                .foregroundStyle(Ink.brown)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let portal = ticket.portalDisplay {
                Text(portal)
                    .font(skeuoFont("AmericanTypewriter", 11))
                    .foregroundStyle(Ink.faded)
                    .lineLimit(1)
            }

            if !ticket.summary.isEmpty {
                Text(ticket.summary)
                    .font(skeuoFont("AmericanTypewriter", 12))
                    .foregroundStyle(Ink.brown.opacity(0.72))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            HStack {
                Spacer()
                Text(ticket.modifiedLabel)
                    .font(skeuoFont("AmericanTypewriter", 10))
                    .foregroundStyle(Ink.brown.opacity(0.45))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(notePaper)
        .rotationEffect(.degrees(hovering ? 0 : noteTilt(for: ticket.filename)))
        .scaleEffect(hovering ? 1.035 : 1)
        .shadow(
            color: .black.opacity(hovering ? 0.38 : 0.28), radius: hovering ? 10 : 3, x: 0,
            y: hovering ? 8 : 3
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: hovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ticket.displayNumber), \(ticket.title)")
        .accessibilityHint("Shows the ticket. Drag it to another column to move the file.")
    }

    private var notePaper: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [paper, paper],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            VStack(spacing: 0) {
                band.frame(height: 18)
                Spacer(minLength: 0)
            }
            Image(nsImage: TextureCache.grain)
                .resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(0.28)
                .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }
}
