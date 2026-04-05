import SwiftUI

struct TaskLimitProgressView: View {
    let count: Int
    let limit: Int
    let label: String

    private var fraction: Double {
        guard limit > 0 else { return 0 }
        return min(Double(count) / Double(limit), 1.0)
    }

    private var progressColor: Color {
        let percent = limit > 0 ? (Double(count) / Double(limit)) * 100 : 0
        if percent >= 100 { return .red }
        if percent >= 80 { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: fraction)
                .tint(progressColor)
                .frame(maxWidth: 120)
            Text("\(count)/\(limit)")
                .font(.caption)
                .foregroundStyle(progressColor)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

struct InboxOverflowBanner: View {
    let inboxCount: Int
    let inboxLimit: Int
    let warningText: String

    var body: some View {
        if inboxCount > inboxLimit {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(warningText.isEmpty ? "Inbox overflow: \(inboxCount)/\(inboxLimit)" : warningText)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.1))
        }
    }
}
