import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
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
                        Label("\(task.completedSubTaskCount)/\(task.subTaskCount)", systemImage: "checklist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var priorityColor: Color {
        switch task.priority {
        case 4: return .red
        case 3: return .orange
        case 2: return .blue
        default: return .gray
        }
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
