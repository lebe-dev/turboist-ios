import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let depth: Int
    let hasChildren: Bool
    let isCollapsed: Bool
    let availableLabels: [TaskLabel]
    let onComplete: () -> Void
    let onToggleCollapse: (() -> Void)?

    init(task: TaskItem, depth: Int = 0, hasChildren: Bool = false, isCollapsed: Bool = false,
         availableLabels: [TaskLabel] = [], onComplete: @escaping () -> Void, onToggleCollapse: (() -> Void)? = nil) {
        self.task = task
        self.depth = depth
        self.hasChildren = hasChildren
        self.isCollapsed = isCollapsed
        self.availableLabels = availableLabels
        self.onComplete = onComplete
        self.onToggleCollapse = onToggleCollapse
    }

    var body: some View {
        HStack(spacing: 8) {
            if depth > 0 {
                Spacer()
                    .frame(width: CGFloat(depth) * 20)
            }

            if hasChildren {
                Button {
                    onToggleCollapse?()
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            } else if depth > 0 {
                Spacer().frame(width: 16)
            }

            Button(action: onComplete) {
                Image(systemName: "circle")
                    .foregroundStyle(priorityColor)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.content)
                    .lineLimit(2)

                if !task.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(task.labels, id: \.self) { label in
                            LabelBadge(name: label, availableLabels: availableLabels)
                        }
                    }
                }

                HStack(spacing: 8) {
                    if let expiresText = ExpiresInHelper.expiresInText(for: task.expiresAt) {
                        HStack(spacing: 2) {
                            Image(systemName: "flame")
                            Text(expiresText)
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }

                    if let due = task.due {
                        HStack(spacing: 2) {
                            Image(systemName: due.recurring ? "arrow.triangle.2.circlepath" : "calendar")
                            Text(DueDateHelper.displayLabel(for: due.date))
                        }
                        .font(.caption)
                        .foregroundStyle(DueDateHelper.status(for: due.date).color)
                    }

                    if task.postponeCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "clock.arrow.circlepath")
                            if task.postponeCount >= 2 {
                                Text("\(task.postponeCount)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(DueDateHelper.postponeColor(count: task.postponeCount))
                    }

                    if task.subTaskCount > 0 {
                        subtaskProgress
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var subtaskProgress: some View {
        let completed = task.completedSubTaskCount
        let total = task.subTaskCount
        let fraction = Double(completed) / Double(total)

        HStack(spacing: 4) {
            Label("\(completed)/\(total)", systemImage: "checklist")
                .font(.caption)
                .foregroundStyle(progressColor(fraction))

            ProgressView(value: fraction)
                .frame(width: 30)
                .tint(progressColor(fraction))
        }
    }

    private func progressColor(_ fraction: Double) -> Color {
        if fraction >= 1.0 { return .green }
        if fraction >= 0.5 { return .blue }
        return .secondary
    }

    private var priorityColor: Color {
        Priority(rawPriority: task.priority).color
    }

}

struct LabelBadge: View {
    let name: String
    let availableLabels: [TaskLabel]

    private var labelColor: Color {
        guard let label = availableLabels.first(where: { $0.name == name }),
              let color = Color(hex: label.color) else {
            return .secondary
        }
        return color
    }

    var body: some View {
        Text(name)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(labelColor)
            .background(labelColor.opacity(0.15))
            .clipShape(Capsule())
    }
}
