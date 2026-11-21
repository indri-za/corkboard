import CorkboardCore
import SwiftUI

struct NewTicketSheet: View {
    @ObservedObject var store: BoardStore
    @State private var title = ""
    @State private var type = "Feature"
    @State private var summary = ""
    @State private var column: Column
    @State private var error: String?

    init(store: BoardStore, column: Column) {
        self.store = store
        _column = State(initialValue: column)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("New note")
                        .font(skeuoFont("Noteworthy-Bold", 28))
                        .foregroundStyle(Ink.brown)
                    Spacer()
                    Text("#\(store.nextNumber())")
                        .font(skeuoFont("MarkerFelt-Wide", 22))
                        .foregroundStyle(Ink.brown.opacity(0.7))
                }

                fieldLabel("Title")
                TextField("What needs doing?", text: $title)
                    .textFieldStyle(.plain)
                    .font(skeuoFont("AmericanTypewriter", 16))
                    .foregroundStyle(Ink.brown)
                    .padding(10)
                    .background(InsetField())
                    .focusEffectDisabled()
                    .onSubmit(save)

                fieldLabel("Type")
                HStack(spacing: 8) {
                    ForEach(["Bug", "Feature", "Chore"], id: \.self) { chip in
                        chipButton(chip)
                    }
                    TextField("or type your own", text: $type)
                        .textFieldStyle(.plain)
                        .font(skeuoFont("AmericanTypewriter", 14))
                        .foregroundStyle(Ink.brown)
                        .padding(8)
                        .background(InsetField())
                        .focusEffectDisabled()
                }

                fieldLabel("Column")
                HStack(spacing: 8) {
                    ForEach(Column.allCases) { item in
                        columnChip(item)
                    }
                }

                fieldLabel("Summary")
                TextEditor(text: $summary)
                    .font(skeuoFont("AmericanTypewriter", 14))
                    .foregroundStyle(Ink.brown)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 110)
                    .background(InsetField())
                    .focusEffectDisabled()

                if let error {
                    Text(error)
                        .font(skeuoFont("AmericanTypewriter", 13))
                        .foregroundStyle(Color(red: 0.6, green: 0.12, blue: 0.12))
                }

                HStack {
                    Spacer()
                    GlossyButton(title: "Cancel", colors: Gloss.slate, foreground: Ink.brown) {
                        store.creatingColumn = nil
                    }
                    .keyboardShortcut(.cancelAction)
                    GlossyButton(
                        title: "Pin it",
                        systemImage: "pin",
                        colors: Gloss.green,
                        enabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        action: save
                    )
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(22)
            .frame(width: 520)
            .background(
                ZStack {
                    Color(red: 1.0, green: 0.96, blue: 0.68)
                    Image(nsImage: TextureCache.grain)
                        .resizable(resizingMode: .tile)
                        .blendMode(.multiply)
                        .opacity(0.22)
                        .allowsHitTesting(false)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 24, y: 14)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(skeuoFont("HelveticaNeue-Bold", 10))
            .tracking(1.2)
            .foregroundStyle(Ink.brown.opacity(0.55))
    }

    private func chipButton(_ chip: String) -> some View {
        Button {
            type = chip
        } label: {
            Text(chip)
                .font(skeuoFont("AmericanTypewriter-Bold", 12))
                .foregroundStyle(type == chip ? Color.white : Ink.brown)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    GlossyBackground(
                        colors: type == chip
                            ? Gloss.blue : [Color.white.opacity(0.7), Color.white.opacity(0.4)])
                )
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(SkeuoPressStyle())
    }

    private func columnChip(_ item: Column) -> some View {
        Button {
            column = item
        } label: {
            Text(item.title)
                .font(skeuoFont("MarkerFelt-Wide", 13))
                .foregroundStyle(item.tapeInk)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(GlossyBackground(colors: item.tapeColors))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(column == item ? Color.white : Color.clear, lineWidth: 2)
                )
                .shadow(
                    color: .black.opacity(column == item ? 0.35 : 0.15),
                    radius: column == item ? 3 : 1, y: 1)
        }
        .buttonStyle(SkeuoPressStyle())
    }

    private func save() {
        do {
            try store.create(title: title, type: type, summary: summary, column: column)
            store.creatingColumn = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
