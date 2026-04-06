import SwiftUI

struct MarkdownText: View {
    let text: String
    let cleanURLs: Bool

    init(_ text: String, cleanURLs: Bool = true) {
        self.text = text
        self.cleanURLs = cleanURLs
    }

    var body: some View {
        if let attributed = renderMarkdown() {
            Text(attributed)
        } else {
            Text(text)
        }
    }

    private func renderMarkdown() -> AttributedString? {
        let source = cleanURLs ? URLCleaner.cleanTrackingParams(in: text) : text
        guard var attributed = try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else {
            return nil
        }
        for run in attributed.runs {
            guard run.link != nil else { continue }
            attributed[run.range].foregroundColor = Color.secondary
            attributed[run.range].underlineStyle = Text.LineStyle(pattern: .solid)
        }
        return attributed
    }
}
