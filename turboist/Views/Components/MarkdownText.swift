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
        return try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
    }
}
