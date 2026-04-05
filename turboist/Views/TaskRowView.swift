import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let depth: Int
    let hasChildren: Bool
    let isCollapsed: Bool
    let onComplete: () -> Void
    let onToggleCollapse: (() -> Void)?

    init(task: TaskItem, depth: Int = 0, hasChildren: Bool = false, isCollapsed: Bool = false,
         onComplete: @escaping () -> Void, onToggleCollapse: (() -> Void)? = nil) {
        self.task = task
        self.depth = depth
        self.hasChildren = hasChildren
        self.isCollapsed = isCollapsed
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
                            Text(label)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: 8) {
                    if let due = task.due {
                        Label(due.date, systemImage: due.recurring ? "arrow.triangle.2.circlepath" : "calendar")
                            .font(.caption)
                            .foregroundStyle(dueDateColor(due.date))
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

    private func dueDateColor(_ dateString: String) -> Color {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return .secondary }
        let today = Calendar.current.startOfDay(for: Date())
        if date < today { return .red }
        if Calendar.current.isDateInToday(date) { return .green }
        return .secondary
    }
}
