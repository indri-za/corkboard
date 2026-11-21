import CorkboardCore
import SwiftUI

struct MarkdownView: View {
    var text: String
    var baseDirectory: URL

    var body: some View {
        let blocks = MarkdownDocument.parse(text)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            ink(text, size: headingSize(level), font: headingFont(level))
                .padding(.top, level == 1 ? 0 : 6)
        case .paragraph(let text):
            ink(text, size: 15, font: "AmericanTypewriter")
                .lineSpacing(3)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        marker(item)
                        ink(item.text, size: 15, font: "AmericanTypewriter")
                            .lineSpacing(2)
                    }
                }
            }
        case .code(let code):
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(skeuoFont("Menlo", 12))
                    .foregroundStyle(Ink.brown)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            )
        case .table(let header, let rows):
            MarkdownTable(header: header, rows: rows, baseDirectory: baseDirectory)
        case .rule:
            Rectangle()
                .fill(Ink.brown.opacity(0.25))
                .frame(height: 1)
                .padding(.vertical, 4)
        case .quote(let text):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.70, green: 0.32, blue: 0.28).opacity(0.8))
                    .frame(width: 3)
                ink(text, size: 15, font: "AmericanTypewriter")
                    .italic()
            }
        }
    }

    @ViewBuilder
    private func marker(_ item: MarkdownListItem) -> some View {
        if let checked = item.checked {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Ink.brown, lineWidth: 1.3)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(checked ? Ink.brown.opacity(0.88) : Color.clear)
                    )
                if checked {
                    InkCheck()
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                        )
                        .padding(2)
                }
            }
            .frame(width: 13, height: 13)
            .padding(.top, 3)
        } else {
            Text(item.marker)
                .font(skeuoFont("AmericanTypewriter-Bold", 14))
                .foregroundStyle(Ink.brown)
                .frame(width: 18, alignment: .trailing)
        }
    }

    private func ink(_ source: String, size: CGFloat, font: String) -> Text {
        markdownText(source, base: baseDirectory, size: size, font: font)
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: 28
        case 2: 20
        case 3: 16
        default: 14
        }
    }

    private func headingFont(_ level: Int) -> String {
        level <= 2 ? "Noteworthy-Bold" : "AmericanTypewriter-Bold"
    }
}

struct MarkdownTable: View {
    var header: [String]
    var rows: [[String]]
    var baseDirectory: URL

    var body: some View {
        let width = max(header.count, rows.map(\.count).max() ?? 0)
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                if !header.isEmpty {
                    row(header, width: width, header: true)
                    Rectangle().fill(Ink.brown.opacity(0.2)).frame(height: 1)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                    row(cells, width: width, header: false)
                        .background(
                            index.isMultiple(of: 2) ? Color.black.opacity(0.03) : Color.clear)
                }
            }
            .padding(4)
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Ink.brown.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func row(_ cells: [String], width: Int, header: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<max(width, 1), id: \.self) { index in
                markdownText(
                    index < cells.count ? cells[index] : "",
                    base: baseDirectory,
                    size: 12,
                    font: header ? "AmericanTypewriter-Bold" : "AmericanTypewriter"
                )
                .frame(minWidth: 88, maxWidth: 240, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
        }
    }
}

struct InkCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 1, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.center.x - 0.5, y: rect.maxY - 1.5))
        path.addLine(to: CGPoint(x: rect.maxX - 0.5, y: rect.minY + 1.5))
        return path
    }
}

func markdownText(_ source: String, base: URL, size: CGFloat, font: String) -> Text {
    let fixed = MarkdownLinks.absolutize(source, base: base)
    var options = AttributedString.MarkdownParsingOptions()
    options.interpretedSyntax = .inlineOnlyPreservingWhitespace
    options.failurePolicy = .returnPartiallyParsedIfPossible
    let text: Text
    if let parsed = try? AttributedString(markdown: fixed, options: options) {
        text = Text(parsed)
    } else {
        text = Text(source)
    }
    return
        text
        .font(skeuoFont(font, size))
        .foregroundStyle(Ink.brown)
}

enum MarkdownLinks {
    static func absolutize(_ markdown: String, base: URL) -> String {
        var output = ""
        var rest = Substring(markdown)
        while let marker = rest.range(of: "](") {
            output.append(contentsOf: rest[..<marker.upperBound])
            rest = rest[marker.upperBound...]
            guard let close = rest.firstIndex(of: ")") else {
                output.append(contentsOf: rest)
                return output
            }
            let target = String(rest[..<close])
            output.append(resolved(target, base: base))
            output.append(")")
            rest = rest[rest.index(after: close)...]
        }
        output.append(contentsOf: rest)
        return output
    }

    private static func resolved(_ target: String, base: URL) -> String {
        let trimmed = target.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("://") || trimmed.hasPrefix("mailto:") || trimmed.hasPrefix("#") {
            return target
        }
        let path =
            trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first.map(
                String.init) ?? trimmed
        guard !path.isEmpty else { return target }
        let url = URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL
        let suffix = trimmed.count > path.count ? String(trimmed.dropFirst(path.count)) : ""
        return url.absoluteString + suffix
    }
}

extension CGRect {
    fileprivate var center: CGPoint { CGPoint(x: midX, y: midY) }
}
